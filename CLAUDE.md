# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`better_player` (Better Player Ultra) is a Flutter plugin for advanced video playback. It is a fork/continuation of Chewie with bundled native (Android/iOS) implementations and a higher-level controller API on top of the embedded `video_player` source.

- Pubspec name: `better_player` (version `0.0.84`)
- Dart SDK: `>=3.0.0 <4.0.0`, Flutter `>=3.3.0`
- Platforms: Android (`com.jhomlala.better_player.BetterPlayerPlugin`, Kotlin) and iOS (Obj-C/Swift in `ios/Classes`)

## Common commands

Run from the repo root unless noted:

- Install deps: `flutter pub get`
- Static analysis (this is what CI runs): `flutter analyze` — note CI runs `pub get` inside `example/` first, then `analyze` from repo root.
- Format check (CI gate): `flutter format -n --set-exit-if-changed .`
- Run tests: `flutter test`
- Run a single test file: `flutter test test/better_player_controller_test.dart`
- Run a single test by name: `flutter test --plain-name "<test name>"`
- Run the example app: `cd example && flutter pub get && flutter run`

CI (`.github/workflows/ci.yml`) currently runs **format check + analyze**; the `test` job is commented out, but tests still exist under `test/` and should be kept green locally.

## Architecture

The public API surface is re-exported from `lib/better_player.dart`. Everything else lives under `lib/src/`. The codebase is layered:

1. **Embedded `video_player` (`lib/src/video_player/`)** — A vendored copy of the Flutter `video_player` plugin (platform interface + method channel implementation). `BetterPlayerController` talks to this layer, not to the upstream pub package. The native Android/iOS code under `android/` and `ios/Classes/` implements the matching method channel (`BetterPlayerPlugin` + `BetterPlayer`/`BetterPlayerView`).

2. **Core (`lib/src/core/`)**
   - `BetterPlayer` (widget) — entry-point widget; wraps controls + the underlying video surface.
   - `BetterPlayerController` — the central state machine. Owns a `VideoPlayerController`, dispatches `BetterPlayerEvent`s, manages data sources, subtitles, ASMS tracks, DRM, playlists, picture-in-picture, fullscreen, and notifications. Most feature work touches this class.
   - `BetterPlayerControllerProvider` / `BetterPlayerAmbient` — `InheritedWidget`s used by control widgets to read the controller without explicit prop drilling.
   - `BetterPlayerWithControls` — composes the video surface with the active controls implementation (Material vs Cupertino) and overlay UI.

3. **Configuration (`lib/src/configuration/`)** — Plain immutable config objects passed into the controller: `BetterPlayerConfiguration`, `BetterPlayerDataSource`, `BetterPlayerControlsConfiguration`, DRM, cache, buffering, notifications, translations, theme, events. The configuration objects are the primary public API consumers wire up.

4. **Controls (`lib/src/controls/`)** — Two control variants (`better_player_material_controls.dart`, `better_player_cupertino_controls.dart`) sharing `BetterPlayerControlsState` (mixin holding shared progress/seek/visibility logic). Progress bars and the overflow menu live here. Custom gesture work (e.g. the double-tap seek spec in `docs/double_tap_spec.md`) belongs in this layer, typically composed with `BetterPlayerMultipleGestureDetector`.

5. **Adaptive streaming (`lib/src/asms/`, `lib/src/hls/`, `lib/src/dash/`)** — ASMS = "Adaptive Streaming Media Source", the abstraction over HLS and DASH. The HLS parser is a vendored Dart port under `lib/src/hls/hls_parser/`. DASH parsing uses the `xml` package via `better_player_dash_utils.dart`. These produce `BetterPlayerAsmsTrack` / `BetterPlayerAsmsSubtitle` / `BetterPlayerAsmsAudioTrack` lists consumed by the controller for quality/audio/subtitle pickers.

6. **Subtitles (`lib/src/subtitles/`)** — Parses SRT/WEBVTT (with HTML tags via `flutter_widget_from_html_core`) and HLS-segmented subtitles; renders via the controls layer.

7. **Playlist (`lib/src/playlist/`)** — `BetterPlayerPlaylistController` wraps a `BetterPlayerController` and advances through a list of `BetterPlayerDataSource`s.

8. **List player (`lib/src/list/`)** — Specialized controller/widget for video-in-`ListView` use cases (uses `visibility_detector` to autoplay when visible).

9. **DRM / ClearKey (`lib/src/clearkey/`, configuration DRM types)** — Token, Widevine, FairPlay (EZDRM) and ClearKey wired through native players.

### Event flow

`BetterPlayerController` exposes a `Stream<BetterPlayerEvent>` (typed by `BetterPlayerEventType`). Almost everything UI cares about — buffering, play/pause, seek, fullscreen toggles, control visibility, errors — flows through this stream. New features should emit appropriate events instead of relying on direct widget callbacks.

### Native ↔ Dart boundary

The `video_player` method channel is the **only** boundary. Adding a native capability requires changes in three places: `MethodChannelVideoPlayer` (Dart), `BetterPlayer.m` / `BetterPlayerPlugin.m` (iOS), and the Kotlin sources under `android/src/main/kotlin/`. Higher-level Dart code should never assume a platform — it goes through `VideoPlayerController` (vendored).

## Conventions

- Lint rules live in `analysis_options.yaml` and extend `package:lint`. Notable enforced rules: `prefer_const_constructors`, `prefer_const_declarations`, `avoid_dynamic_calls`, `close_sinks`, `cancel_subscriptions`. Disabled (intentionally): `sort_constructors_first`, `sized_box_for_whitespace`, `sort_pub_dependencies`, `avoid_unnecessary_containers`.
- Public API additions must be exported from `lib/better_player.dart` to be visible to plugin consumers.
- Specs/design notes for in-progress features live under `docs/` (e.g. `docs/double_tap_spec.md` describes the 40/20/40 double-tap seek behavior, accumulation grace window, and overlay rules — consult it before changing tap-zone logic in the controls layer).

## GitHub / PR rules

- This repo has two remotes: `origin` = `thatera-howard-nguyen/better-player-ultra` (the working fork), `upstream` = `Lo4D/better-player-ultra` (original). `gh` may auto-detect `upstream` as the base.
- **Always** create PRs against `thatera-howard-nguyen/better-player-ultra` using the explicit flag: `gh pr create --repo thatera-howard-nguyen/better-player-ultra ...`

## Testing notes

- Tests under `test/` use the local mocks `mock_video_player_controller.dart`, `mock_method_channel.dart`, and `better_player_mock_controller.dart` — prefer extending these rather than introducing a new mocking framework.
- `better_player_test_utils.dart` contains shared fixtures.
