import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/services/playback/library_audio_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

/// Persists the Up Next list as track identities, so it survives restarts.
class UpNextStore {
  static const boxName = 'up-next-v1';
  static const _key = 'ids';

  final Box<dynamic> box;

  UpNextStore(this.box);

  List<String> readIds() {
    final value = box.get(_key);
    return value is List ? value.whereType<String>().toList() : const [];
  }

  Future<void> save(List<MusicMetadata> songs) async {
    try {
      await box.put(_key, [for (final song in songs) song.identity]);
    } catch (error) {
      debugPrint('Could not save Up Next: ${error.runtimeType}');
    }
  }

  /// Restores the saved list into [handler], dropping tracks that no longer
  /// resolve, then keeps the store in step with later changes.
  void attach(
    LibraryAudioHandler handler,
    MusicMetadata? Function(String identity) resolve, {
    VoidCallback? onChanged,
  }) {
    final restored = [for (final id in readIds()) ?resolve(id)];
    handler.onUpNextChanged = () {
      save(handler.upNext).ignore();
      onChanged?.call();
    };
    handler.setUpNext(restored);
  }
}
