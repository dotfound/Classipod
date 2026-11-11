import 'dart:async';

import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/podcast_download_service.dart';
import 'package:classipod/core/podcasts/podcast_repository.dart';

/// The pipeline shared by app start, the Refresh row and the background
/// worker: refresh feeds, queue auto-downloads, clean up, then download.
class PodcastSync {
  static const playedRetention = Duration(hours: 24);

  final PodcastRepository repository;
  final PodcastDownloadService downloads;

  /// Whether downloading is allowed right now (the Wi-Fi only setting).
  final Future<bool> Function() canDownload;
  Future<void>? _running;

  PodcastSync({
    required this.repository,
    required this.downloads,
    Future<bool> Function()? canDownload,
  }) : canDownload = canDownload ?? (() async => true);

  bool get isRunning => _running != null;

  Future<void> run({bool refresh = true}) {
    return _running ??= _run(refresh).whenComplete(() => _running = null);
  }

  Future<void> _run(bool refresh) async {
    await downloads.requeueInterrupted();
    if (refresh) await repository.refreshAll();
    await queueAutoDownloads();
    await cleanUp();
    if (await canDownload()) await downloads.processQueue();
  }

  /// Queues the unplayed episodes among each show's newest `keepLatest`.
  Future<void> queueAutoDownloads() async {
    for (final show in repository.shows) {
      if (!show.autoDownload) continue;
      final newest = repository.episodesOf(show.feedUrl).take(show.keepLatest);
      for (final episode in newest) {
        if (episode.isPlayed ||
            episode.downloadState != PodcastDownloadState.none) {
          continue;
        }
        await downloads.enqueue(episode);
      }
    }
  }

  /// Deletes files of episodes played more than 24 hours ago. Episodes
  /// that are part-way through are never deleted.
  Future<int> cleanUp({bool allPlayed = false}) async {
    final cutoff = repository.now().subtract(playedRetention);
    var deleted = 0;
    for (final episode in repository.episodesBox.values.toList()) {
      final playedAt = episode.playedAt;
      if (!episode.isPlayed ||
          episode.localPath == null ||
          episode.positionSeconds > 0) {
        continue;
      }
      if (!allPlayed && (playedAt == null || playedAt.isAfter(cutoff))) {
        continue;
      }
      await downloads.deleteDownload(episode);
      deleted++;
    }
    return deleted;
  }
}
