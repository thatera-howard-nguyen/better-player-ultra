import 'package:better_player/better_player.dart';
import 'package:example/constants.dart';
import 'package:flutter/material.dart';

class WidgetBelowSeekbarPage extends StatefulWidget {
  @override
  _WidgetBelowSeekbarPageState createState() => _WidgetBelowSeekbarPageState();
}

class _WidgetBelowSeekbarPageState extends State<WidgetBelowSeekbarPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      // Widget dưới seekbar - API mới đơn giản hơn
      widgetBelowSeekBar: _buildCustomWidgetBelowSeekbar(),
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enablePip: true,
        // Widget ở bên trái top bar
        widgetInTopBarLeft: _buildCustomWidgetInTopBarLeft(),
        playerTheme: BetterPlayerTheme.material,
      ),
    );
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.hlsPlaylistUrl,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    super.initState();
  }

  Widget _buildCustomWidgetInTopBarLeft() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            "HD",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomWidgetBelowSeekbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Custom controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous,
                label: "Previous",
                onTap: () {
                  print("Previous button tapped");
                },
              ),
              _buildControlButton(
                icon: Icons.fast_rewind,
                label: "Rewind 10s",
                onTap: () {
                  final currentPosition = _betterPlayerController
                      .videoPlayerController?.value.position;
                  if (currentPosition != null) {
                    final newPosition = Duration(
                      seconds: (currentPosition.inSeconds - 10)
                          .clamp(0, double.infinity)
                          .toInt(),
                    );
                    _betterPlayerController.seekTo(newPosition);
                  }
                },
              ),
              _buildControlButton(
                icon: Icons.fast_forward,
                label: "Forward 10s",
                onTap: () {
                  final currentPosition = _betterPlayerController
                      .videoPlayerController?.value.position;
                  final duration = _betterPlayerController
                      .videoPlayerController?.value.duration;
                  if (currentPosition != null && duration != null) {
                    final newPosition = Duration(
                      seconds: (currentPosition.inSeconds + 10)
                          .clamp(0, duration.inSeconds),
                    );
                    _betterPlayerController.seekTo(newPosition);
                  }
                },
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                label: "Next",
                onTap: () {
                  print("Next button tapped");
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Timeline on Seekbar"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Timeline and fullscreen button are now positioned directly above the seekbar without fixed height constraints. Also demonstrates the new widgetInTopBarLeft feature showing an HD indicator on the left side of the top bar.",
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
        ],
      ),
    );
  }
}
