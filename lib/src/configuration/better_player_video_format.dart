///Representation of possible video formats in Better Player.
enum BetterPlayerVideoFormat {
  /// Automatically detect the format from the URL or file extension.
  /// Detects: .m3u8 → HLS, .mpd → DASH, .ism/.isml → SS, otherwise lets
  /// the native player decide.
  auto,
  dash,
  hls,
  ss,
  other,
}
