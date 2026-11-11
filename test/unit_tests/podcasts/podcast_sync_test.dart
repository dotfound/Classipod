import 'dart:io';

import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/podcast_download_service.dart';
import 'package:classipod/core/podcasts/podcast_feed_client.dart';
import 'package:classipod/core/podcasts/podcast_repository.dart';
import 'package:classipod/core/podcasts/podcast_sync.dart';
import 'package:classipod/hive/hive_registrar.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

bool adaptersRegistered = false;

const feedUrl = 'https://example.com/feed.xml';

String feedWith(int count) {
  final items = [
    for (var i = count; i >= 1; i--)
      '<item><title>Episode $i</title><guid>ep-$i</guid>'
          '<pubDate>${i.toString().padLeft(2, '0')} Nov 2026 06:00:00 GMT'
          '</pubDate><enclosure url="https://example.com/ep$i.mp3" '
          'type="audio/mpeg"/></item>',
  ];
  return '<rss><channel><title>Show</title>${items.join()}</channel></rss>';
}

void main() {
  late Directory directory;
  late PodcastRepository repository;
  late PodcastDownloadService downloads;
  late PodcastSync sync;
  late DateTime now;
  late int feedItems;
  late Set<String> failing;
  late List<String> downloaded;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('podcast_sync');
    Hive.init('${directory.path}/hive');
    if (!adaptersRegistered) Hive.registerAdapters();
    adaptersRegistered = true;
    now = DateTime.utc(2026, 11, 11, 12);
    feedItems = 5;
    failing = {};
    downloaded = [];
    final client = MockClient((request) async {
      final url = request.url.toString();
      if (url == feedUrl) return http.Response(feedWith(feedItems), 200);
      if (failing.contains(url)) return http.Response('nope', 500);
      downloaded.add(url);
      return http.Response.bytes(List.filled(2048, 7), 200);
    });
    repository = PodcastRepository(
      showsBox: await Hive.openBox(PodcastRepository.showsBoxName),
      episodesBox: await Hive.openBox(PodcastRepository.episodesBoxName),
      feedClient: PodcastFeedClient(client: client),
      storageRoot: '${directory.path}/podcasts',
      now: () => now,
    );
    downloads = PodcastDownloadService(repository: repository, client: client);
    sync = PodcastSync(repository: repository, downloads: downloads);
    await repository.subscribe(feedUrl);
  });

  tearDown(() async {
    await repository.close();
    await Hive.deleteFromDisk();
    directory.deleteSync(recursive: true);
  });

  PodcastEpisode episode(int number) => repository
      .episodesOf(feedUrl)
      .firstWhere((episode) => episode.id == 'ep-$number');

  test('downloads the newest three episodes to app storage', () async {
    await sync.run();
    expect(downloaded, [
      'https://example.com/ep5.mp3',
      'https://example.com/ep4.mp3',
      'https://example.com/ep3.mp3',
    ]);
    final newest = episode(5);
    expect(newest.downloadState, PodcastDownloadState.done);
    expect(File(newest.localPath!).lengthSync(), 2048);
    expect(newest.localPath, startsWith('${directory.path}/podcasts/'));
    expect(File('${newest.localPath}.part').existsSync(), isFalse);
    expect(episode(2).downloadState, PodcastDownloadState.none);
  });

  test('a new episode in the feed is downloaded on the next run', () async {
    await sync.run();
    downloaded.clear();
    feedItems = 6;
    await sync.run();
    expect(downloaded, ['https://example.com/ep6.mp3']);
    expect(episode(6).isDownloaded, isTrue);
  });

  test('failed downloads are retried on the next run', () async {
    failing.add('https://example.com/ep4.mp3');
    await sync.run();
    expect(episode(4).downloadState, PodcastDownloadState.failed);
    expect(episode(3).isDownloaded, isTrue);
    failing.clear();
    await sync.run();
    expect(episode(4).isDownloaded, isTrue);
  });

  test('played episodes are not downloaded', () async {
    final played = episode(5)..isPlayed = true;
    await repository.saveEpisode(played);
    await sync.run();
    expect(episode(5).downloadState, PodcastDownloadState.none);
    expect(downloaded, hasLength(2));
  });

  test('nothing downloads when downloading is not allowed', () async {
    sync = PodcastSync(
      repository: repository,
      downloads: downloads,
      canDownload: () async => false,
    );
    await sync.run();
    expect(downloaded, isEmpty);
    expect(episode(5).downloadState, PodcastDownloadState.queued);
  });

  test('cleans up files played over 24 hours ago only', () async {
    await sync.run();
    final old = episode(5)
      ..isPlayed = true
      ..playedAt = now.subtract(const Duration(hours: 25));
    final recent = episode(4)
      ..isPlayed = true
      ..playedAt = now.subtract(const Duration(hours: 2));
    final replaying = episode(3)
      ..isPlayed = true
      ..positionSeconds = 30
      ..playedAt = now.subtract(const Duration(days: 3));
    final oldPath = old.localPath!;
    await repository.saveEpisode(old);
    await repository.saveEpisode(recent);
    await repository.saveEpisode(replaying);
    expect(await sync.cleanUp(), 1);
    expect(File(oldPath).existsSync(), isFalse);
    expect(episode(5).localPath, isNull);
    expect(episode(5).downloadState, PodcastDownloadState.none);
    expect(episode(4).isDownloaded, isTrue);
    expect(episode(3).isDownloaded, isTrue);
    expect(await sync.cleanUp(allPlayed: true), 1);
    expect(episode(4).isDownloaded, isFalse);
  });

  test('unsubscribe deletes downloaded files', () async {
    await sync.run();
    final folder = Directory(repository.showDirectory(feedUrl)!);
    expect(folder.existsSync(), isTrue);
    await repository.unsubscribe(feedUrl);
    expect(folder.existsSync(), isFalse);
  });
}
