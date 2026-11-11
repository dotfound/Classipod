import 'dart:async';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/podcasts/podcast_providers.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/podcasts/providers/podcast_library_provider.dart';
import 'package:classipod/features/podcasts/widgets/podcast_list_tile.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shows sorted by newest episode, with Refresh as the last row.
class PodcastsScreen extends ConsumerStatefulWidget {
  const PodcastsScreen({super.key});

  @override
  ConsumerState createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen>
    with CustomScreen {
  @override
  String get routeName => Routes.podcasts.name;

  @override
  String get screenStateKey => Routes.podcasts.name;

  @override
  List<PodcastShowSummary> get displayItems =>
      ref.read(podcastShowSummariesProvider);

  @override
  int get extraDisplayItems => 1;

  @override
  set extraDisplayItems(int value) {}

  @override
  void onSelectPressed() => _select(selectedDisplayItem);

  void _select(int index) {
    setState(() => selectedDisplayItem = index);
    if (index >= displayItems.length) {
      unawaited(
        ref.read(podcastSyncControllerProvider.notifier).sync(force: true),
      );
      return;
    }
    context.goNamed(
      Routes.podcastShow.name,
      queryParameters: {'feed': displayItems[index].show.feedUrl},
    );
  }

  @override
  Widget build(BuildContext context) {
    final shows = ref.watch(podcastShowSummariesProvider);
    final syncing = ref.watch(podcastSyncControllerProvider);
    final loading = ref.watch(podcastServicesProvider).isLoading;
    return CupertinoPageScaffold(
      child: CupertinoScrollbar(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          itemCount: shows.length + 1,
          prototypeItem: const PodcastListTile(text: '', isSelected: false),
          itemBuilder: (context, index) {
            if (index == shows.length) {
              return PodcastListTile(
                text: loading
                    ? context.localization.podcastLoading
                    : syncing
                    ? context.localization.podcastRefreshing
                    : context.localization.podcastRefresh,
                isSelected: selectedDisplayItem == index,
                onTap: () => _select(index),
              );
            }
            final summary = shows[index];
            return PodcastListTile(
              text: summary.show.title,
              dot: summary.hasUnplayed ? PodcastDot.full : PodcastDot.none,
              isSelected: selectedDisplayItem == index,
              onTap: () => _select(index),
            );
          },
        ),
      ),
    );
  }
}
