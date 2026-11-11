import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/widgets/options_list_tile.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _PlaylistSongsMoreOptions {
  playNext,
  addToUpNext,
  removeSongFromPlaylist,
  cancel;

  String title(BuildContext context) {
    switch (this) {
      case playNext:
        return context.localization.playNext;
      case addToUpNext:
        return context.localization.addToUpNext;
      case removeSongFromPlaylist:
        return context.localization.removeSongFromThePlaylist;
      case cancel:
        return context.localization.cancelText;
    }
  }
}

class PlaylistSongsMoreOptionsModal extends ConsumerStatefulWidget {
  const PlaylistSongsMoreOptionsModal({super.key});

  /// Results popped for the Up Next options; the playlist screen acts on
  /// them because it knows which song was selected.
  static const playNext = 'playNext';
  static const addToUpNext = 'addToUpNext';

  @override
  ConsumerState createState() => _PlaylistSongsMoreOptionsModalState();
}

class _PlaylistSongsMoreOptionsModalState
    extends ConsumerState<PlaylistSongsMoreOptionsModal>
    with CustomScreen {
  @override
  String get routeName => Routes.playlistSongsMoreOptions.name;

  @override
  List<_PlaylistSongsMoreOptions> get displayItems =>
      _PlaylistSongsMoreOptions.values;

  @override
  Future<void> onSelectPressed() =>
      _performAction(displayItems[selectedDisplayItem]);

  Future<void> _performAction(_PlaylistSongsMoreOptions optionItem) async {
    setState(() => selectedDisplayItem = displayItems.indexOf(optionItem));
    switch (optionItem) {
      case _PlaylistSongsMoreOptions.playNext:
        context.pop(PlaylistSongsMoreOptionsModal.playNext);
        break;
      case _PlaylistSongsMoreOptions.addToUpNext:
        context.pop(PlaylistSongsMoreOptionsModal.addToUpNext);
        break;
      case _PlaylistSongsMoreOptions.removeSongFromPlaylist:
        context.pop(true);
        break;
      case _PlaylistSongsMoreOptions.cancel:
        context.pop(false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        border: Border.all(color: context.appOutlineColor),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        controller: scrollController,
        itemCount: displayItems.length,
        prototypeItem: const OptionsListTile(text: '', isSelected: false),
        itemBuilder: (context, index) {
          return OptionsListTile(
            text: displayItems[index].title(context),
            isSelected: index == selectedDisplayItem,
            onTap: () async => _performAction(displayItems[index]),
          );
        },
      ),
    );
  }
}
