import 'dart:async';
import 'package:better_player/better_player.dart';
import 'package:better_player/src/configuration/better_player_controller_event.dart';
import 'package:better_player/src/core/better_player_ambient.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/core/better_player_with_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

///Widget which uses provided controller to render video player.
class BetterPlayer extends StatefulWidget {
  const BetterPlayer({Key? key, required this.controller}) : super(key: key);

  factory BetterPlayer.network(
    String url, {
    BetterPlayerConfiguration? betterPlayerConfiguration,
  }) =>
      BetterPlayer(
        controller: BetterPlayerController(
          betterPlayerConfiguration ?? const BetterPlayerConfiguration(),
          betterPlayerDataSource:
              BetterPlayerDataSource(BetterPlayerDataSourceType.network, url),
        ),
      );

  factory BetterPlayer.file(
    String url, {
    BetterPlayerConfiguration? betterPlayerConfiguration,
  }) =>
      BetterPlayer(
        controller: BetterPlayerController(
          betterPlayerConfiguration ?? const BetterPlayerConfiguration(),
          betterPlayerDataSource:
              BetterPlayerDataSource(BetterPlayerDataSourceType.file, url),
        ),
      );

  final BetterPlayerController controller;

  @override
  _BetterPlayerState createState() {
    return _BetterPlayerState();
  }
}

