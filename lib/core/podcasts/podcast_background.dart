// The worker entry point makes the analyzer treat this file as its own
// program, so members used only by the app look unreachable.
// ignore_for_file: unreachable_from_main
import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:classipod/core/podcasts/podcast_download_service.dart';
import 'package:classipod/core/podcasts/podcast_repository.dart';
import 'package:classipod/core/podcasts/podcast_sync.dart';
import 'package:classipod/hive/hive_registrar.g.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

/// Background auto-download. Hive boxes must only be open in one isolate at
/// a time, so the app and the worker hand over through named ports: the
/// worker asks a live app to sync instead, and a starting app asks a
/// running worker to stop.
class PodcastBackground {
  PodcastBackground._();

  static const taskName = 'uk.dotfound.pixelpod.podcastSync';
  static const hiveSubDirectory = 'ClassiPod';
  static const _appPort = 'pixelpod-podcast-app';
  static const _workerPort = 'pixelpod-podcast-worker';

  static Future<String> storageRoot() async =>
      '${(await getApplicationDocumentsDirectory()).path}/podcasts';

  /// Registers the two-hourly task. Called on every app start.
  static Future<void> schedule({required bool wifiOnly}) async {
    await Workmanager().initialize(podcastCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 2),
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  /// Called by the app before it opens the podcast boxes. Stops a running
  /// worker, then listens for workers that want the app to sync for them.
  static Future<void> claimForApp(Future<void> Function() sync) async {
    final worker = ui.IsolateNameServer.lookupPortByName(_workerPort);
    if (worker != null) {
      final reply = ReceivePort();
      worker.send(reply.sendPort);
      try {
        await reply.first.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        debugPrint('Podcast worker did not stop in time');
      }
      reply.close();
    }
    final port = ReceivePort();
    ui.IsolateNameServer.removePortNameMapping(_appPort);
    ui.IsolateNameServer.registerPortWithName(port.sendPort, _appPort);
    port.listen((message) {
      if (message is SendPort) {
        message.send(true);
        unawaited(sync());
      }
    });
  }

  /// The worker's entry point. Returns true so the task is not retried
  /// early; failed downloads are picked up on the next run.
  static Future<bool> runHeadless() async {
    final app = ui.IsolateNameServer.lookupPortByName(_appPort);
    if (app != null) {
      final reply = ReceivePort();
      app.send(reply.sendPort);
      try {
        await reply.first.timeout(const Duration(seconds: 3));
        reply.close();
        return true;
      } on TimeoutException {
        // The app isolate has gone; its port is stale.
        reply.close();
        ui.IsolateNameServer.removePortNameMapping(_appPort);
      }
    }
    final stop = ReceivePort();
    ui.IsolateNameServer.removePortNameMapping(_workerPort);
    ui.IsolateNameServer.registerPortWithName(stop.sendPort, _workerPort);
    PodcastRepository? repository;
    SendPort? waiting;
    try {
      await Hive.initFlutter(hiveSubDirectory);
      try {
        Hive.registerAdapters();
      } on HiveError {
        // Already registered in this isolate.
      }
      repository = await PodcastRepository.open(
        storageRoot: await storageRoot(),
      );
      final downloads = PodcastDownloadService(repository: repository);
      stop.listen((message) {
        if (message is SendPort) {
          waiting = message;
          downloads.cancel();
        }
      });
      await PodcastSync(repository: repository, downloads: downloads).run();
    } catch (error) {
      debugPrint('Podcast background sync failed: $error');
    } finally {
      await repository?.close();
      ui.IsolateNameServer.removePortNameMapping(_workerPort);
      stop.close();
      waiting?.send(true);
    }
    return true;
  }
}

@pragma('vm:entry-point')
void podcastCallbackDispatcher() {
  Workmanager().executeTask(
    (task, inputData) => PodcastBackground.runHeadless(),
  );
}
