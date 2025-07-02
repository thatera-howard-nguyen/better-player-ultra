import 'package:better_player/better_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

///UI configuration of Better Player. Allows to change colors/icons/behavior
///of controls. Used in BetterPlayerConfiguration. Configuration applies only
///for player displayed in app, not in notification or PiP mode.
class BetterPlayerControlsConfiguration {
  ///Color of the control bars
  final Color controlBarColor;

  ///Color of texts
  final Color textColor;

  ///Color of icons
  final Color iconsColor;

  ///Widget of play
  final Widget? playIcon;

  ///Widget of pause
  final Widget? pauseIcon;

  ///Widget of mute
  final Widget? muteIcon;

  ///Widget of unmute
  final Widget? unMuteIcon;

  ///Widget of fullscreen mode enable
  final Widget? fullscreenEnableIcon;

  ///Widget of fullscreen mode disable
  final Widget? fullscreenDisableIcon;

  ///Widget of skip back
  final Widget? skipBackIcon;

  ///Widget of skip forward
  final Widget? skipForwardIcon;

  ///Widget of replay
  final Widget? replayIcon;

  ///Flag used to enable/disable fullscreen
  final bool enableFullscreen;

  ///Flag used to enable/disable mute
  final bool enableMute;

  ///Flag used to enable/disable progress texts
  final bool enableProgressText;

  ///Flag used to enable/disable progress bar
  final bool enableProgressBar;

  ///Flag used to enable/disable progress bar drag
  final bool enableProgressBarDrag;

  ///Flag used to enable/disable play-pause
  final bool enablePlayPause;

  ///Flag used to enable skip forward and skip back
  final bool enableSkips;

  ///Progress bar played color
  final Color progressBarPlayedColor;

  ///Progress bar circle color
  final Color progressBarHandleColor;

  ///Progress bar buffered video color
  final Color progressBarBufferedColor;

  ///Progress bar background color
  final Color progressBarBackgroundColor;

  ///Time to hide controls
  final Duration controlsHideTime;

  ///Parameter used to build custom controls
  final Widget Function(BetterPlayerController controller,
      Function(bool) onPlayerVisibilityChanged)? customControlsBuilder;

  ///Parameter used to change theme of the player
  final BetterPlayerTheme? playerTheme;

  ///Flag used to show/hide controls
  final bool showControls;

  ///Flag used to show controls on init
  final bool showControlsOnInitialize;

  ///Control bar height
  final double controlBarHeight;

  ///Live text color;
  final Color liveTextColor;

  ///Flag used to show/hide overflow menu which contains playback, subtitles,
  ///qualities options.
  final bool enableOverflowMenu;

  ///Flag used to show/hide playback speed
  final bool enablePlaybackSpeed;

  ///Flag used to show/hide subtitles
  final bool enableSubtitles;

  ///Flag used to show/hide qualities
  final bool enableQualities;

  ///Flag used to show/hide PiP mode
  final bool enablePip;

  ///Flag used to enable/disable retry feature
  final bool enableRetry;

  ///Flag used to show/hide audio tracks
  final bool enableAudioTracks;

  ///Custom items of overflow menu
  final List<BetterPlayerOverflowMenuItem> overflowMenuCustomItems;

  ///Icon of the overflow menu
  final IconData overflowMenuIcon;

  ///Icon of the PiP menu
  final IconData pipMenuIcon;

  ///Icon of the playback speed menu item from overflow menu
  final IconData playbackSpeedIcon;

  ///Icon of the subtitles menu item from overflow menu
  final IconData subtitlesIcon;

  ///Icon of the qualities menu item from overflow menu
  final IconData qualitiesIcon;

  ///Icon of the audios menu item from overflow menu
  final IconData audioTracksIcon;

  ///Color of overflow menu icons
  final Color overflowMenuIconsColor;

  ///Time which will be used once user uses forward
  final int forwardSkipTimeInMilliseconds;

  ///Time which will be used once user uses backward
  final int backwardSkipTimeInMilliseconds;

  ///Color of default loading indicator
  final Color loadingColor;

  ///Widget which can be used instead of default progress
  final Widget? loadingWidget;

  ///Color of the background, when no frame is displayed.
  final Color backgroundColor;

  ///Color of the bottom modal sheet used for overflow menu items.
  final Color overflowModalColor;

  ///Color of text in bottom modal sheet used for overflow menu items.
  final Color overflowModalTextColor;

