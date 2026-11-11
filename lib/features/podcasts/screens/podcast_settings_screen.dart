import 'dart:async';
import 'dart:io';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/podcasts/podcast_background.dart';
import 'package:classipod/core/podcasts/podcast_providers.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/settings/widgets/settings_list_tile.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

enum _PodcastSetting {
  wifiOnly,
  keepLatest,
  storageUsed,
  deleteAllPlayed,
  importOpml,
  syncNow,
}

/// Settings → Podcasts.
class PodcastSettingsScreen extends ConsumerStatefulWidget {
  const PodcastSettingsScreen({super.key});

  /// The file "Import OPML" reads before falling back to a file picker:
  /// `<external files dir>/podcasts.opml`, which adb can push to.
  static const importFileName = 'podcasts.opml';

  @override
  ConsumerState createState() => _PodcastSettingsScreenState();
}

class _PodcastSettingsScreenState extends ConsumerState<PodcastSettingsScreen>
    with CustomScreen {
  static const _keepChoices = [1, 2, 3, 5, 10];
  int? _storageBytes;
  String? _importResult;

  @override
  String get routeName => Routes.podcastSettings.name;

  @override
  List<_PodcastSetting> get displayItems => [
    _PodcastSetting.wifiOnly,
    _PodcastSetting.keepLatest,
    _PodcastSetting.storageUsed,
    _PodcastSetting.deleteAllPlayed,
    _PodcastSetting.importOpml,
    if (kDebugMode) _PodcastSetting.syncNow,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_measureStorage());
  }

  Future<void> _measureStorage() async {
    var bytes = 0;
    try {
      final root = Directory(await PodcastBackground.storageRoot());
      if (root.existsSync()) {
        await for (final entity in root.list(recursive: true)) {
          if (entity is File) bytes += await entity.length();
        }
      }
    } on FileSystemException catch (_) {}
    if (mounted) setState(() => _storageBytes = bytes);
  }

  String _title(_PodcastSetting setting) {
    final text = context.localization;
    return switch (setting) {
      _PodcastSetting.wifiOnly => text.podcastWifiOnly,
      _PodcastSetting.keepLatest => text.podcastKeepLatest,
      _PodcastSetting.storageUsed => text.podcastStorageUsed,
      _PodcastSetting.deleteAllPlayed => text.podcastDeleteAllPlayed,
      _PodcastSetting.importOpml => text.podcastImportOpml,
      _PodcastSetting.syncNow => text.podcastSyncNow,
    };
  }

  String? _value(_PodcastSetting setting) {
    final settings = ref.read(podcastSettingsProvider);
    final text = context.localization;
    switch (setting) {
      case _PodcastSetting.wifiOnly:
        return settings.wifiOnly ? text.tileValueOn : text.tileValueOff;
      case _PodcastSetting.keepLatest:
        return '${settings.keepLatest}';
      case _PodcastSetting.storageUsed:
        final bytes = _storageBytes;
        if (bytes == null) return '…';
        return bytes >= 1 << 30
            ? '${(bytes / (1 << 30)).toStringAsFixed(1)} GB'
            : '${(bytes / (1 << 20)).round()} MB';
      case _PodcastSetting.importOpml:
        return _importResult;
      case _PodcastSetting.deleteAllPlayed:
      case _PodcastSetting.syncNow:
        return null;
    }
  }

  @override
  Future<void> onSelectPressed() => _run(selectedDisplayItem);

  Future<void> _run(int index) async {
    setState(() => selectedDisplayItem = index);
    final settings = ref.read(podcastSettingsProvider);
    final services = ref.read(podcastServicesProvider).value;
    final sync = ref.read(podcastSyncControllerProvider.notifier);
    switch (displayItems[index]) {
      case _PodcastSetting.wifiOnly:
        final wifiOnly = !settings.wifiOnly;
        await settings.setWifiOnly(wifiOnly);
        await PodcastBackground.schedule(wifiOnly: wifiOnly);
      case _PodcastSetting.keepLatest:
        final next =
            _keepChoices[(_keepChoices.indexOf(settings.keepLatest) + 1) %
                _keepChoices.length];
        await settings.setKeepLatest(next);
        if (services != null) {
          for (final show in services.repository.shows) {
            show.keepLatest = next;
            await services.repository.saveShow(show);
          }
          unawaited(services.sync.run(refresh: false));
        }
      case _PodcastSetting.storageUsed:
        await _measureStorage();
      case _PodcastSetting.deleteAllPlayed:
        await services?.sync.cleanUp(allPlayed: true);
        await _measureStorage();
      case _PodcastSetting.importOpml:
        final opml = await _readOpml();
        if (opml == null) break;
        final failed = await sync.importOpml(opml);
        _importResult = failed.isEmpty ? '✓' : '${failed.length} ✗';
        unawaited(sync.sync(force: true));
      case _PodcastSetting.syncNow:
        await sync.sync(force: true);
    }
    if (mounted) setState(() {});
  }

  Future<String?> _readOpml() async {
    try {
      final directory = await getExternalStorageDirectory();
      final pushed = File(
        '${directory?.path}/${PodcastSettingsScreen.importFileName}',
      );
      if (pushed.existsSync()) return await pushed.readAsString();
      final picked = await FilePicker.pickFiles();
      final path =
          picked?.firstOrNull?.path; // ignore: invalid_null_aware_operator
      return path == null ? null : await File(path).readAsString();
    } catch (error) {
      debugPrint('Could not read OPML: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(podcastRevisionProvider);
    return CupertinoPageScaffold(
      child: CupertinoScrollbar(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          itemCount: displayItems.length,
          prototypeItem: SettingsListTile(
            text: '',
            isSelected: false,
            onTap: () {},
          ),
          itemBuilder: (context, index) => SettingsListTile(
            text: _title(displayItems[index]),
            value: _value(displayItems[index]),
            isSelected: selectedDisplayItem == index,
            onTap: () async => _run(index),
          ),
        ),
      ),
    );
  }
}
