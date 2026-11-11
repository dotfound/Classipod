import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/services/playback/up_next_controller.dart';
import 'package:classipod/core/widgets/empty_state_widget.dart';
import 'package:classipod/features/custom_screen_elements/action_options_modal.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Up Next list. Selecting an item offers Remove, Move to top and
/// Clear Up Next.
class UpNextScreen extends ConsumerStatefulWidget {
  const UpNextScreen({super.key});

  @override
  ConsumerState createState() => _UpNextScreenState();
}

class _UpNextScreenState extends ConsumerState<UpNextScreen> with CustomScreen {
  @override
  String get routeName => Routes.upNext.name;

  @override
  List<MusicMetadata> get displayItems => ref.read(upNextProvider);

  @override
  void onSelectPressed() => _openOptions(selectedDisplayItem);

  void _openOptions(int index) {
    if (index >= displayItems.length) return;
    setState(() => selectedDisplayItem = index);
    context.goNamed(Routes.upNextMoreOptions.name, extra: index);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(upNextProvider);
    if (items.isEmpty) {
      return CupertinoPageScaffold(
        child: EmptyStateWidget(
          emptyDescription: context.localization.upNextEmpty,
        ),
      );
    }
    final selected = selectedDisplayItem.clamp(0, items.length - 1);
    return CupertinoPageScaffold(
      child: CupertinoScrollbar(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          itemCount: items.length,
          prototypeItem: SettingsListTile(
            text: '',
            isSelected: false,
            onTap: () {},
          ),
          itemBuilder: (context, index) => SettingsListTile(
            text: items[index].getTrackName,
            value: items[index].isPodcastEpisode
                ? context.localization.podcastsScreenTitle
                : null,
            isSelected: selected == index,
            onTap: () => _openOptions(index),
          ),
        ),
      ),
    );
  }
}

class UpNextOptionsModal extends ConsumerWidget {
  final int index;

  const UpNextOptionsModal({super.key, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upNext = ref.read(upNextProvider.notifier);
    final text = context.localization;
    return ActionOptionsModal(
      routeName: Routes.upNextMoreOptions.name,
      options: [
        ActionOption(text.upNextRemove, () async => upNext.remove(index)),
        ActionOption(text.upNextMoveToTop, () async => upNext.moveToTop(index)),
        ActionOption(text.upNextClear, () async => upNext.clear()),
        ActionOption(text.cancelText),
      ],
    );
  }
}
