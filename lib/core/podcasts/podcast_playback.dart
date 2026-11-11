import 'dart:async';

import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:classipod/core/podcasts/models/podcast_show.dart';
import 'package:classipod/core/podcasts/podcast_repository.dart';
import 'package:classipod/core/services/playback/library_audio_handler.dart';
import 'package:just_audio/just_audio.dart';

const podcastSpeeds = [1.0, 1.25, 1.5, 2.0];

/// Maps an episode onto the track model the playback handler uses.
MusicMetadata episodeToMetadata(PodcastEpisode episode, PodcastShow? show) {
  final author = show?.author;
  return MusicMetadata(
    songId: '${MusicMetadata.podcastIdPrefix}${episode.storageKey}',
    trackName: episode.title,
    albumName: show?.title,
    albumArtistName: author,
    trackArtistNames: author == null ? null : [author],
    trackDuration: episode.durationSeconds > 0
        ? episode.durationSeconds * 1000
        : null,
    filePath: episode.localPath,
    thumbnailPath: show?.localArtworkPath,
    genres: const ['Podcast'],
  );
}

String? episodeKeyOf(MusicMetadata? song) =>
    song == null || !song.isPodcastEpisode
    ? null
    : song.songId!.substring(MusicMetadata.podcastIdPrefix.length);

/// Whether a position counts as finished: 95% through or in the last minute.
bool isEpisodeFinished(int positionSeconds, int durationSeconds) =>
    durationSeconds > 0 &&
    (positionSeconds >= durationSeconds * 0.95 ||
        durationSeconds - positionSeconds <= 60);

/// Saves episode positions, marks episodes played and applies the playback
/// speed. Positions are saved every 10 seconds and on pause, stop and track
/// change.
class PodcastPlaybackTracker {
  static const saveInterval = Duration(seconds: 10);

  final PodcastRepository repository;
  final LibraryAudioHandler handler;
  final AudioPlayer player;
  final DateTime Function() now;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _currentKey;
  Duration _position = Duration.zero;
  Duration _lastSaved = Duration.zero;

  PodcastPlaybackTracker({
    required this.repository,
    required this.handler,
    required this.player,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    handler.resumePositionFor = resumePosition;
    _subscriptions
      ..add(handler.currentSongStream.listen(_onSongChanged))
      ..add(player.positionStream.listen(_onPosition))
      ..add(
        player.playingStream.listen((playing) {
          if (!playing) unawaited(save());
        }),
      )
      ..add(
        player.processingStateStream.listen((state) {
          if (state == ProcessingState.completed) {
            unawaited(save(finished: true));
          }
        }),
      );
  }

  PodcastEpisode? get currentEpisode {
    final key = _currentKey;
    return key == null ? null : repository.episode(key);
  }

  Duration resumePosition(MusicMetadata song) {
    final key = episodeKeyOf(song);
    final episode = key == null ? null : repository.episode(key);
    if (episode == null ||
        isEpisodeFinished(episode.positionSeconds, episode.durationSeconds)) {
      return Duration.zero;
    }
    return Duration(seconds: episode.positionSeconds);
  }

  void _onSongChanged(MusicMetadata? song) {
    final key = episodeKeyOf(song);
    if (key == _currentKey) return;
    unawaited(save());
    _currentKey = key;
    final episode = currentEpisode;
    _position = episode == null ? Duration.zero : resumePosition(song!);
    _lastSaved = _position;
    // Songs always play at normal speed; episodes use their show's speed.
    final speed = episode == null
        ? 1.0
        : repository.show(episode.showFeedUrl)?.speed ?? 1.0;
    unawaited(_applySpeed(speed));
  }

  Future<void> _applySpeed(double speed) async {
    try {
      if (player.speed != speed) await player.setSpeed(speed);
    } catch (_) {}
  }

  void _onPosition(Duration position) {
    if (_currentKey == null ||
        handler.loading ||
        player.processingState != ProcessingState.ready ||
        position == Duration.zero) {
      return;
    }
    _position = position;
    if ((position - _lastSaved).abs() >= saveInterval) unawaited(save());
  }

  /// Persists the current episode's position and played state.
  Future<void> save({bool finished = false}) async {
    final episode = currentEpisode;
    if (episode == null) return;
    _lastSaved = _position;
    final duration = player.duration?.inSeconds ?? 0;
    if (episode.durationSeconds <= 0 && duration > 0) {
      episode.durationSeconds = duration;
    }
    final seconds = _position.inSeconds;
    if (finished || isEpisodeFinished(seconds, episode.durationSeconds)) {
      if (!episode.isPlayed) episode.playedAt = now();
      episode
        ..isPlayed = true
        ..positionSeconds = 0;
    } else {
      episode.positionSeconds = seconds;
    }
    await repository.saveEpisode(episode);
  }

  double get speed => player.speed;

  /// Sets the speed for the current episode and remembers it for its show.
  Future<void> setSpeed(double speed) async {
    final episode = currentEpisode;
    if (episode == null) return;
    await _applySpeed(speed);
    final show = repository.show(episode.showFeedUrl);
    if (show != null && show.speed != speed) {
      show.speed = speed;
      await repository.saveShow(show);
    }
  }

  Future<void> dispose() async {
    await save();
    handler.resumePositionFor = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
