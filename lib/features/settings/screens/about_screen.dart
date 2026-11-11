import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/extensions/go_router_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/providers/filtered_audio_files_provider.dart';
import 'package:classipod/features/device/models/device_action.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/music/artists/providers/artist_names_provider.dart';
import 'package:classipod/features/settings/widgets/about_list_tile.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  /// Presses of Select needed before the long hold opens maintenance.
  static const maintenancePresses = 7;

  /// The hold is 3 seconds; a long press is recognised after 0.5 seconds.
  static const maintenanceHold = Duration(milliseconds: 2500);

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  int _selectPresses = 0;
  DateTime? _holdStarted;

  /// Hidden maintenance exit: press Select 7 times, then hold it for 3
  /// seconds.
  void _trackMaintenanceGesture(DeviceAction action) {
    switch (action) {
      case DeviceAction.select:
        _selectPresses++;
      case DeviceAction.selectLongPress:
        _holdStarted = DateTime.now();
      case DeviceAction.longPressEnd:
        final started = _holdStarted;
        _holdStarted = null;
        final unlocked =
            _selectPresses >= AboutScreen.maintenancePresses &&
            started != null &&
            DateTime.now().difference(started) >= AboutScreen.maintenanceHold;
        _selectPresses = 0;
        if (unlocked) context.goNamed(Routes.maintenance.name);
      default:
        _selectPresses = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(deviceButtonsServiceProvider, (prevState, newState) {
      if (newState == null ||
          context.router.locationNamed != Routes.about.name) {
        return;
      } else if (newState == DeviceAction.menu) {
        context.pop();
      } else {
        _trackMaintenanceGesture(newState);
      }
    });

    return CupertinoPageScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  context.localization.appTitle,
                  style: CupertinoTheme.of(context).textTheme.textStyle
                      .copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.appPrimaryTextColor,
                      ),
                ),
                const SizedBox(height: 10),
                AboutListTile(
                  titleText: context.localization.songsScreenTitle,
                  valueText:
                      "${ref.read(filteredAudioFilesProvider).requireValue.length}",
                ),
                AboutListTile(
                  titleText: context.localization.artistsScreenTitle,
                  valueText: "${ref.read(artistNamesProvider).length}",
                ),
                AboutListTile(
                  titleText: context.localization.albumsScreenTitle,
                  valueText: "${ref.read(albumDetailsProvider).length}",
                ),
                AboutListTile(
                  titleText: context.localization.versionAboutScreenTitle,
                  valueText: "2.1.0",
                ),
                AboutListTile(
                  titleText: context.localization.madeWithLoveTitle,
                  valueText: "Aditya",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
