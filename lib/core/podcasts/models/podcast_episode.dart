import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A short, Hive-safe key for a feed URL or episode id.
String podcastKey(String value) => sha1.convert(utf8.encode(value)).toString();

enum PodcastDownloadState { none, queued, downloading, done, failed }

class PodcastEpisode {
  /// The feed's guid, or the enclosure URL when the feed has none.
  final String id;
  final String showFeedUrl;
  String title;
  String description;
  DateTime? pubDate;
  String enclosureUrl;
  int durationSeconds;
  String? localPath;
  PodcastDownloadState downloadState;
  int positionSeconds;
  bool isPlayed;
  DateTime? playedAt;

  PodcastEpisode({
    required this.id,
    required this.showFeedUrl,
    required this.title,
    this.description = '',
    this.pubDate,
    required this.enclosureUrl,
    this.durationSeconds = 0,
    this.localPath,
    this.downloadState = PodcastDownloadState.none,
    this.positionSeconds = 0,
    this.isPlayed = false,
    this.playedAt,
  });

  /// Unique across shows; used as the Hive key and the playback id.
  String get storageKey => podcastKey('$showFeedUrl\n$id');

  bool get isDownloaded =>
      downloadState == PodcastDownloadState.done && localPath != null;

  bool get isInProgress => !isPlayed && positionSeconds > 0;
}
