import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/services/kiosk_service.dart';
import 'package:classipod/core/widgets/display_list_tile.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The hidden maintenance menu: leaves the locked-down mode to reach
/// Android's Wi-Fi or Bluetooth settings.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen>
    with CustomScreen {
  @override
  String get routeName => Routes.maintenance.name;

  @override
  List<Future<void> Function()> get displayItems => [
    KioskService.openWifiSettings,
    KioskService.openBluetoothSettings,
  ];

  @override
  Future<void> onSelectPressed() => _open(selectedDisplayItem);

  Future<void> _open(int index) async {
    setState(() => selectedDisplayItem = index);
    await displayItems[index]();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.localization.maintenanceWifi,
      context.localization.maintenanceBluetooth,
    ];
    return CupertinoPageScaffold(
      child: ListView.builder(
        controller: scrollController,
        itemCount: titles.length,
        itemBuilder: (context, index) => DisplayListTile(
          text: titles[index],
          isSelected: selectedDisplayItem == index,
          onTap: () async => _open(index),
        ),
      ),
    );
  }
}
