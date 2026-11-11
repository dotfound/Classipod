import 'dart:async';

import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/podcasts/podcast_playback.dart';
import 'package:classipod/core/podcasts/podcast_providers.dart';
import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/core/widgets/display_list_tile.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/music/playlist/providers/playlists_provider.dart';
import 'package:classipod/features/music/songs/screens/song_edit_screen.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _NowPlayingMoreOptions {
  upNext,
  speed,
  addToOnTheGo,
  browseAlbum,
  browseArtist,
  editSong,
  sleepTimer,
  cancel;

  String title(BuildContext context) {
    switch (this) {
      case upNext:
        return context.localization.upNextTitle;
      case speed:
        return context.localization.playbackSpeed;
      case addToOnTheGo:
        return context.localization.addToOnTheGoPlaylist;
      case browseAlbum:
        return context.localization.browseAlbum;
      case browseArtist:
        return context.localization.browseArtist;
      case editSong:
        return context.localization.editSongOption;
      case sleepTimer:
        return context.localization.sleepTimerTitle;
      case cancel:
        return context.localization.cancelText;
    }
  }
}

class NowPlayingMoreOptionsScreen extends ConsumerStatefulWidget {
  const NowPlayingMoreOptionsScreen({super.key});

  @override
  ConsumerState createState() => _NowPlayingMoreOptionsScreenState();
}

class _NowPlayingMoreOptionsScreenState
    extends ConsumerState<NowPlayingMoreOptionsScreen>
    with CustomScreen {
  @override
  String get routeName => Routes.nowPlayingMoreOptions.name;

  @override
  List<_NowPlayingMoreOptions> get displayItems {
    final isEpisode =
        ref.read(nowPlayingDetailsProvider).currentMetadata?.isPodcastEpisode ??
        false;
    return [
      _NowPlayingMoreOptions.upNext,
      if (isEpisode)
        _NowPlayingMoreOptions.speed
      else ...[
        _NowPlayingMoreOptions.addToOnTheGo,
        _NowPlayingMoreOptions.browseAlbum,
        _NowPlayingMoreOptions.browseArtist,
        _NowPlayingMoreOptions.editSong,
      ],
      _NowPlayingMoreOptions.sleepTimer,
      _NowPlayingMoreOptions.cancel,
    ];
  }

  String _speedLabel(double speed) =>
      '${speed == speed.roundToDouble() ? speed.round() : speed}×';

  @override
  Future<void> onSelectPressed() =>
      _navigateToScreen(displayItems[selectedDisplayItem]);

  @override
  void onMenuButtonPressed() => _closeScreen();

  void _closeScreen() {
    // Let every device-action listener see the options route before popping.
    // Otherwise Now Playing can handle the same Menu/Select press again.
    scheduleMicrotask(() {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        context.pop();
      }
    });
  }

  Future<void> _navigateToScreen(_NowPlayingMoreOptions optionItem) async {
    setState(() => selectedDisplayItem = displayItems.indexOf(optionItem));
    final currentSongMetadata = ref
        .read(nowPlayingDetailsProvider)
        .currentMetadata;
    switch (optionItem) {
      case _NowPlayingMoreOptions.upNext:
        await context.pushNamed(Routes.upNext.name);
        break;
      case _NowPlayingMoreOptions.speed:
        final playback = ref.read(podcastServicesProvider).value?.playback;
        if (playback == null) break;
        final current = podcastSpeeds.indexOf(playback.speed);
        await playback.setSpeed(
          podcastSpeeds[(current + 1) % podcastSpeeds.length],
        );
        if (mounted) setState(() {});
        break;
      case _NowPlayingMoreOptions.addToOnTheGo:
        ref
            .read(playlistsProvider.notifier)
            .addSongToPlaylist(currentSongMetadata);
        _closeScreen();
        break;
      case _NowPlayingMoreOptions.browseAlbum:
        final albumDetailIndex = ref
            .read(albumDetailsProvider)
            .indexWhere((e) => e == currentSongMetadata?.getAlbumDetail);
        if (albumDetailIndex != -1) {
          await Future<void>.value();
          if (!mounted) return;
          context.goNamed(
            Routes.albumSongs.name,
            queryParameters: const {'selectAlbum': 'true'},
            extra: ref.read(albumDetailsProvider)[albumDetailIndex],
          );
        }
        break;
      case _NowPlayingMoreOptions.browseArtist:
        final artistName =
            currentSongMetadata?.getMainArtistName ?? 'Unknown Artist';
        await Future<void>.value();
        if (!mounted) return;
        context.goNamed(
          Routes.artistAlbums.name,
          pathParameters: {'artistName': artistName},
          queryParameters: {'selectedArtist': artistName},
        );
        break;
      case _NowPlayingMoreOptions.editSong:
        if (currentSongMetadata == null) {
          _closeScreen();
          return;
        }
        await showCupertinoDialog(
          context: context,
          builder: (dialogContext) =>
              SongEditScreen(songMetadata: currentSongMetadata),
        );
        if (mounted) {
          _closeScreen();
        }
        break;
      case _NowPlayingMoreOptions.sleepTimer:
        await context.pushNamed(Routes.sleepTimer.name);
        break;
      case _NowPlayingMoreOptions.cancel:
        _closeScreen();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CupertinoScrollbar(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          itemCount: displayItems.length,
          prototypeItem: const DisplayListTile(text: '', isSelected: false),
          itemBuilder: (context, index) {
            return DisplayListTile(
              text: displayItems[index] == _NowPlayingMoreOptions.speed
                  ? '${displayItems[index].title(context)}: '
                        '${_speedLabel(ref.read(audioPlayerProvider).speed)}'
                  : displayItems[index].title(context),
              isSelected: index == selectedDisplayItem,
              onTap: () async => _navigateToScreen(displayItems[index]),
            );
          },
        ),
      ),
    );
  }
}
