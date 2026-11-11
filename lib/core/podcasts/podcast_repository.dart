import 'dart:async';
import 'dart:io';

import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/models/podcast_show.dart';
import 'package:classipod/core/podcasts/podcast_feed_client.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

class PodcastRepository {
  static const showsBoxName = 'podcast_shows_v1';
  static const episodesBoxName = 'podcast_episodes_v1';

  final Box<PodcastShow> showsBox;
  final Box<PodcastEpisode> episodesBox;
  final PodcastFeedClient feedClient;

  /// Directory that holds one folder per show. Null disables file handling.
  final String? storageRoot;
  final DateTime Function() now;
  final StreamController<void> _changes = StreamController.broadcast();

  PodcastRepository({
    required this.showsBox,
    required this.episodesBox,
    required this.feedClient,
    this.storageRoot,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static Future<PodcastRepository> open({
    PodcastFeedClient? feedClient,
    String? storageRoot,
  }) async => PodcastRepository(
    showsBox: await Hive.openBox<PodcastShow>(showsBoxName),
    episodesBox: await Hive.openBox<PodcastEpisode>(episodesBoxName),
    feedClient: feedClient ?? PodcastFeedClient(),
    storageRoot: storageRoot,
  );

  /// Fires after any show or episode changes.
  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  List<PodcastShow> get shows => showsBox.values.toList();

  PodcastShow? show(String feedUrl) => showsBox.get(podcastKey(feedUrl));

  PodcastEpisode? episode(String storageKey) => episodesBox.get(storageKey);

  /// Episodes of a show, newest first.
  List<PodcastEpisode> episodesOf(String feedUrl) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return episodesBox.values
        .where((episode) => episode.showFeedUrl == feedUrl)
        .toList()
      ..sort((a, b) => (b.pubDate ?? epoch).compareTo(a.pubDate ?? epoch));
  }

  String? showDirectory(String feedUrl) =>
      storageRoot == null ? null : '$storageRoot/${podcastKey(feedUrl)}';

  Future<void> saveShow(PodcastShow show) async {
    await showsBox.put(podcastKey(show.feedUrl), show);
    _notify();
  }

  Future<void> saveEpisode(PodcastEpisode episode) async {
    await episodesBox.put(episode.storageKey, episode);
    _notify();
  }

  /// Subscribes to a feed. Returns the existing show if already subscribed.
  Future<PodcastShow> subscribe(String feedUrl, {int? keepLatest}) async {
    final url = feedUrl.trim();
    final existing = show(url);
    if (existing != null) return existing;
    final response = await feedClient.fetch(url);
    final feed = response.feed!;
    final created = PodcastShow(
      feedUrl: url,
      title: feed.title,
      keepLatest: keepLatest ?? 3,
    );
    await _apply(created, response);
    return created;
  }

  Future<void> unsubscribe(String feedUrl) async {
    final keys = [
      for (final episode in episodesBox.values)
        if (episode.showFeedUrl == feedUrl) episode.storageKey,
    ];
    await episodesBox.deleteAll(keys);
    await showsBox.delete(podcastKey(feedUrl));
    final directory = showDirectory(feedUrl);
    if (directory != null) {
      try {
        final folder = Directory(directory);
        if (folder.existsSync()) await folder.delete(recursive: true);
      } on FileSystemException catch (error) {
        debugPrint('Could not delete podcast files: ${error.message}');
      }
    }
    _notify();
  }

  /// Refreshes every show. Returns the feed URLs that failed.
  Future<List<String>> refreshAll() async {
    final failed = <String>[];
    for (final show in shows) {
      if (!await refreshOne(show)) failed.add(show.feedUrl);
    }
    return failed;
  }

  /// Returns false when the feed could not be fetched or parsed.
  Future<bool> refreshOne(PodcastShow show) async {
    try {
      final response = await feedClient.fetch(
        show.feedUrl,
        etag: show.etag,
        lastModified: show.lastModified,
      );
      await _apply(show, response);
      return true;
    } catch (error) {
      debugPrint('Could not refresh ${show.feedUrl}: $error');
      return false;
    }
  }

  Future<void> _apply(PodcastShow show, PodcastFeedResponse response) async {
    show.lastRefreshed = now();
    final feed = response.feed;
    if (feed != null) {
      show
        ..title = feed.title
        ..author = feed.author
        ..etag = response.etag
        ..lastModified = response.lastModified;
      if (feed.artworkUrl != show.artworkUrl) {
        show
          ..artworkUrl = feed.artworkUrl
          ..localArtworkPath = null;
      }
      await _merge(feed.episodes);
    }
    await _cacheArtwork(show);
    await saveShow(show);
  }

  /// Adds new episodes and updates feed fields, keeping local state.
  Future<void> _merge(List<PodcastEpisode> parsed) async {
    final changed = <String, PodcastEpisode>{};
    for (final fresh in parsed) {
      final key = fresh.storageKey;
      final existing = episodesBox.get(key);
      if (existing == null) {
        changed[key] = fresh;
        continue;
      }
      existing
        ..title = fresh.title
        ..description = fresh.description
        ..pubDate = fresh.pubDate ?? existing.pubDate
        ..enclosureUrl = fresh.enclosureUrl;
      if (fresh.durationSeconds > 0) {
        existing.durationSeconds = fresh.durationSeconds;
      }
      changed[key] = existing;
    }
    await episodesBox.putAll(changed);
  }

  Future<void> _cacheArtwork(PodcastShow show) async {
    final directory = showDirectory(show.feedUrl);
    final url = show.artworkUrl;
    if (directory == null || url == null) return;
    final cached = show.localArtworkPath;
    if (cached != null && File(cached).existsSync()) return;
    try {
      final response = await feedClient.client
          .get(Uri.parse(url), headers: {'User-Agent': 'PixelPod/1.0'})
          .timeout(feedClient.timeout);
      if (response.statusCode != HttpStatus.ok) return;
      final path = Uri.parse(url).path.toLowerCase();
      final extension = path.endsWith('.png') ? 'png' : 'jpg';
      final file = File('$directory/artwork.$extension');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      show.localArtworkPath = file.path;
    } catch (error) {
      debugPrint('Could not cache artwork for ${show.feedUrl}: $error');
    }
  }

  Future<void> close() async {
    await _changes.close();
    await showsBox.close();
    await episodesBox.close();
  }
}
