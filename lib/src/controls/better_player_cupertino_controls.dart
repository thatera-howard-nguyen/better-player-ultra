import 'dart:async';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _CupertinoDoubleTapSide { left, right }

class BetterPlayerCupertinoControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visibility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerCupertinoControls({
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerCupertinoControlsState();
  }
}

class _BetterPlayerCupertinoControlsState
    extends BetterPlayerControlsState<BetterPlayerCupertinoControls> {
  final marginSize = 5.0;
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _expandCollapseTimer;
  Timer? _initTimer;
  bool _wasLoading = false;

  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  // Double-tap seek overlay state (same as Material)
  static const int _doubleTapStepMs = 10000; // 10s per tap
  static const int _doubleTapGraceWindowMs = 400; // suggested 400ms
  Timer? _doubleTapTimer;
  int _doubleTapAccumMs = 0;
  bool _showDoubleTapOverlay = false;
  bool _doubleTapConsumed = false;
  _CupertinoDoubleTapSide? _doubleTapSide;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _betterPlayerController = BetterPlayerController.of(context);

    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }

    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    final backgroundColor = _controlsConfiguration.controlBarColor;
    final iconColor = _controlsConfiguration.iconsColor;
    final orientation = MediaQuery.of(context).orientation;
    final barHeight = orientation == Orientation.portrait
        ? _controlsConfiguration.controlBarHeight
        : _controlsConfiguration.controlBarHeight + 10;
    const buttonPadding = 10.0;
    final isFullScreen = _betterPlayerController?.isFullScreen == true;

    _wasLoading = isLoading(_latestValue);

    // If controls are disabled, return SizedBox to allow overlay touch events
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    final controlsColumn = Column(children: <Widget>[
      _buildTopBar(
        backgroundColor,
        iconColor,
        barHeight,
        buttonPadding,
      ),
      if (_wasLoading)
        Expanded(child: Center(child: _buildLoadingWidget()))
      else
        _buildHitArea(),
      _buildNextVideoWidget(),
      _buildBottomBar(
        backgroundColor,
        iconColor,
        barHeight,
      ),
    ]);
    return GestureDetector(
      onTap: betterPlayerController!.controlsEnabled
          ? () {
              if (BetterPlayerMultipleGestureDetector.of(context) != null) {
                BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
              }
              controlsNotVisible
                  ? cancelAndRestartTimer()
                  : changePlayerControlsNotVisible(true);
            }
          : null,
      onDoubleTapDown: betterPlayerController!.controlsEnabled
          ? (details) {
              if (BetterPlayerMultipleGestureDetector.of(context) != null) {
                BetterPlayerMultipleGestureDetector.of(context)!
                    .onDoubleTapDown
                    ?.call(details);
              }
              _handleDoubleTapDown(details);
            }
          : null,
      onDoubleTap: betterPlayerController!.controlsEnabled
          ? () {
              if (BetterPlayerMultipleGestureDetector.of(context) != null) {
                BetterPlayerMultipleGestureDetector.of(context)!
                    .onDoubleTap
                    ?.call();
              }
              if (_doubleTapConsumed) {
                _doubleTapConsumed = false;
                return;
              }
              cancelAndRestartTimer();
              _onPlayPause();
            }
          : null,
      onLongPress: betterPlayerController!.controlsEnabled
          ? () {
              if (BetterPlayerMultipleGestureDetector.of(context) != null) {
                BetterPlayerMultipleGestureDetector.of(context)!
                    .onLongPress
                    ?.call();
              }
            }
          : null,
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing:
                controlsNotVisible && betterPlayerController!.controlsEnabled,
            child:
                isFullScreen ? SafeArea(child: controlsColumn) : controlsColumn,
          ),
          Positioned.fill(child: _buildDoubleTapOverlay()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller!.removeListener(_updateState);
    _hideTimer?.cancel();
    _expandCollapseTimer?.cancel();
    _initTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
    _doubleTapTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildBottomBar(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
  ) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        alignment: Alignment.bottomCenter,
        margin: EdgeInsets.all(marginSize),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: _betterPlayerController!.isLiveStream()
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const SizedBox(width: 8),
                      if (_controlsConfiguration.enablePlayPause)
                        _buildPlayPause(_controller!, iconColor, barHeight)
                      else
                        const SizedBox(),
                      const SizedBox(width: 8),
                      _buildLiveWidget(),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      if (_controlsConfiguration.enableSkips)
                        _buildSkipBack(iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enablePlayPause)
                        _buildPlayPause(_controller!, iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableSkips)
                        _buildSkipForward(iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableProgressText)
                        _buildPosition()
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableProgressBar)
                        _buildProgressBar()
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableProgressText)
                        _buildRemaining()
                      else
                        const SizedBox()
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Expanded(
      child: Text(
        _betterPlayerController!.translations.controlsLive,
        style: TextStyle(
            color: _controlsConfiguration.liveTextColor,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  GestureDetector _buildExpandButton(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.symmetric(
              horizontal: buttonPadding,
            ),
            decoration: BoxDecoration(color: backgroundColor),
            child: _betterPlayerController!.isFullScreen
                ? (_controlsConfiguration.fullscreenDisableIcon ??
                    const SizedBox())
                : (_controlsConfiguration.fullscreenEnableIcon ??
                    const SizedBox()),
          ),
        ),
      ),
    );
  }

  Expanded _buildHitArea() {
    return Expanded(
      child: GestureDetector(
        onTap: _latestValue != null && _latestValue!.isPlaying
            ? () {
                if (controlsNotVisible == true) {
                  cancelAndRestartTimer();
                } else {
                  _hideTimer?.cancel();
                  changePlayerControlsNotVisible(true);
                }
              }
            : () {
                _hideTimer?.cancel();
                changePlayerControlsNotVisible(false);
              },
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  GestureDetector _buildMoreButton(
    VideoPlayerController? controller,
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: () {
        onShowMoreClicked();
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
              ),
              child: Icon(
                _controlsConfiguration.overflowMenuIcon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildMuteButton(
    VideoPlayerController? controller,
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return GestureDetector(
      onTap: () {
        cancelAndRestartTimer();

        if (_latestValue!.volume == 0) {
          controller!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          controller.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
              ),
              child: (_latestValue != null && _latestValue!.volume > 0)
                  ? (_controlsConfiguration.muteIcon ?? const SizedBox())
                  : (_controlsConfiguration.unMuteIcon ?? const SizedBox()),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildPlayPause(
    VideoPlayerController controller,
    Color iconColor,
    double barHeight,
  ) {
    return GestureDetector(
      onTap: _onPlayPause,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: controller.value.isPlaying
            ? (_controlsConfiguration.pauseIcon ?? const SizedBox())
            : (_controlsConfiguration.playIcon ?? const SizedBox()),
      ),
    );
  }

  Widget _buildPosition() {
    final position =
        _latestValue != null ? _latestValue!.position : const Duration();

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        BetterPlayerUtils.formatDuration(position),
        style: TextStyle(
          color: _controlsConfiguration.textColor,
          fontSize: 12.0,
        ),
      ),
    );
  }

  Widget _buildRemaining() {
    final position = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration! - _latestValue!.position
        : const Duration();

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        '-${BetterPlayerUtils.formatDuration(position)}',
        style:
            TextStyle(color: _controlsConfiguration.textColor, fontSize: 12.0),
      ),
    );
  }

  GestureDetector _buildSkipBack(Color iconColor, double barHeight) {
    return GestureDetector(
      onTap: skipBack,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        margin: const EdgeInsets.only(left: 10.0),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
        ),
        child: _controlsConfiguration.skipBackIcon ?? const SizedBox(),
      ),
    );
  }

  GestureDetector _buildSkipForward(Color iconColor, double barHeight) {
    return GestureDetector(
      onTap: skipForward,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        margin: const EdgeInsets.only(right: 8.0),
        child: _controlsConfiguration.skipForwardIcon ?? const SizedBox(),
      ),
    );
  }

  Widget _buildTopBar(
    Color backgroundColor,
    Color iconColor,
    double topBarHeight,
    double buttonPadding,
  ) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    final barHeight = topBarHeight * 0.8;
    final iconSize = topBarHeight * 0.4;
    return Container(
      height: barHeight,
      margin: EdgeInsets.only(
        top: marginSize,
        right: marginSize,
        left: marginSize,
      ),
      child: Row(
        children: <Widget>[
          if (_controlsConfiguration.enableFullscreen)
            _buildExpandButton(
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
          const SizedBox(
            width: 4,
          ),
          if (_controlsConfiguration.enablePip)
            _buildPipButton(
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
          const Spacer(),
          if (_controlsConfiguration.enableMute)
            _buildMuteButton(
              _controller,
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
          const SizedBox(
            width: 4,
          ),
          if (_controlsConfiguration.enableOverflowMenu)
            _buildMoreButton(
              _controller,
              backgroundColor,
              iconColor,
              barHeight,
              iconSize,
              buttonPadding,
            )
          else
            const SizedBox(),
        ],
      ),
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _betterPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return InkWell(
            onTap: () {
              _betterPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4, right: 8),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_betterPlayerController!.translations.controlsNextVideoIn} $time ...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    changePlayerControlsNotVisible(false);
    _startHideTimer();
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) ||
        _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }
    _controlsVisibilityStreamSubscription =
        _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);

      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _expandCollapseTimer = Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: BetterPlayerCupertinoVideoProgressBar(
          _controller,
          _betterPlayerController,
          onDragStart: () {
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            _startHideTimer();
          },
          onTapDown: () {
            cancelAndRestartTimer();
          },
          colors: BetterPlayerProgressColors(
              playedColor: _controlsConfiguration.progressBarPlayedColor,
              handleColor: _controlsConfiguration.progressBarHandleColor,
              bufferedColor: _controlsConfiguration.progressBarBufferedColor,
              backgroundColor:
                  _controlsConfiguration.progressBarBackgroundColor),
        ),
      ),
    );
  }

  // ===== Double-tap overlay and logic (same as Material) =====
  Widget _buildDoubleTapOverlay() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    final bool visible = _showDoubleTapOverlay && _doubleTapSide != null;
    if (!visible) return const SizedBox();

    final bool isLeft = _doubleTapSide == _CupertinoDoubleTapSide.left;
    final Color dimColor = Colors.black.withOpacity(0.4);
    final TextStyle labelStyle = const TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w700,
    );

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: Container(
              color: isLeft ? dimColor : Colors.transparent,
              child: isLeft
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.gobackward_10,
                                color: Colors.white, size: 34),
                            const SizedBox(width: 8),
                            Text(
                              "${(_doubleTapAccumMs / 1000).round()}s",
                              style: labelStyle,
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const Expanded(flex: 20, child: SizedBox()),
          Expanded(
            flex: 40,
            child: Container(
              color: !isLeft ? dimColor : Colors.transparent,
              child: !isLeft
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${(_doubleTapAccumMs / 1000).round()}s",
                              style: labelStyle,
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.goforward_10,
                                color: Colors.white, size: 34),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (_betterPlayerController?.isLiveStream() == true) {
      return; // no seek for live
    }
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size size = box.size;
    final Offset local = box.globalToLocal(details.globalPosition);
    final double x = local.dx;
    final double width = size.width == 0 ? 1 : size.width;
    final double ratio = x / width;

    if (ratio < 0.4) {
      _onDoubleTapZone(_CupertinoDoubleTapSide.left);
    } else if (ratio > 0.6) {
      _onDoubleTapZone(_CupertinoDoubleTapSide.right);
    } else {
      _doubleTapConsumed = false;
    }
  }

  void _onDoubleTapZone(_CupertinoDoubleTapSide side) {
    _doubleTapConsumed = true;
    _doubleTapSide = side;
    _showDoubleTapOverlay = true;
    _doubleTapAccumMs = _doubleTapAccumMs + _doubleTapStepMs;

    HapticFeedback.lightImpact();

    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(
      const Duration(milliseconds: _doubleTapGraceWindowMs),
      _applyDoubleTapSeek,
    );
    setState(() {});
  }

  Future<void> _applyDoubleTapSeek() async {
    if (_betterPlayerController == null || _controller == null) return;
    final int currentMs = _controller!.value.position.inMilliseconds;
    final int durationMs = _controller!.value.duration?.inMilliseconds ?? 0;
    int delta = _doubleTapAccumMs *
        (_doubleTapSide == _CupertinoDoubleTapSide.left ? -1 : 1);
    int target = currentMs + delta;
    if (target < 0) target = 0;
    if (durationMs > 0 && target > durationMs) target = durationMs;

    HapticFeedback.mediumImpact();

    await _betterPlayerController!.seekTo(Duration(milliseconds: target));

    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
    _doubleTapAccumMs = 0;
    _doubleTapSide = null;
    setState(() {
      _showDoubleTapOverlay = false;
    });
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
        if (_betterPlayerController!.betterPlayerDataSource?.liveStream ==
            true) {
          _betterPlayerController!.play();
          _betterPlayerController!.cancelNextVideoTimer();
        }
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible ||
          isVideoFinished(_controller!.value) ||
          _wasLoading ||
          isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue)) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return _controlsConfiguration.loadingWidget;
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }

  Widget _buildPipButton(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) {
    return FutureBuilder<bool>(
      future: _betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return GestureDetector(
            onTap: () {
              betterPlayerController!.enablePictureInPicture(
                  betterPlayerController!.betterPlayerGlobalKey!);
            },
            child: AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: barHeight,
                  padding: EdgeInsets.only(
                    left: buttonPadding,
                    right: buttonPadding,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.5),
                  ),
                  child: Center(
                    child: Icon(
                      _controlsConfiguration.pipMenuIcon,
                      color: iconColor,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }
}
