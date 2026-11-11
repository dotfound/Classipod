import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final upNextProvider = NotifierProvider<UpNextController, List<MusicMetadata>>(
  UpNextController.new,
);

/// The Up Next list: tracks and episodes played before the normal queue
/// continues. Shuffle and repeat do not apply to it.
class UpNextController extends Notifier<List<MusicMetadata>> {
  @override
  List<MusicMetadata> build() => ref.read(libraryAudioHandlerProvider).upNext;

  /// Called by the handler whenever the list changes.
  void refresh() => state = ref.read(libraryAudioHandlerProvider).upNext;

  void playNext(List<MusicMetadata> songs) =>
      ref.read(libraryAudioHandlerProvider).addToUpNext(songs, playNext: true);

  void add(List<MusicMetadata> songs) =>
      ref.read(libraryAudioHandlerProvider).addToUpNext(songs);

  void remove(int index) =>
      ref.read(libraryAudioHandlerProvider).removeFromUpNext(index);

  void moveToTop(int index) =>
      ref.read(libraryAudioHandlerProvider).moveUpNextToTop(index);

  void clear() => ref.read(libraryAudioHandlerProvider).clearUpNext();
}
