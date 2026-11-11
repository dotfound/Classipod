import 'dart:async';
import 'dart:io';

import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/podcast_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Downloads queued episodes one at a time into app-private storage.
class PodcastDownloadService {
  final PodcastRepository repository;
  final http.Client client;

  /// Download progress (0 to 1) by episode storage key.
  final ValueNotifier<Map<String, double>> progress = ValueNotifier(const {});

  Future<void>? _running;
  bool _cancelled = false;

  PodcastDownloadService({required this.repository, http.Client? client})
    : client = client ?? http.Client();

  bool get isRunning => _running != null;

  /// Stops after the current chunk; the episode goes back to queued.
  void cancel() => _cancelled = true;

  /// Puts interrupted and failed downloads back in the queue.
  Future<void> requeueInterrupted() async {
    if (isRunning) return;
    for (final episode in repository.episodesBox.values.toList()) {
      if (episode.downloadState == PodcastDownloadState.downloading ||
          episode.downloadState == PodcastDownloadState.failed) {
        episode.downloadState = PodcastDownloadState.queued;
        await repository.saveEpisode(episode);
      }
    }
  }

  Future<void> enqueue(PodcastEpisode episode) async {
    if (episode.isDownloaded ||
        episode.downloadState == PodcastDownloadState.downloading) {
      return;
    }
    episode.downloadState = PodcastDownloadState.queued;
    await repository.saveEpisode(episode);
  }

  Future<void> deleteDownload(PodcastEpisode episode) async {
    final path = episode.localPath;
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } on FileSystemException catch (error) {
        debugPrint('Could not delete episode: ${error.message}');
      }
    }
    episode
      ..localPath = null
      ..downloadState = PodcastDownloadState.none;
    await repository.saveEpisode(episode);
  }

  /// Downloads everything queued. Concurrent calls share one run.
  Future<void> processQueue() {
    return _running ??= _process().whenComplete(() => _running = null);
  }

  Future<void> _process() async {
    _cancelled = false;
    final attempted = <String>{};
    while (!_cancelled) {
      final queued =
          repository.episodesBox.values
              .where(
                (episode) =>
                    episode.downloadState == PodcastDownloadState.queued &&
                    !attempted.contains(episode.storageKey),
              )
              .toList()
            ..sort(_newestFirst);
      final next = queued.firstOrNull;
      if (next == null) return;
      attempted.add(next.storageKey);
      await _download(next);
    }
  }

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static int _newestFirst(PodcastEpisode a, PodcastEpisode b) =>
      (b.pubDate ?? _epoch).compareTo(a.pubDate ?? _epoch);

  void _setProgress(String key, double? value) {
    final next = Map<String, double>.of(progress.value);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    progress.value = Map.unmodifiable(next);
  }

  Future<void> _download(PodcastEpisode episode) async {
    final directory = repository.showDirectory(episode.showFeedUrl);
    if (directory == null) return;
    final key = episode.storageKey;
    final target = File('$directory/$key.${_extension(episode.enclosureUrl)}');
    final part = File('${target.path}.part');
    episode.downloadState = PodcastDownloadState.downloading;
    await repository.saveEpisode(episode);
    _setProgress(key, 0);
    IOSink? sink;
    try {
      await target.parent.create(recursive: true);
      final request = http.Request('GET', Uri.parse(episode.enclosureUrl))
        ..headers['User-Agent'] = 'PixelPod/1.0';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      var reported = 0.0;
      sink = part.openWrite();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        if (_cancelled) break;
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && received / total - reported >= 0.01) {
          reported = received / total;
          _setProgress(key, reported);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (_cancelled) {
        if (part.existsSync()) await part.delete();
        episode.downloadState = PodcastDownloadState.queued;
      } else {
        await part.rename(target.path);
        episode
          ..localPath = target.path
          ..downloadState = PodcastDownloadState.done;
      }
    } catch (error) {
      debugPrint('Download failed for ${episode.enclosureUrl}: $error');
      try {
        await sink?.close();
        if (part.existsSync()) await part.delete();
      } catch (_) {}
      episode.downloadState = PodcastDownloadState.failed;
    } finally {
      _setProgress(key, null);
      await repository.saveEpisode(episode);
    }
  }

  static String _extension(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    final dot = path.lastIndexOf('.');
    final extension = dot < 0 ? '' : path.substring(dot + 1);
    return RegExp(r'^[a-z0-9]{2,4}$').hasMatch(extension) ? extension : 'mp3';
  }
}
