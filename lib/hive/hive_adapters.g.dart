// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class PlaylistModelAdapter extends TypeAdapter<PlaylistModel> {
  @override
  final typeId = 1;

  @override
  PlaylistModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaylistModel(
      name: fields[1] as String,
      songs: (fields[2] as List).cast<MusicMetadata>(),
    );
  }

  @override
  void write(BinaryWriter writer, PlaylistModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.songs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MusicMetadataAdapter extends TypeAdapter<MusicMetadata> {
  @override
  final typeId = 2;

  @override
  MusicMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MusicMetadata(
      serverId: fields[22] as String?,
      remoteSongId: fields[23] as String?,
      remoteAlbumId: fields[24] as String?,
      remoteArtworkId: fields[25] as String?,
      songId: fields[18] as String?,
      sourceVolume: fields[19] as String?,
      contentUri: fields[20] as String?,
      albumArtistNames: (fields[21] as List?)?.cast<String>(),
      trackName: fields[0] as String?,
      trackArtistNames: (fields[1] as List?)?.cast<String>(),
      albumName: fields[2] as String?,
      albumArtistName: fields[3] as String?,
      trackNumber: (fields[4] as num?)?.toInt(),
      albumLength: (fields[5] as num?)?.toInt(),
      year: (fields[6] as num?)?.toInt(),
      genres: fields[7] == null ? const [] : (fields[7] as List).cast<String>(),
      discNumber: (fields[8] as num?)?.toInt(),
      mimeType: fields[9] as String?,
      trackDuration: (fields[10] as num?)?.toInt(),
      bitrate: (fields[11] as num?)?.toInt(),
      filePath: fields[12] as String?,
      thumbnailPath: fields[13] as String?,
      originalSongIndex: fields[14] == null ? 0 : (fields[14] as num).toInt(),
      isOnDevice: fields[15] == null ? true : fields[15] as bool,
      rating: fields[16] == null ? 0 : (fields[16] as num).toInt(),
      lyrics: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MusicMetadata obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.trackName)
      ..writeByte(1)
      ..write(obj.trackArtistNames)
      ..writeByte(2)
      ..write(obj.albumName)
      ..writeByte(3)
      ..write(obj.albumArtistName)
      ..writeByte(4)
      ..write(obj.trackNumber)
      ..writeByte(5)
      ..write(obj.albumLength)
      ..writeByte(6)
      ..write(obj.year)
      ..writeByte(7)
      ..write(obj.genres)
      ..writeByte(8)
      ..write(obj.discNumber)
      ..writeByte(9)
      ..write(obj.mimeType)
      ..writeByte(10)
      ..write(obj.trackDuration)
      ..writeByte(11)
      ..write(obj.bitrate)
      ..writeByte(12)
      ..write(obj.filePath)
      ..writeByte(13)
      ..write(obj.thumbnailPath)
      ..writeByte(14)
      ..write(obj.originalSongIndex)
      ..writeByte(15)
      ..write(obj.isOnDevice)
      ..writeByte(16)
      ..write(obj.rating)
      ..writeByte(17)
      ..write(obj.lyrics)
      ..writeByte(18)
      ..write(obj.songId)
      ..writeByte(19)
      ..write(obj.sourceVolume)
      ..writeByte(20)
      ..write(obj.contentUri)
      ..writeByte(21)
      ..write(obj.albumArtistNames)
      ..writeByte(22)
      ..write(obj.serverId)
      ..writeByte(23)
      ..write(obj.remoteSongId)
      ..writeByte(24)
      ..write(obj.remoteAlbumId)
      ..writeByte(25)
      ..write(obj.remoteArtworkId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExcludeDirectoryModelAdapter extends TypeAdapter<ExcludeDirectoryModel> {
  @override
  final typeId = 3;

  @override
  ExcludeDirectoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExcludeDirectoryModel(
      directoryPath: fields[0] as String,
      isExcluded: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ExcludeDirectoryModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.directoryPath)
      ..writeByte(1)
      ..write(obj.isExcluded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExcludeDirectoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PodcastShowAdapter extends TypeAdapter<PodcastShow> {
  @override
  final typeId = 4;

  @override
  PodcastShow read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PodcastShow(
      feedUrl: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String?,
      artworkUrl: fields[3] as String?,
      localArtworkPath: fields[4] as String?,
      lastRefreshed: fields[5] as DateTime?,
      etag: fields[6] as String?,
      lastModified: fields[7] as String?,
      autoDownload: fields[8] == null ? true : fields[8] as bool,
      keepLatest: fields[9] == null ? 3 : (fields[9] as num).toInt(),
      speed: fields[10] == null ? 1 : (fields[10] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, PodcastShow obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.feedUrl)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.artworkUrl)
      ..writeByte(4)
      ..write(obj.localArtworkPath)
      ..writeByte(5)
      ..write(obj.lastRefreshed)
      ..writeByte(6)
      ..write(obj.etag)
      ..writeByte(7)
      ..write(obj.lastModified)
      ..writeByte(8)
      ..write(obj.autoDownload)
      ..writeByte(9)
      ..write(obj.keepLatest)
      ..writeByte(10)
      ..write(obj.speed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodcastShowAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PodcastEpisodeAdapter extends TypeAdapter<PodcastEpisode> {
  @override
  final typeId = 5;

  @override
  PodcastEpisode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PodcastEpisode(
      id: fields[0] as String,
      showFeedUrl: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] == null ? '' : fields[3] as String,
      pubDate: fields[4] as DateTime?,
      enclosureUrl: fields[5] as String,
      durationSeconds: fields[6] == null ? 0 : (fields[6] as num).toInt(),
      localPath: fields[7] as String?,
      downloadState: fields[8] == null
          ? PodcastDownloadState.none
          : fields[8] as PodcastDownloadState,
      positionSeconds: fields[9] == null ? 0 : (fields[9] as num).toInt(),
      isPlayed: fields[10] == null ? false : fields[10] as bool,
      playedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PodcastEpisode obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.showFeedUrl)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.pubDate)
      ..writeByte(5)
      ..write(obj.enclosureUrl)
      ..writeByte(6)
      ..write(obj.durationSeconds)
      ..writeByte(7)
      ..write(obj.localPath)
      ..writeByte(8)
      ..write(obj.downloadState)
      ..writeByte(9)
      ..write(obj.positionSeconds)
      ..writeByte(10)
      ..write(obj.isPlayed)
      ..writeByte(11)
      ..write(obj.playedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodcastEpisodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PodcastDownloadStateAdapter extends TypeAdapter<PodcastDownloadState> {
  @override
  final typeId = 6;

  @override
  PodcastDownloadState read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PodcastDownloadState.none;
      case 1:
        return PodcastDownloadState.queued;
      case 2:
        return PodcastDownloadState.downloading;
      case 3:
        return PodcastDownloadState.done;
      case 4:
        return PodcastDownloadState.failed;
      default:
        return PodcastDownloadState.none;
    }
  }

  @override
  void write(BinaryWriter writer, PodcastDownloadState obj) {
    switch (obj) {
      case PodcastDownloadState.none:
        writer.writeByte(0);
      case PodcastDownloadState.queued:
        writer.writeByte(1);
      case PodcastDownloadState.downloading:
        writer.writeByte(2);
      case PodcastDownloadState.done:
        writer.writeByte(3);
      case PodcastDownloadState.failed:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodcastDownloadStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