class _BetterPlayerState extends State<BetterPlayer>
    with WidgetsBindingObserver {
  BetterPlayerConfiguration get _betterPlayerConfiguration =>
      widget.controller.betterPlayerConfiguration;

  bool _isFullScreen = false;

  ///State of navigator on widget created
  late NavigatorState _navigatorState;

  ///Flag which determines if widget has initialized
  bool _initialized = false;

  ///Subscription for controller events
  StreamSubscription? _controllerEventSubscription;

  ///Current orientation of the device
  Orientation? _currentOrientation;

  ///Flag to track if fullscreen was triggered by orientation change
  bool _fullscreenTriggeredByOrientation = false;

  ///Flag to track if fullscreen was triggered by manual control
  bool _fullscreenTriggeredByManual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    if (!_initialized) {
      final navigator = Navigator.of(context);
      setState(() {
        _navigatorState = navigator;
        _currentOrientation = MediaQuery.of(context).orientation;
      });
      _setup();
      _initialized = true;
    } else {
      // Check for orientation changes
      final newOrientation = MediaQuery.of(context).orientation;
      if (_currentOrientation != newOrientation) {
        _handleOrientationChange(newOrientation);
      }
    }
    super.didChangeDependencies();
  }

  Future<void> _setup() async {
    _controllerEventSubscription =
        widget.controller.controllerEventStream.listen(onControllerEvent);

    //Default locale
    var locale = const Locale("en", "US");
    try {
      if (mounted) {
        final contextLocale = Localizations.localeOf(context);
        locale = contextLocale;
      }
    } catch (exception) {
      BetterPlayerUtils.log(exception.toString());
    }
    widget.controller.setupTranslations(locale);

    // Set up orientation constraints for portrait videos
    _setupOrientationConstraints();
  }

  ///Set up orientation constraints based on video aspect ratio
  void _setupOrientationConstraints() {
    // Listen for video initialization to set orientation constraints
    widget.controller.videoPlayerController?.addListener(() {
      if (!mounted) {
        return;
      }
      // Don't override orientations while in fullscreen or during manual fullscreen trigger
      if (_isFullScreen || _fullscreenTriggeredByManual) {
        return;
      }

      final aspectRatio =
          widget.controller.videoPlayerController?.value.aspectRatio ?? 1.0;

      if (_isPortraitVideo(aspectRatio)) {
        _setupPortraitVideoOrientationConstraints();
      } else {
        _setupLandscapeVideoOrientationConstraints();
      }
    });
  }

  ///Setup orientation constraints for portrait videos
  void _setupPortraitVideoOrientationConstraints() {
    // Avoid changing orientations when in fullscreen
    if (_isFullScreen || _fullscreenTriggeredByManual) {
      return;
    }
    BetterPlayerUtils.log(
        "Portrait video - Setting up orientation constraints");
    // Force portrait orientation immediately for portrait videos
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  ///Setup orientation constraints for landscape videos
  void _setupLandscapeVideoOrientationConstraints() {
    // Avoid changing orientations when in fullscreen
    if (_isFullScreen) {
      return;
    }
    BetterPlayerUtils.log(
        "Landscape video - Setting up orientation constraints (allowing all orientations)");
    // Allow all orientations for landscape videos to enable rotation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    ///If somehow BetterPlayer widget has been disposed from widget tree and
    ///full screen is on, then full screen route must be pop and return to normal
    ///state.
    if (_isFullScreen) {
      WakelockPlus.disable();
      _navigatorState.maybePop();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: _betterPlayerConfiguration.systemOverlaysAfterFullScreen);
      SystemChrome.setPreferredOrientations(
          _betterPlayerConfiguration.deviceOrientationsAfterFullScreen);
    }

    WidgetsBinding.instance.removeObserver(this);
    _controllerEventSubscription?.cancel();
    widget.controller.dispose();
    VisibilityDetectorController.instance
        .forget(Key("${widget.controller.hashCode}_key"));
    super.dispose();
  }

  @override
  void didUpdateWidget(BetterPlayer oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _controllerEventSubscription?.cancel();
      _controllerEventSubscription =
          widget.controller.controllerEventStream.listen(onControllerEvent);
    }
    super.didUpdateWidget(oldWidget);
  }

  void onControllerEvent(BetterPlayerControllerEvent event) {
    switch (event) {
      case BetterPlayerControllerEvent.openFullscreen:
        // Check if this is a manual fullscreen (not from orientation)
        if (!_fullscreenTriggeredByOrientation) {
          _fullscreenTriggeredByManual = true;
          // Handle manual fullscreen with YouTube-like behavior
          _handleManualFullscreen();
        }
        onFullScreenChanged();
        break;
      case BetterPlayerControllerEvent.hideFullscreen:
        // Check if this is a manual fullscreen (not from orientation)
        if (!_fullscreenTriggeredByOrientation) {
          _fullscreenTriggeredByManual = true;
        }
        onFullScreenChanged();
        break;
      default:
        setState(() {});
        break;
    }
  }

  ///Handle manual fullscreen with YouTube-like behavior
  void _handleManualFullscreen() {
    if (!mounted) return;

    final aspectRatio =
        widget.controller.videoPlayerController?.value.aspectRatio ?? 1.0;

    BetterPlayerUtils.log(
        "Manual fullscreen - Aspect ratio: $aspectRatio (threshold: 4:3 = ${4.0 / 3.0})");

    if (_isPortraitVideo(aspectRatio)) {
      _handlePortraitVideoManualFullscreen();
    } else {
      _handleLandscapeVideoManualFullscreen();
    }
  }

  ///Check if video is portrait based on aspect ratio
  bool _isPortraitVideo(double aspectRatio) {
    return aspectRatio <= 4.0 / 3.0;
  }

  ///Handle manual fullscreen for portrait videos
  void _handlePortraitVideoManualFullscreen() {
    BetterPlayerUtils.log(
        "Portrait video - Manual fullscreen: forcing portrait orientation");
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  ///Handle manual fullscreen for landscape videos
  void _handleLandscapeVideoManualFullscreen() {
    BetterPlayerUtils.log(
        "Landscape video - Manual fullscreen: forcing landscape orientation");
    // Force landscape on manual fullscreen to rotate even if system rotate is locked
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  ///Handle orientation changes and automatically toggle fullscreen
  void _handleOrientationChange(Orientation newOrientation) {
    if (!mounted) return;

    setState(() {
      _currentOrientation = newOrientation;
    });

    final aspectRatio =
        widget.controller.videoPlayerController?.value.aspectRatio ?? 1.0;

    BetterPlayerUtils.log(
        "Orientation change - New: $newOrientation, Aspect ratio: $aspectRatio (threshold: 4:3 = ${4.0 / 3.0}), Manual triggered: $_fullscreenTriggeredByManual, Is fullscreen: $_isFullScreen");

    // Only handle automatic fullscreen if not manually triggered
    if (!_fullscreenTriggeredByManual) {
      if (_isPortraitVideo(aspectRatio)) {
        _handlePortraitVideoOrientationChange(newOrientation);
      } else {
        _handleLandscapeVideoOrientationChange(newOrientation);
      }
    }
  }

  ///Handle orientation changes for portrait videos
  void _handlePortraitVideoOrientationChange(Orientation newOrientation) {
    // For portrait videos: auto fullscreen in portrait mode, prevent landscape rotation
    if (newOrientation == Orientation.portrait && !_isFullScreen) {
      BetterPlayerUtils.log("Portrait video - entering fullscreen");
      _fullscreenTriggeredByOrientation = true;
      widget.controller.enterFullScreen();
    }
    // Prevent landscape rotation for portrait videos always
    if (newOrientation == Orientation.landscape) {
      BetterPlayerUtils.log("Portrait video - preventing landscape rotation");
      _preventLandscapeRotationForPortraitVideo();
    }
  }

  ///Handle orientation changes for landscape videos
  void _handleLandscapeVideoOrientationChange(Orientation newOrientation) {
    // For landscape videos: enter fullscreen when rotating to landscape
    if (newOrientation == Orientation.landscape && !_isFullScreen) {
      BetterPlayerUtils.log("Landscape video - entering fullscreen");
      _fullscreenTriggeredByOrientation = true;
      widget.controller.enterFullScreen();
    }
    // Exit fullscreen when rotating to portrait for landscape videos
    else if (newOrientation == Orientation.portrait && _isFullScreen) {
      BetterPlayerUtils.log(
          "Landscape video - exiting fullscreen due to portrait rotation");
      _fullscreenTriggeredByOrientation = true;
      widget.controller.exitFullScreen();
      // Immediately restore post-fullscreen orientations to allow portrait
      final after =
          _betterPlayerConfiguration.deviceOrientationsAfterFullScreen;
      SystemChrome.setPreferredOrientations(after);
    }
  }

  ///Prevent landscape rotation for portrait videos
  void _preventLandscapeRotationForPortraitVideo() {
    // Force back to portrait orientation immediately
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  ///Get orientations for portrait video fullscreen
  List<DeviceOrientation> _getPortraitVideoFullscreenOrientations() {
    BetterPlayerUtils.log(
        "Portrait video - Fullscreen orientations: portrait only");
    return [DeviceOrientation.portraitUp];
  }

  ///Get orientations for landscape video fullscreen
  List<DeviceOrientation> _getLandscapeVideoFullscreenOrientations() {
    BetterPlayerUtils.log(
        "Landscape video - Fullscreen orientations: allow landscape and portrait for rotation-based exit");
    return [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ];
  }

  // ignore: avoid_void_async
  Future<void> onFullScreenChanged() async {
    final controller = widget.controller;
    if (controller.isFullScreen && !_isFullScreen) {
      _isFullScreen = true;
      controller
          .postEvent(BetterPlayerEvent(BetterPlayerEventType.openFullscreen));
      await _pushFullScreenWidget(context);
    } else if (_isFullScreen) {
      Navigator.of(context, rootNavigator: true).pop();
      _isFullScreen = false;
      controller
          .postEvent(BetterPlayerEvent(BetterPlayerEventType.hideFullscreen));
      // Ensure device orientations are restored on any non-route exit path
      final after =
          _betterPlayerConfiguration.deviceOrientationsAfterFullScreen;
      SystemChrome.setPreferredOrientations(after);
    }

    // Reset flags after fullscreen change is complete
    if (_fullscreenTriggeredByOrientation) {
      _fullscreenTriggeredByOrientation = false;
    }
    if (_fullscreenTriggeredByManual) {
      _fullscreenTriggeredByManual = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BetterPlayerControllerProvider(
      controller: widget.controller,
      child: _buildPlayer(),
    );
  }

  Widget _buildFullScreenVideo(
      BuildContext context,
      Animation<double> animation,
      BetterPlayerControllerProvider controllerProvider) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BetterPlayerAmbientBackdrop(
        controller: widget.controller,
        child: Container(
          alignment: Alignment.center,
          child: controllerProvider,
        ),
      ),
    );
  }

  AnimatedWidget _defaultRoutePageBuilder(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      BetterPlayerControllerProvider controllerProvider) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return _buildFullScreenVideo(context, animation, controllerProvider);
      },
    );
  }

  Widget _fullScreenRoutePageBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final controllerProvider = BetterPlayerControllerProvider(
        controller: widget.controller, child: _buildPlayer());

    final routePageBuilder = _betterPlayerConfiguration.routePageBuilder;
    if (routePageBuilder == null) {
      return _defaultRoutePageBuilder(
          context, animation, secondaryAnimation, controllerProvider);
    }

    return routePageBuilder(
        context, animation, secondaryAnimation, controllerProvider);
  }

  Future<dynamic> _pushFullScreenWidget(BuildContext context) async {
    final TransitionRoute<void> route = PageRouteBuilder<void>(
      settings: const RouteSettings(),
      pageBuilder: _fullScreenRoutePageBuilder,
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // If fullscreen is triggered manually, don't let auto/config override the
    // forced orientation we just applied in _handleManualFullscreen.
    // Otherwise, apply auto-detect or configured orientations.
    if (!_fullscreenTriggeredByManual) {
      if (_betterPlayerConfiguration.autoDetectFullscreenDeviceOrientation ==
          true) {
        final aspectRatio =
            widget.controller.videoPlayerController?.value.aspectRatio ?? 1.0;

        List<DeviceOrientation> deviceOrientations;
        if (_isPortraitVideo(aspectRatio)) {
          deviceOrientations = _getPortraitVideoFullscreenOrientations();
        } else {
          deviceOrientations = _getLandscapeVideoFullscreenOrientations();
        }
        await SystemChrome.setPreferredOrientations(
          deviceOrientations
              .where((o) => o != DeviceOrientation.portraitDown)
              .toList(),
        );
      } else {
        await SystemChrome.setPreferredOrientations(
          widget.controller.betterPlayerConfiguration
              .deviceOrientationsOnFullScreen
              .where((o) => o != DeviceOrientation.portraitDown)
              .toList(),
        );
      }
    }

    if (!_betterPlayerConfiguration.allowedScreenSleep) {
      WakelockPlus.enable();
    }

    await Navigator.of(context, rootNavigator: true).push(route);
    _isFullScreen = false;
    widget.controller.exitFullScreen();

    // The wakelock plugins checks whether it needs to perform an action internally,
    // so we do not need to check Wakelock.isEnabled.
    WakelockPlus.disable();

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: _betterPlayerConfiguration.systemOverlaysAfterFullScreen);
    await SystemChrome.setPreferredOrientations(_betterPlayerConfiguration
        .deviceOrientationsAfterFullScreen
        .where((o) => o != DeviceOrientation.portraitDown)
        .toList());
  }

  Widget _buildPlayer() {
    return VisibilityDetector(
      key: Key("${widget.controller.hashCode}_key"),
      onVisibilityChanged: (VisibilityInfo info) =>
          widget.controller.onPlayerVisibilityChanged(info.visibleFraction),
      child: BetterPlayerWithControls(
        controller: widget.controller,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    widget.controller.setAppLifecycleState(state);
  }
}

///Page route builder used in fullscreen mode.
typedef BetterPlayerRoutePageBuilder = Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    BetterPlayerControllerProvider controllerProvider);