  const BetterPlayerControlsConfiguration({
    this.controlBarColor = Colors.black87,
    this.textColor = Colors.white,
    this.iconsColor = Colors.white,
    this.playIcon =
        const Icon(Icons.play_arrow_outlined, size: 42, color: Colors.white),
    this.pauseIcon =
        const Icon(Icons.pause_outlined, size: 42, color: Colors.white),
    this.muteIcon = const Icon(Icons.volume_up_outlined, color: Colors.white),
    this.unMuteIcon =
        const Icon(Icons.volume_off_outlined, color: Colors.white),
    this.fullscreenEnableIcon =
        const Icon(Icons.fullscreen_outlined, color: Colors.white),
    this.fullscreenDisableIcon =
        const Icon(Icons.fullscreen_exit_outlined, color: Colors.white),
    this.skipBackIcon =
        const Icon(Icons.replay_10_outlined, size: 24, color: Colors.white),
    this.skipForwardIcon =
        const Icon(Icons.forward_10_outlined, size: 24, color: Colors.white),
    this.replayIcon = const Icon(Icons.replay, size: 42, color: Colors.white),
    this.enableFullscreen = true,
    this.enableMute = true,
    this.enableProgressText = true,
    this.enableProgressBar = true,
    this.enableProgressBarDrag = true,
    this.enablePlayPause = true,
    this.enableSkips = true,
    this.enableAudioTracks = true,
    this.progressBarPlayedColor = Colors.white,
    this.progressBarHandleColor = Colors.white,
    this.progressBarBufferedColor = Colors.white70,
    this.progressBarBackgroundColor = Colors.white60,
    this.controlsHideTime = const Duration(milliseconds: 300),
    this.customControlsBuilder,
    this.playerTheme,
    this.showControls = true,
    this.showControlsOnInitialize = true,
    this.controlBarHeight = 48.0,
    this.liveTextColor = Colors.red,
    this.enableOverflowMenu = true,
    this.enablePlaybackSpeed = true,
    this.enableSubtitles = true,
    this.enableQualities = true,
    this.enablePip = true,
    this.enableRetry = true,
    this.overflowMenuCustomItems = const [],
    this.overflowMenuIcon = Icons.more_vert_outlined,
    this.pipMenuIcon = Icons.picture_in_picture_outlined,
    this.playbackSpeedIcon = Icons.shutter_speed_outlined,
    this.qualitiesIcon = Icons.hd_outlined,
    this.subtitlesIcon = Icons.closed_caption_outlined,
    this.audioTracksIcon = Icons.audiotrack_outlined,
    this.overflowMenuIconsColor = Colors.black,
    this.forwardSkipTimeInMilliseconds = 10000,
    this.backwardSkipTimeInMilliseconds = 10000,
    this.loadingColor = Colors.white,
    this.loadingWidget,
    this.backgroundColor = Colors.black,
    this.overflowModalColor = Colors.white,
    this.overflowModalTextColor = Colors.black,
  });

  factory BetterPlayerControlsConfiguration.white() {
    return const BetterPlayerControlsConfiguration(
      controlBarColor: Colors.white,
      textColor: Colors.black,
      iconsColor: Colors.black,
      progressBarPlayedColor: Colors.black,
      progressBarHandleColor: Colors.black,
      progressBarBufferedColor: Colors.black54,
      progressBarBackgroundColor: Colors.white70,
    );
  }

  factory BetterPlayerControlsConfiguration.cupertino() {
    return const BetterPlayerControlsConfiguration(
      fullscreenEnableIcon: Icon(CupertinoIcons.arrow_up_left_arrow_down_right),
      fullscreenDisableIcon:
          Icon(CupertinoIcons.arrow_down_right_arrow_up_left),
      playIcon: Icon(CupertinoIcons.play_arrow_solid),
      pauseIcon: Icon(CupertinoIcons.pause_solid),
      skipBackIcon: Icon(CupertinoIcons.gobackward_15, size: 24),
      skipForwardIcon: Icon(CupertinoIcons.goforward_15, size: 24),
    );
  }

  ///Setup BetterPlayerControlsConfiguration based on Theme options.
  factory BetterPlayerControlsConfiguration.theme(ThemeData theme) {
    return BetterPlayerControlsConfiguration(
      textColor: theme.textTheme.bodySmall?.color ?? Colors.white,
      iconsColor: theme.buttonTheme.colorScheme?.primary ?? Colors.white,
    );
  }
}
