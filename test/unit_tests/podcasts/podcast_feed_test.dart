import 'dart:io';

import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/podcast_feed_client.dart';
import 'package:classipod/core/podcasts/podcast_opml.dart';
import 'package:classipod/core/podcasts/podcast_repository.dart';
import 'package:classipod/hive/hive_registrar.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/test_files/podcasts/$name.xml').readAsStringSync();

bool adaptersRegistered = false;

const feedUrl = 'https://example.com/feed.xml';

void main() {
  group('feed parsing', () {
    test('parses a normal feed and skips items without audio', () {
      final feed = parsePodcastFeed(fixture('normal'), feedUrl);
      expect(feed.title, 'Normal Show');
      expect(feed.author, 'Normal Author');
      expect(feed.artworkUrl, 'https://example.com/itunes.jpg');
      expect(feed.episodes.map((e) => e.id), ['ep-2', 'ep-1']);
      final episode = feed.episodes.first;
      expect(episode.description, 'Second & best.\nMore notes');
      expect(episode.durationSeconds, 3600);
      expect(episode.pubDate, DateTime.utc(2026, 11, 10, 6));
      expect(episode.enclosureUrl, 'https://example.com/ep2.mp3');
      expect(feed.episodes.last.pubDate, DateTime.utc(2026, 11, 3, 6));
    });

    test('handles seconds, MM:SS and HH:MM:SS durations', () {
      final feed = parsePodcastFeed(fixture('odd_durations'), feedUrl);
      expect(feed.artworkUrl, 'https://example.com/plain.jpg');
      expect(feed.episodes.map((e) => e.durationSeconds), [
        754,
        754,
        3723,
        0,
        0,
      ]);
    });

    test('falls back to the enclosure URL when the guid is missing', () {
      final feed = parsePodcastFeed(fixture('missing_guids'), feedUrl);
      expect(feed.episodes.map((e) => e.id), [
        'https://example.com/one.mp3',
        'https://example.com/two.mp3',
      ]);
      expect(feed.episodes.first.pubDate, DateTime.utc(2026, 11, 2, 9));
    });

    test('rejects documents that are not feeds', () {
      expect(
        () => parsePodcastFeed('<html></html>', feedUrl),
        throwsA(isA<PodcastFeedException>()),
      );
      expect(
        () => parsePodcastFeed('not xml', feedUrl),
        throwsA(isA<PodcastFeedException>()),
      );
    });
  });

  group('opml', () {
    test('reads feed URLs once each, including nested outlines', () {
      const opml =
          '<opml><body><outline text="Folder">'
          '<outline type="rss" xmlUrl="https://a.example/feed"/>'
          '</outline><outline xmlUrl="https://b.example/feed"/>'
          '<outline xmlUrl="https://a.example/feed"/>'
          '<outline text="No feed"/></body></opml>';
      expect(parseOpmlFeedUrls(opml), [
        'https://a.example/feed',
        'https://b.example/feed',
      ]);
      expect(parseOpmlFeedUrls('not xml'), isEmpty);
    });

    test('the bundled seed lists every subscription', () {
      final urls = parseOpmlFeedUrls(
        File('assets/podcasts_seed.opml').readAsStringSync(),
      );
      expect(urls, hasLength(12));
    });
  });

  group('repository', () {
    late Directory directory;
    late List<http.Request> requests;
    late http.Response Function(http.Request) respond;
    late PodcastRepository repository;

    setUp(() async {
      directory = Directory.systemTemp.createTempSync('podcast_repo');
      Hive.init(directory.path);
      if (!adaptersRegistered) Hive.registerAdapters();
      adaptersRegistered = true;
      requests = [];
      respond = (_) => http.Response.bytes(
        File('test/test_files/podcasts/normal.xml').readAsBytesSync(),
        200,
        headers: {'etag': '"v1"', 'last-modified': 'yesterday'},
      );
      repository = await PodcastRepository.open(
        feedClient: PodcastFeedClient(
          client: MockClient((request) async {
            requests.add(request);
            return respond(request);
          }),
        ),
      );
    });

    tearDown(() async {
      await repository.close();
      await Hive.deleteFromDisk();
      directory.deleteSync(recursive: true);
    });

    test('subscribe stores the show and its episodes newest first', () async {
      final show = await repository.subscribe(feedUrl);
      expect(show.title, 'Normal Show');
      expect(show.etag, '"v1"');
      expect(show.autoDownload, isTrue);
      expect(show.keepLatest, 3);
      expect(repository.episodesOf(feedUrl).map((e) => e.id), ['ep-2', 'ep-1']);
      expect(await repository.subscribe(feedUrl), same(show));
      expect(repository.shows, hasLength(1));
    });

    test('refresh merges without duplicates and keeps local state', () async {
      final show = await repository.subscribe(feedUrl);
      final episode = repository.episodesOf(feedUrl).last
        ..positionSeconds = 42
        ..isPlayed = true
        ..localPath = '/tmp/ep1.mp3'
        ..downloadState = PodcastDownloadState.done;
      await repository.saveEpisode(episode);
      respond = (_) => http.Response(
        fixture('normal').replaceFirst(
          '<item>',
          '<item><title>Episode Three</title><guid>ep-3</guid>'
              '<pubDate>Wed, 11 Nov 2026 06:00:00 GMT</pubDate>'
              '<enclosure url="https://example.com/ep3.mp3" '
              'type="audio/mpeg"/></item><item>',
        ),
        200,
        headers: {'content-type': 'text/xml; charset=utf-8'},
      );
      expect(await repository.refreshOne(show), isTrue);
      final episodes = repository.episodesOf(feedUrl);
      expect(episodes.map((e) => e.id), ['ep-3', 'ep-2', 'ep-1']);
      expect(episodes.last.positionSeconds, 42);
      expect(episodes.last.isPlayed, isTrue);
      expect(episodes.last.localPath, '/tmp/ep1.mp3');
      expect(episodes.last.downloadState, PodcastDownloadState.done);
    });

    test('sends validators and leaves episodes alone on 304', () async {
      final show = await repository.subscribe(feedUrl);
      respond = (_) => http.Response('', 304);
      expect(await repository.refreshOne(show), isTrue);
      expect(requests.last.headers['If-None-Match'], '"v1"');
      expect(requests.last.headers['If-Modified-Since'], 'yesterday');
      expect(repository.episodesOf(feedUrl), hasLength(2));
      expect(repository.show(feedUrl)!.etag, '"v1"');
    });

    test('a failing feed is reported and keeps existing data', () async {
      await repository.subscribe(feedUrl);
      respond = (_) => http.Response('gone', 404);
      expect(await repository.refreshAll(), [feedUrl]);
      expect(repository.episodesOf(feedUrl), hasLength(2));
    });

    test('unsubscribe removes the show and its episodes', () async {
      await repository.subscribe(feedUrl);
      await repository.unsubscribe(feedUrl);
      expect(repository.shows, isEmpty);
      expect(repository.episodesOf(feedUrl), isEmpty);
    });
  });
}
