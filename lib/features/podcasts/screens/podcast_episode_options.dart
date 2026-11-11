import 'dart:async';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/podcasts/podcast_playback.dart';
import 'package:classipod/core/podcasts/podcast_providers.dart';
import 'package:classipod/core/services/playback/up_next_controller.dart';
import 'package:classipod/features/custom_screen_elements/action_options_modal.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// More options for an episode: Up Next, download, played state and
/// unsubscribing from its show.
class PodcastEpisodeOptionsModal extends ConsumerWidget {
  final String episodeKey;

  const PodcastEpisodeOptionsModal({super.key, required this.episodeKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.read(podcastServicesProvider).value;
    final episode = services?.repository.episode(episodeKey);
    final text = context.localization;
    if (services == null || episode == null) {
      return ActionOptionsModal(
        routeName: Routes.podcastEpisodeMoreOptions.name,
        options: [ActionOption(text.cancelText)],
      );
    }
    final repository = services.repository;
    final metadata = episodeToMetadata(
      episode,
      repository.show(episode.showFeedUrl),
    );
    final router = GoRouter.of(context);
    final upNext = ref.read(upNextProvider.notifier);
    return ActionOptionsModal(
      routeName: Routes.podcastEpisodeMoreOptions.name,
      options: [
        if (episode.isDownloaded) ...[
          ActionOption(text.playNext, () async => upNext.playNext([metadata])),
          ActionOption(text.addToUpNext, () async => upNext.add([metadata])),
          ActionOption(
            text.podcastDeleteDownload,
            () => services.downloads.deleteDownload(episode),
          ),
        ] else
          ActionOption(text.podcastDownload, () async {
            await services.downloads.enqueue(episode);
            unawaited(services.downloads.processQueue());
          }),
        ActionOption(
          episode.isPlayed ? text.podcastMarkUnplayed : text.podcastMarkPlayed,
          () {
            episode
              ..isPlayed = !episode.isPlayed
              ..playedAt = episode.isPlayed ? null : DateTime.now()
              ..positionSeconds = 0;
            return repository.saveEpisode(episode);
          },
        ),
        ActionOption(text.podcastUnsubscribe, () async {
          router.goNamed(Routes.podcasts.name);
          await repository.unsubscribe(episode.showFeedUrl);
        }),
        ActionOption(text.cancelText),
      ],
    );
  }
}
