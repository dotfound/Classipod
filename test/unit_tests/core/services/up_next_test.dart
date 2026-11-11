import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/models/playback_shuffle_mode.dart';
import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/models/podcast_show.dart';
import 'package:classipod/core/podcasts/podcast_feed_client.dart';
import 'package:classipod/core/podcasts/podcast_playback.dart';
import 'package:classipod/core/podcasts/podcast_repository.dart';
import 'package:classipod/core/services/playback/library_audio_handler.dart';
import 'package:classipod/core/services/playback/up_next_store.dart';
import 'package:classipod/hive/hive_registrar.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:just_audio/just_audio.dart';

class TestPlayer extends Fake implements AudioPlayer {
  final states = StreamController<ProcessingState>.broadcast();
  final playingEvents = StreamController<bool>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  final loadedIds = <String>[];
  final startPositions = <Duration>[];

  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration;
  @override
  double speed = 1;
  @override
  Duration get bufferedPosition => Duration.zero;
  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Stream<PlayerException> get errorStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<ProcessingState> get processingStateStream => states.stream;
  @override
  Stream<bool> get playingStream => playingEvents.stream;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loadedIds.add(((source as UriAudioSource).tag as MediaItem).id);
    startPositions.add(initialPosition ?? Duration.zero);
    position = initialPosition ?? Duration.zero;
    processingState = ProcessingState.ready;
    states.add(processingState);
    return duration;
  }

  @override
  Future<void> clearAudioSources() async {}

  @override
  Future<void> play() async {
    playing = true;
    playingEvents.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    playingEvents.add(false);
  }

  @override
  Future<void> stop() => pause();

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    this.position = position ?? Duration.zero;
  }

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  void moveTo(Duration value) {
    position = value;
    positions.add(value);
  }

  Future<void> complete() async {
    processingState = ProcessingState.completed;
    states.add(processingState);
    await settle();
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

MusicMetadata song(String id) =>
    MusicMetadata(songId: id, trackName: id, filePath: '/music/$id.mp3');

bool adaptersRegistered = false;

void main() {
  late TestPlayer player;
  late LibraryAudioHandler handler;

  setUp(() {
    player = TestPlayer();
    handler = LibraryAudioHandler(player);
  });

  tearDown(() => handler.dispose());

  Future<void> start(List<String> ids) async {
    await handler.setSongs(ids.map(song).toList(), preload: false);
    await handler.play();
    await settle();
  }

  group('up next ordering', () {
    test('Play Next goes to the front and Add appends', () {
      handler
        ..addToUpNext([song('x')])
        ..addToUpNext([song('y')])
        ..addToUpNext([song('p'), song('q')], playNext: true);
      expect(handler.upNext.map((s) => s.identity), ['p', 'q', 'x', 'y']);
      handler.moveUpNextToTop(2);
      expect(handler.upNext.map((s) => s.identity), ['x', 'p', 'q', 'y']);
      handler.removeFromUpNext(1);
      expect(handler.upNext.map((s) => s.identity), ['x', 'q', 'y']);
      handler.clearUpNext();
      expect(handler.upNext, isEmpty);
    });

    test('plays Up Next before the queue, then falls through', () async {
      await start(['a', 'b', 'c']);
      handler.addToUpNext([song('x'), song('y')]);
      await player.complete();
      await player.complete();
      expect(handler.currentSong!.identity, 'y');
      expect(handler.currentIndex, 0);
      expect(handler.upNext, isEmpty);
      await player.complete();
      await player.complete();
      expect(player.loadedIds, ['a', 'x', 'y', 'b', 'c']);
      expect(handler.currentIndex, 2);
      expect(handler.currentSong!.identity, 'c');
    });

    test('skip next takes Up Next first; previous returns to queue', () async {
      await start(['a', 'b']);
      handler.addToUpNext([song('x')]);
      await handler.skipToNext();
      expect(handler.currentSong!.identity, 'x');
      await handler.skipToPrevious();
      expect(handler.currentSong!.identity, 'a');
      await handler.skipToNext();
      expect(handler.currentSong!.identity, 'b');
      expect(player.loadedIds, ['a', 'x', 'a', 'b']);
    });

    test('shuffle and repeat apply to the normal queue only', () async {
      await start(['a', 'b', 'c']);
      await handler.setShuffleMode(PlaybackShuffleMode.songs.audioServiceMode);
      await handler.setRepeatMode(AudioServiceRepeatMode.one);
      handler.addToUpNext([song('x'), song('y'), song('z')]);
      await player.complete();
      expect(handler.currentSong!.identity, 'a');
      await handler.setRepeatMode(AudioServiceRepeatMode.none);
      await player.complete();
      await player.complete();
      await player.complete();
      expect(player.loadedIds.sublist(2), ['x', 'y', 'z']);
    });

    test('the queue ends after the last Up Next track', () async {
      await start(['a']);
      handler.addToUpNext([song('x')]);
      await player.complete();
      expect(player.playing, isTrue);
      await player.complete();
      expect(player.playing, isFalse);
      expect(player.loadedIds, ['a', 'x']);
    });
  });

  group('persistence and episodes', () {
    late Directory directory;
    late PodcastRepository repository;
    late PodcastEpisode episode;
    late PodcastShow show;
    late DateTime now;

    setUp(() async {
      directory = Directory.systemTemp.createTempSync('up_next');
      Hive.init(directory.path);
      if (!adaptersRegistered) Hive.registerAdapters();
      adaptersRegistered = true;
      now = DateTime.utc(2026, 11, 11);
      repository = PodcastRepository(
        showsBox: await Hive.openBox(PodcastRepository.showsBoxName),
        episodesBox: await Hive.openBox(PodcastRepository.episodesBoxName),
        feedClient: PodcastFeedClient(),
      );
      show = PodcastShow(feedUrl: 'https://example.com/feed', title: 'Show');
      episode = PodcastEpisode(
        id: 'ep-1',
        showFeedUrl: show.feedUrl,
        title: 'Episode',
        enclosureUrl: 'https://example.com/ep1.mp3',
        durationSeconds: 1000,
        localPath: '/podcasts/ep1.mp3',
        downloadState: PodcastDownloadState.done,
        positionSeconds: 300,
      );
      await repository.saveShow(show);
      await repository.saveEpisode(episode);
    });

    tearDown(() async {
      await repository.close();
      await Hive.deleteFromDisk();
      directory.deleteSync(recursive: true);
    });

    MusicMetadata? resolve(String id) {
      if (!id.startsWith(MusicMetadata.podcastIdPrefix)) return song(id);
      final found = repository.episode(
        id.substring(MusicMetadata.podcastIdPrefix.length),
      );
      return found == null ? null : episodeToMetadata(found, show);
    }

    test('Up Next survives a restart with songs and episodes', () async {
      final box = await Hive.openBox<dynamic>(UpNextStore.boxName);
      UpNextStore(box).attach(handler, resolve);
      handler.addToUpNext([song('x'), episodeToMetadata(episode, show)]);
      await settle();
      await repository.episodesBox.delete(episode.storageKey);
      await repository.saveEpisode(episode);

      final restarted = LibraryAudioHandler(TestPlayer());
      var changes = 0;
      UpNextStore(box).attach(restarted, resolve, onChanged: () => changes++);
      expect(restarted.upNext.map((s) => s.identity), [
        'x',
        'podcast:${episode.storageKey}',
      ]);
      expect(restarted.upNext.last.isPodcastEpisode, isTrue);
      expect(changes, 1);
      await restarted.dispose();
    });

    test('tracks that no longer resolve are dropped on restore', () async {
      final box = await Hive.openBox<dynamic>(UpNextStore.boxName);
      await UpNextStore(box).save([song('x'), song('gone')]);
      UpNextStore(box).attach(handler, (id) => id == 'gone' ? null : song(id));
      expect(handler.upNext.map((s) => s.identity), ['x']);
    });

    test(
      'an episode from Up Next resumes, saves and is marked played',
      () async {
        final tracker = PodcastPlaybackTracker(
          repository: repository,
          handler: handler,
          player: player,
          now: () => now,
        );
        show.speed = 1.5;
        await start(['a']);
        expect(player.speed, 1);
        handler.addToUpNext([episodeToMetadata(episode, show)]);
        await player.complete();
        expect(handler.currentSong!.isPodcastEpisode, isTrue);
        expect(player.startPositions.last, const Duration(seconds: 300));
        expect(player.speed, 1.5);

        player.moveTo(const Duration(seconds: 305));
        await settle();
        expect(repository.episode(episode.storageKey)!.positionSeconds, 300);
        player.moveTo(const Duration(seconds: 311));
        await settle();
        expect(repository.episode(episode.storageKey)!.positionSeconds, 311);

        player.moveTo(const Duration(seconds: 400));
        await handler.pause();
        await settle();
        expect(repository.episode(episode.storageKey)!.positionSeconds, 400);
        expect(repository.episode(episode.storageKey)!.isPlayed, isFalse);

        await handler.play();
        player.moveTo(const Duration(seconds: 955));
        await settle();
        final played = repository.episode(episode.storageKey)!;
        expect(played.isPlayed, isTrue);
        expect(played.playedAt, now);
        expect(played.positionSeconds, 0);

        await tracker.setSpeed(2);
        expect(repository.show(show.feedUrl)!.speed, 2);
        player.position = Duration.zero;
        await handler.skipToPrevious();
        await settle();
        expect(handler.currentSong!.identity, 'a');
        expect(player.speed, 1);
        await tracker.dispose();
      },
    );

    test('finished episodes restart from the beginning', () {
      final tracker = PodcastPlaybackTracker(
        repository: repository,
        handler: handler,
        player: player,
      );
      episode.positionSeconds = 960;
      expect(
        tracker.resumePosition(episodeToMetadata(episode, show)),
        Duration.zero,
      );
      expect(isEpisodeFinished(939, 1000), isFalse);
      expect(isEpisodeFinished(941, 1000), isTrue);
      expect(isEpisodeFinished(3400, 3600), isFalse);
      expect(isEpisodeFinished(3541, 3600), isTrue);
      expect(isEpisodeFinished(50, 0), isFalse);
    });
  });
}
