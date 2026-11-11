import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/models/podcast_show.dart';
import 'package:classipod/core/podcasts/podcast_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PodcastShowSummary {
  final PodcastShow show;
  final DateTime? newestEpisode;

  /// Whether any of the show's newest `keepLatest` episodes is unplayed.
  final bool hasUnplayed;

  const PodcastShowSummary({
    required this.show,
    required this.newestEpisode,
    required this.hasUnplayed,
  });
}

/// Every show's episodes, newest first, rebuilt when podcast data changes.
final podcastEpisodesByShowProvider =
    Provider<Map<String, List<PodcastEpisode>>>((ref) {
      ref.watch(podcastRevisionProvider);
      final repository = ref.watch(podcastServicesProvider).value?.repository;
      if (repository == null) return const {};
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final byShow = <String, List<PodcastEpisode>>{};
      for (final episode in repository.episodesBox.values) {
        byShow.putIfAbsent(episode.showFeedUrl, () => []).add(episode);
      }
      for (final episodes in byShow.values) {
        episodes.sort(
          (a, b) => (b.pubDate ?? epoch).compareTo(a.pubDate ?? epoch),
        );
      }
      return byShow;
    });

/// Shows sorted by their newest episode.
final podcastShowSummariesProvider = Provider<List<PodcastShowSummary>>((ref) {
  final byShow = ref.watch(podcastEpisodesByShowProvider);
  final repository = ref.watch(podcastServicesProvider).value?.repository;
  if (repository == null) return const [];
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  return [
    for (final show in repository.shows)
      PodcastShowSummary(
        show: show,
        newestEpisode: byShow[show.feedUrl]?.firstOrNull?.pubDate,
        hasUnplayed: (byShow[show.feedUrl] ?? const [])
            .take(show.keepLatest)
            .any((episode) => !episode.isPlayed),
      ),
  ]..sort(
    (a, b) => (b.newestEpisode ?? epoch).compareTo(a.newestEpisode ?? epoch),
  );
});
