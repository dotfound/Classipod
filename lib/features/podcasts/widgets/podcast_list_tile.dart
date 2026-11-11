import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/theme/ipod_gradients.dart';
import 'package:classipod/core/theme/ipod_typography.dart';
import 'package:classipod/core/widgets/selected_marquee_text.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

enum PodcastDot { none, half, full }

/// A menu row with a leading played-state dot and a trailing value.
class PodcastListTile extends StatelessWidget {
  final String text;
  final String? value;
  final PodcastDot dot;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PodcastListTile({
    super.key,
    required this.text,
    this.value,
    this.dot = PodcastDot.none,
    required this.isSelected,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = IpodTypography.menu.copyWith(
      color: isSelected
          ? context.appInverseTextColor
          : context.appPrimaryTextColor,
    );
    final dotColor = isSelected
        ? context.appInverseTextColor
        : CupertinoColors.activeBlue;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 30,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isSelected ? IpodGradients.selectionFor(context) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              spacing: 5,
              children: [
                SizedBox(
                  width: 10,
                  child: dot == PodcastDot.none
                      ? null
                      : Icon(
                          dot == PodcastDot.full
                              ? CupertinoIcons.circle_fill
                              : CupertinoIcons.circle_lefthalf_fill,
                          size: 10,
                          color: dotColor,
                        ),
                ),
                Expanded(
                  child: SelectedMarqueeText(
                    text,
                    isSelected: isSelected,
                    style: textStyle,
                  ),
                ),
                if (value != null)
                  Text(value!, style: textStyle.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
