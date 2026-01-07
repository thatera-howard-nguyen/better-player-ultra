import 'dart:io';
import 'dart:ui';

import 'package:better_player/better_player.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/material.dart';

///Wraps the player with a blurred replica of the current video to emulate Ambient Mode.
class BetterPlayerAmbientBackdrop extends StatelessWidget {
  const BetterPlayerAmbientBackdrop({
    required this.controller,
    required this.child,
    super.key,
  });

  final BetterPlayerController controller;
  final Widget child;

  bool _shouldShowAmbient(BuildContext context) {
    final configuration = controller.betterPlayerConfiguration;

    if (!configuration.enableAmbientMode) {
      return false;
    }

    if (configuration.ambientModeFullScreenOnly && !controller.isFullScreen) {
      return false;
    }

    if (configuration.ambientModeLandscapeOnly) {
      final orientation = MediaQuery.maybeOf(context)?.orientation;
      if (orientation == null || orientation != Orientation.landscape) {
        return false;
      }
    }

    final videoController = controller.videoPlayerController;
    if (videoController == null || !videoController.value.initialized) {
      return false;
    }

    return true;
  }

  Widget _buildBlurredVideo({
    required double blurSigma,
    required double darken,
  }) {
    // On iOS, ImageFilter.blur doesn't work well with UiKitView (native view)
    // Try a different approach: wrap video in RepaintBoundary and use
    // ImageFiltered in a special way, or use BackdropFilter
    if (Platform.isIOS) {
      // Solution for iOS: Use RepaintBoundary to separate video into a separate layer
      // and apply blur using BackdropFilter
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video layer - rendered first
            RepaintBoundary(
              child: _AmbientVideoSurface(
                controller: controller,
              ),
            ),
            // BackdropFilter to blur video behind
            // BackdropFilter will blur everything in the same layer behind it
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      );
    } else {
      // On Android and other platforms, use ImageFiltered as before
      return ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: ClipRect(
          child: _AmbientVideoSurface(
            controller: controller,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackColor = controller
        .betterPlayerConfiguration.controlsConfiguration.backgroundColor;

    if (!_shouldShowAmbient(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(color: fallbackColor),
        child: child,
      );
    }

    final configuration = controller.betterPlayerConfiguration;
    final blurSigma = configuration.ambientBlurSigma.clamp(0, 100).toDouble();
    final scale = configuration.ambientScale.clamp(1.0, 2.0);
    final darken = configuration.ambientDarken.clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity:
                  controller.videoPlayerController?.value.initialized == true
                      ? 1
                      : 0,
              duration: const Duration(milliseconds: 300),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.scale(
                      scale: scale,
                      child: RepaintBoundary(
                        child: ClipRect(
                          child: _buildBlurredVideo(
                            blurSigma: blurSigma,
                            darken: darken,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.black.withValues(alpha: darken),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientVideoSurface extends StatelessWidget {
  const _AmbientVideoSurface({
    required this.controller,
  });

  final BetterPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final videoController = controller.videoPlayerController;
    if (videoController == null ||
        !videoController.value.initialized ||
        videoController.value.size == null ||
        videoController.value.size == Size.zero) {
      return const SizedBox();
    }

    final size = videoController.value.size!;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(videoController),
      ),
    );
  }
}
