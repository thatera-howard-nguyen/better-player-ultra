import 'dart:async';
import 'dart:io';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/video_player/video_player.dart';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerMaterialControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerMaterialControlsState();
  }
}

class _BetterPlayerMaterialControlsState
    extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  // Double-tap seek overlay state
  static const int _doubleTapStepMs = 10000; // 10s per tap
  static const int _doubleTapGraceWindowMs =
      800; // 300-500ms suggested, use 400ms
  Timer? _doubleTapTimer;
  int _doubleTapAccumMs = 0;
  bool _showDoubleTapOverlay = false;
  bool _doubleTapConsumed =
      false; // prevents onDoubleTap default when handled by zones
  _DoubleTapSide? _doubleTapSide;

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
    _wasLoading = isLoading(_latestValue);
    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }

    // If controls are disabled, return SizedBox to allow overlay touch events
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

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
              // If we've handled double-tap in left/right zones, swallow default
              if (_doubleTapConsumed) {
                _doubleTapConsumed = false;
                return;
              }
              cancelAndRestartTimer();
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
            child: AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: Container(
                color: _controlsConfiguration.controlBarColor,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: _buildTopBar(),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: _wasLoading
                              ? _buildLoadingWidget()
                              : _buildHitArea(),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _buildBottomBar(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Double-tap overlay drawn outside of controls opacity
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
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
    _doubleTapTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
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

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      child: (_controlsConfiguration.enableOverflowMenu ||
              _betterPlayerController!
                      .betterPlayerConfiguration.widgetInTopBarLeft !=
                  null)
          ? Container(
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Left side: Custom widget
                  if (_betterPlayerController!
                          .betterPlayerConfiguration.widgetInTopBarLeft !=
                      null)
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: _betterPlayerController!
                              .betterPlayerConfiguration.widgetInTopBarLeft!,
                        ),
                      ),
                    ),
                  // Right side: Existing controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_controlsConfiguration.enablePip)
                        _buildPipButtonWrapperWidget(
                            controlsNotVisible, _onPlayerHide)
                      else
                        const SizedBox(),
                      _buildMoreButton(),
                    ],
                  ),
                ],
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildPipButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        betterPlayerController!.enablePictureInPicture(
            betterPlayerController!.betterPlayerGlobalKey!);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          betterPlayerControlsConfiguration.pipMenuIcon,
          color: betterPlayerControlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPipButtonWrapperWidget(
      bool hideStuff, void Function() onPlayerHide) {
    return FutureBuilder<bool>(
      future: betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final bool isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return AnimatedOpacity(
            opacity: hideStuff ? 0.0 : 1.0,
            duration: betterPlayerControlsConfiguration.controlsHideTime,
            onEnd: onPlayerHide,
            child: Container(
              height: betterPlayerControlsConfiguration.controlBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildPipButton(),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMoreButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowMoreClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          _controlsConfiguration.overflowMenuIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isFullScreen = _betterPlayerController?.isFullScreen == true;
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Top row: Timeline and controls
          Container(
            height: 30,
            child: Row(
              children: [
                if (_betterPlayerController!.isLiveStream())
                  _buildLiveWidget()
                else
                  _controlsConfiguration.enableProgressText
                      ? Expanded(child: _buildPosition())
                      : const SizedBox(),
                const Spacer(),
                if (_controlsConfiguration.enableFullscreen)
                  _buildExpandButton()
                else
                  const SizedBox(),
              ],
            ),
          ),
          // Bottom row: Progress bar
          if (_betterPlayerController!.isLiveStream())
            const SizedBox()
          else
            _controlsConfiguration.enableProgressBar
                ? _buildProgressBar()
                : const SizedBox(),
          // Custom widget below seekbar
          if (_betterPlayerController!
                  .betterPlayerConfiguration.widgetBelowSeekBar !=
              null)
            _betterPlayerController!
                .betterPlayerConfiguration.widgetBelowSeekBar!,
          if (Platform.isIOS && isFullScreen) const SizedBox(height: 20)
        ],
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(
        _betterPlayerController!.translations.controlsLive,
        style: TextStyle(
          color: _controlsConfiguration.liveTextColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildExpandButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: _onExpandCollapse,
      child: Container(
        height: _controlsConfiguration.controlBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: _betterPlayerController!.isFullScreen
            ? (_controlsConfiguration.fullscreenDisableIcon ?? const SizedBox())
            : (_controlsConfiguration.fullscreenEnableIcon ?? const SizedBox()),
      ),
    );
  }

  Widget _buildHitArea() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Container(
      child: Center(
        child: _buildMiddleRow(),
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: _betterPlayerController?.isLiveStream() == true
          ? const SizedBox()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlsConfiguration.enableSkips
                    ? Expanded(
                        child: _buildSkipButton(
                            _controlsConfiguration.skipBackIcon ??
                                const SizedBox()))
                    : const SizedBox(),
                Expanded(
                    child: _buildReplayButton(
                  _controller!,
                  _controller!.value.isPlaying
                      ? (_controlsConfiguration.pauseIcon ?? const SizedBox())
                      : (_controlsConfiguration.playIcon ?? const SizedBox()),
                  _controlsConfiguration.replayIcon ?? const SizedBox(),
                )),
                _controlsConfiguration.enableSkips
                    ? Expanded(
                        child: _buildForwardButton(
                            _controlsConfiguration.skipForwardIcon ??
                                const SizedBox()))
                    : const SizedBox(),
              ],
            ),
    );
  }

  Widget _buildHitAreaClickableButton({
    required Widget icon,
    required void Function() onClicked,
  }) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: onClicked,
        child: Align(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [icon],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(Widget icon) {
    return _buildHitAreaClickableButton(
      icon: icon,
      onClicked: skipBack,
    );
  }

  Widget _buildForwardButton(Widget icon) {
    return _buildHitAreaClickableButton(
      icon: icon,
      onClicked: skipForward,
    );
  }

  Widget _buildReplayButton(VideoPlayerController controller,
      Widget playPauseIcon, Widget replayIcon) {
    final bool isFinished = isVideoFinished(_latestValue);
    return _buildHitAreaClickableButton(
      icon: isFinished ? replayIcon : playPauseIcon,
      onClicked: () {
        if (isFinished) {
          if (_latestValue != null && _latestValue!.isPlaying) {
            if (_displayTapped) {
              changePlayerControlsNotVisible(true);
            } else {
              cancelAndRestartTimer();
            }
          } else {
            _onPlayPause();
            changePlayerControlsNotVisible(true);
          }
        } else {
          _onPlayPause();
        }
      },
    );
  }

  Widget _buildPosition() {
    final position =
        _latestValue != null ? _latestValue!.position : Duration.zero;
    final duration = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration!
        : Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: RichText(
        text: TextSpan(
            text: BetterPlayerUtils.formatDuration(position),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _controlsConfiguration.textColor,
              decoration: TextDecoration.none,
            ),
            children: <TextSpan>[
              TextSpan(
                text: ' / ${BetterPlayerUtils.formatDuration(duration)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _controlsConfiguration.textColor.withOpacity(0.6),
                  decoration: TextDecoration.none,
                ),
              )
            ]),
      ),
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
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
    _showAfterExpandCollapseTimer =
        Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
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
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
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
          if (isVideoFinished(_latestValue) &&
              _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  Widget _buildProgressBar() {
    return Container(
      height: 30,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: BetterPlayerMaterialVideoProgressBar(
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
          backgroundColor: _controlsConfiguration.progressBarBackgroundColor,
        ),
      ),
    );
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return Container(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }

  // ===== Double-tap overlay and logic =====

  Widget _buildDoubleTapOverlay() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    final bool visible = _showDoubleTapOverlay && _doubleTapSide != null;
    if (!visible) return const SizedBox();

    final bool isLeft = _doubleTapSide == _DoubleTapSide.left;
    final Color dimColor = Colors.black.withOpacity(0.4);
    final TextStyle labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w700,
    );

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      child: Row(
        children: [
          // Left 40%
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
                            const Icon(Icons.fast_rewind,
                                color: Colors.white, size: 36),
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
          // Middle 20% neutral
          const Expanded(flex: 20, child: SizedBox()),
          // Right 40%
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
                            const Icon(Icons.fast_forward,
                                color: Colors.white, size: 36),
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
      _onDoubleTapZone(_DoubleTapSide.left);
    } else if (ratio > 0.6) {
      _onDoubleTapZone(_DoubleTapSide.right);
    } else {
      // neutral zone: let default onDoubleTap run
      _doubleTapConsumed = false;
    }
  }

  void _onDoubleTapZone(_DoubleTapSide side) {
    _doubleTapConsumed = true; // prevent default onDoubleTap behavior
    _doubleTapSide = side;
    _showDoubleTapOverlay = true;
    _doubleTapAccumMs = _doubleTapAccumMs + _doubleTapStepMs;

    // Haptic feedback per tap (light)
    HapticFeedback.lightImpact();

    // Reset grace timer
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
    int delta =
        _doubleTapAccumMs * (_doubleTapSide == _DoubleTapSide.left ? -1 : 1);
    int target = currentMs + delta;
    if (target < 0) target = 0;
    if (durationMs > 0 && target > durationMs) target = durationMs;

    // Haptic feedback medium when applying
    HapticFeedback.mediumImpact();

    await _betterPlayerController!.seekTo(Duration(milliseconds: target));

    // Reset state and fade out overlay
    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
    _doubleTapAccumMs = 0;
    _doubleTapSide = null;
    setState(() {
      _showDoubleTapOverlay = false;
    });
  }
}

enum _DoubleTapSide { left, right }
