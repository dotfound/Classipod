import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/widgets/options_list_tile.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ActionOption {
  final String title;

  /// Runs after the modal has closed. Null just closes the modal.
  final Future<void> Function()? action;

  const ActionOption(this.title, [this.action]);
}

/// A click-wheel options modal built from a list of titled actions.
class ActionOptionsModal extends ConsumerStatefulWidget {
  final String routeName;
  final List<ActionOption> options;

  const ActionOptionsModal({
    super.key,
    required this.routeName,
    required this.options,
  });

  @override
  ConsumerState createState() => _ActionOptionsModalState();
}

class _ActionOptionsModalState extends ConsumerState<ActionOptionsModal>
    with CustomScreen {
  @override
  String get routeName => widget.routeName;

  @override
  List<ActionOption> get displayItems => widget.options;

  @override
  Future<void> onSelectPressed() => _run(selectedDisplayItem);

  Future<void> _run(int index) async {
    if (index < 0 || index >= displayItems.length) return;
    setState(() => selectedDisplayItem = index);
    final action = displayItems[index].action;
    context.pop();
    await action?.call();
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
        itemBuilder: (context, index) => OptionsListTile(
          text: displayItems[index].title,
          isSelected: index == selectedDisplayItem,
          onTap: () async => _run(index),
        ),
      ),
    );
  }
}
