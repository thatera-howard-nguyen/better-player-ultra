# Better Player Ultra

A Flutter plugin for advanced video playback on Android and iOS. Fork of [better_player](https://github.com/jhomlala/betterplayer) with continued development and additional features.

## Features

- HLS and DASH adaptive streaming (track, audio, and subtitle selection)
- Subtitles: SRT, WEBVTT with HTML tags, HLS-segmented, multiple tracks
- DRM: token, Widevine, FairPlay (EZDRM), ClearKey
- Picture-in-Picture (Android and iOS)
- Playlist and ListView autoplay support
- Cache support
- Alternative resolution switching
- Playback speed control
- HTTP headers and custom aspect ratio / BoxFit
- Lock screen / notification controls
- Material and Cupertino control variants

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  better_player:
    git:
      url: https://github.com/thatera-howard-nguyen/better-player-ultra.git
```

Then run `flutter pub get`.

## Basic usage

```dart
BetterPlayerController controller = BetterPlayerController(
  const BetterPlayerConfiguration(autoPlay: true),
  betterPlayerDataSource: BetterPlayerDataSource(
    BetterPlayerDataSourceType.network,
    'https://example.com/video.m3u8',
  ),
);

BetterPlayer(controller: controller);
```

Dispose the controller when done:

```dart
controller.dispose();
```

## Example app

See the `example/` directory for a full working demo.
