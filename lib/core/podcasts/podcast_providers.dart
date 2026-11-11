import 'dart:async';

import 'package:classipod/core/models/shared_preference_keys.dart';
import 'package:classipod/core/podcasts/podcast_background.dart';
import 'package:classipod/core/podcasts/podcast_download_service.dart';
import 'package:classipod/core/podcasts/podcast_opml.dart';
import 'package:classipod/core/podcasts/podcast_playback.dart';
import 'package:classipod/core/podcasts/podcast_repository.dart';
import 'package:classipod/core/podcasts/podcast_sync.dart';
import 'package:classipod/core/providers/shared_preferences_with_cache_provider.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PodcastServices {
  final PodcastRepository repository;
  final PodcastDownloadService downloads;
  final PodcastSync sync;
  final PodcastPlaybackTracker playback;

  const PodcastServices({
    required this.repository,
    required this.downloads,
    required this.sync,
    required this.playback,
  });
}

/// Podcast preferences kept in shared preferences.
class PodcastSettings {
  final Ref ref;

  const PodcastSettings(this.ref);

  static const autoSyncInterval = Duration(minutes: 30);

  dynamic get _preferences =>
      ref.read(sharedPreferencesWithCacheProvider).requireValue;

  bool get wifiOnly =>
      _preferences.getBool(SharedPreferencesKeys.podcastWifiOnly.name)
          as bool? ??
      true;

  int get keepLatest =>
      _preferences.getInt(SharedPreferencesKeys.podcastKeepLatest.name)
          as int? ??
      3;

  bool get seedImported =>
      _preferences.getBool(SharedPreferencesKeys.podcastSeedImported.name)
          as bool? ??
      false;

  DateTime? get lastSync {
    final millis =
        _preferences.getInt(SharedPreferencesKeys.podcastLastSync.name) as int?;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setWifiOnly(bool value) async =>
      _preferences.setBool(SharedPreferencesKeys.podcastWifiOnly.name, value);

  Future<void> setKeepLatest(int value) async =>
      _preferences.setInt(SharedPreferencesKeys.podcastKeepLatest.name, value);

  Future<void> setSeedImported() async => _preferences.setBool(
    SharedPreferencesKeys.podcastSeedImported.name,
    true,
  );

  Future<void> setLastSync(DateTime value) async => _preferences.setInt(
    SharedPreferencesKeys.podcastLastSync.name,
    value.millisecondsSinceEpoch,
  );
}

final podcastSettingsProvider = Provider<PodcastSettings>(PodcastSettings.new);

/// Opens the podcast boxes. Awaited during app start-up on Android.
final podcastServicesProvider = FutureProvider<PodcastServices>((ref) async {
  final settings = ref.read(podcastSettingsProvider);
  late final PodcastSync sync;
  await PodcastBackground.claimForApp(() => sync.run());
  final repository = await PodcastRepository.open(
    storageRoot: await PodcastBackground.storageRoot(),
  );
  final downloads = PodcastDownloadService(repository: repository);
  sync = PodcastSync(
    repository: repository,
    downloads: downloads,
    canDownload: () async {
      if (!settings.wifiOnly) return true;
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    },
  );
  final playback = PodcastPlaybackTracker(
    repository: repository,
    handler: ref.read(libraryAudioHandlerProvider),
    player: ref.read(audioPlayerProvider),
  );
  ref.onDispose(() async {
    await playback.dispose();
    await repository.close();
  });
  return PodcastServices(
    repository: repository,
    downloads: downloads,
    sync: sync,
    playback: playback,
  );
});

/// Bumps whenever a show or episode changes, so screens can rebuild.
final podcastRevisionProvider = NotifierProvider<PodcastRevisionNotifier, int>(
  PodcastRevisionNotifier.new,
);

class PodcastRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final services = ref.watch(podcastServicesProvider).value;
    if (services != null) {
      final subscription = services.repository.changes.listen(
        (_) => state = state + 1,
      );
      ref.onDispose(subscription.cancel);
    }
    return 0;
  }
}

/// Download progress (0 to 1) by episode storage key.
final podcastDownloadProgressProvider =
    NotifierProvider<PodcastDownloadProgressNotifier, Map<String, double>>(
      PodcastDownloadProgressNotifier.new,
    );

class PodcastDownloadProgressNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    final progress = ref
        .watch(podcastServicesProvider)
        .value
        ?.downloads
        .progress;
    if (progress == null) return const {};
    void listener() => state = progress.value;
    progress.addListener(listener);
    ref.onDispose(() => progress.removeListener(listener));
    return progress.value;
  }
}

final podcastSyncControllerProvider =
    NotifierProvider<PodcastSyncController, bool>(PodcastSyncController.new);

/// Runs the sync pipeline; the state is whether a sync is in progress.
class PodcastSyncController extends Notifier<bool> {
  @override
  bool build() => false;

  static const seedAsset = 'assets/podcasts_seed.opml';

  /// Run once at app start: schedules the background task, imports the
  /// bundled subscriptions on first launch, then syncs.
  Future<void> start() async {
    try {
      final settings = ref.read(podcastSettingsProvider);
      await ref.read(podcastServicesProvider.future);
      await PodcastBackground.schedule(wifiOnly: settings.wifiOnly);
      if (!settings.seedImported) {
        final failed = await importOpml(await rootBundle.loadString(seedAsset));
        if (failed.isEmpty) await settings.setSeedImported();
        await sync(force: true);
      } else {
        await sync();
      }
    } catch (error) {
      debugPrint('Podcast start-up failed: $error');
    }
  }

  /// Subscribes to every feed in an OPML document. Returns the feed URLs
  /// that could not be subscribed.
  Future<List<String>> importOpml(String opml) async {
    final services = await ref.read(podcastServicesProvider.future);
    final keepLatest = ref.read(podcastSettingsProvider).keepLatest;
    final failed = <String>[];
    for (final url in parseOpmlFeedUrls(opml)) {
      try {
        await services.repository.subscribe(url, keepLatest: keepLatest);
      } catch (error) {
        debugPrint('Could not subscribe to $url: $error');
        failed.add(url);
      }
    }
    return failed;
  }

  /// [force] skips the 30 minute throttle used for app start.
  Future<void> sync({bool force = false}) async {
    final services = await ref.read(podcastServicesProvider.future);
    final settings = ref.read(podcastSettingsProvider);
    final last = settings.lastSync;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < PodcastSettings.autoSyncInterval) {
      // Still resume anything queued, without refetching feeds.
      unawaited(services.sync.run(refresh: false));
      return;
    }
    state = true;
    try {
      await settings.setLastSync(DateTime.now());
      await services.sync.run();
    } catch (error) {
      debugPrint('Podcast sync failed: $error');
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
