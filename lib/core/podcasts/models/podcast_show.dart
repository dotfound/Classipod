class PodcastShow {
  final String feedUrl;
  String title;
  String? author;
  String? artworkUrl;
  String? localArtworkPath;
  DateTime? lastRefreshed;
  String? etag;
  String? lastModified;
  bool autoDownload;
  int keepLatest;
  double speed;

  PodcastShow({
    required this.feedUrl,
    required this.title,
    this.author,
    this.artworkUrl,
    this.localArtworkPath,
    this.lastRefreshed,
    this.etag,
    this.lastModified,
    this.autoDownload = true,
    this.keepLatest = 3,
    this.speed = 1,
  });
}
