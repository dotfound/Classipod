import 'dart:async';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/extensions/go_router_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/podcast_playback.dart';
import 'package:classipod/core/podcasts/podcast_providers.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/core/widgets/empty_state_widget.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/podcasts/providers/podcast_library_provider.dart';
import 'package:classipod/features/podcasts/widgets/podcast_list_tile.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A show's episodes, newest first.
class PodcastShowScreen extends ConsumerStatefulWidget {
  final String feedUrl;

  const PodcastShowScreen({super.key, required this.feedUrl});

  @override
  ConsumerState createState() => _PodcastShowScreenState();
}

class _PodcastShowScreenState extends ConsumerState<PodcastShowScreen>
    with CustomScreen {
  /// An episode to play as soon as its download finishes.
  String? _playWhenDownloaded;

  @override
  String get routeName => Routes.podcastShow.name;

  @override
  String get screenStateKey => '${Routes.podcastShow.name}:${widget.feedUrl}';

  @override
  List<PodcastEpisode> get displayItems =>
      ref.read(podcastEpisodesByShowProvider)[widget.feedUrl] ?? const [];

  @override
  Future<void> onSelectPressed() => _select(selectedDisplayItem);

  @override
  void onSelectLongPress() => _openOptions(selectedDisplayItem);

  void _openOptions(int index) {
    if (index >= displayItems.length) return;
    setState(() => selectedDisplayItem = index);
    context.goNamed(
      Routes.podcastEpisodeMoreOptions.name,
      queryParameters: {
        'feed': widget.feedUrl,
        'episode': displayItems[index].storageKey,
      },
    );
  }

  Future<void> _select(int index) async {
    if (index >= displayItems.length) return;
    setState(() => selectedDisplayItem = index);
    final episode = displayItems[index];
    if (episode.isDownloaded) {
      await _play(episode);
      return;
    }
    final services = ref.read(podcastServicesProvider).value;
    if (services == null) return;
    _playWhenDownloaded = episode.storageKey;
    await services.downloads.enqueue(episode);
    unawaited(services.downloads.processQueue());
  }

  Future<void> _play(PodcastEpisode episode) async {
    final repository = ref.read(podcastServicesProvider).value?.repository;
    if (repository == null) return;
    await ref
        .read(audioPlayerServiceProvider.notifier)
        .playEpisode(
          episodeToMetadata(episode, repository.show(episode.showFeedUrl)),
        );
    if (mounted) await context.openUniqueNamed(Routes.nowPlaying.name);
  }

  void _playPendingDownload() {
    final key = _playWhenDownloaded;
    if (key == null) return;
    final episode = displayItems
        .where((episode) => episode.storageKey == key)
        .firstOrNull;
    if (episode == null ||
        episode.downloadState == PodcastDownloadState.failed) {
      _playWhenDownloaded = null;
    } else if (episode.isDownloaded) {
      _playWhenDownloaded = null;
      if (context.router.locationNamed == routeName) unawaited(_play(episode));
    }
  }

  String? _stateLabel(PodcastEpisode episode, Map<String, double> progress) {
    switch (episode.downloadState) {
      case PodcastDownloadState.done:
        return null;
      case PodcastDownloadState.downloading:
        final value = progress[episode.storageKey] ?? 0;
        return '${(value * 100).round()}%';
      case PodcastDownloadState.queued:
        return context.localization.podcastQueued;
      case PodcastDownloadState.failed:
        return context.localization.podcastFailed;
      case PodcastDownloadState.none:
        return '↓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodes =
        ref.watch(podcastEpisodesByShowProvider)[widget.feedUrl] ?? const [];
    final progress = ref.watch(podcastDownloadProgressProvider);
    ref.listen(podcastRevisionProvider, (_, _) => _playPendingDownload());
    if (episodes.isEmpty) {
      return CupertinoPageScaffold(
        child: EmptyStateWidget(
          emptyDescription: context.localization.podcastNoEpisodes,
        ),
      );
    }
    return CupertinoPageScaffold(
      child: CupertinoScrollbar(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          itemCount: episodes.length,
          prototypeItem: const PodcastListTile(text: '', isSelected: false),
          itemBuilder: (context, index) {
            final episode = episodes[index];
            return PodcastListTile(
              text: episode.title,
              value: _stateLabel(episode, progress),
              dot: episode.isPlayed
                  ? PodcastDot.none
                  : episode.isInProgress
                  ? PodcastDot.half
                  : PodcastDot.full,
              isSelected: selectedDisplayItem == index,
              onTap: () async => _select(index),
              onLongPress: () => _openOptions(index),
            );
          },
        ),
      ),
    );
  }
}
