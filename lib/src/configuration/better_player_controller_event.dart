///Internal events of BetterPlayerController, used in widgets to update state.
enum BetterPlayerControllerEvent {
  ///Fullscreen mode has started.
  openFullscreen,

  ///Fullscreen mode has ended.
  hideFullscreen,

  ///Fullscreen mode has started for Picture-in-Picture (no orientation change).
  openFullscreenForPip,

  ///Subtitles changed.
  changeSubtitles,

  ///New data source has been set.
  setupDataSource,

  //Video has started.
  play
}
