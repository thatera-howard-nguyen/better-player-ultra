import 'package:better_player/better_player.dart';
import 'package:example/constants.dart';
import 'package:flutter/material.dart';

class OverlayTouchTestPage extends StatefulWidget {
  @override
  _OverlayTouchTestPageState createState() => _OverlayTouchTestPageState();
}

class _OverlayTouchTestPageState extends State<OverlayTouchTestPage> {
  late BetterPlayerController _betterPlayerController;
  int _overlayTapCount = 0;

  @override
  void initState() {
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      handleLifecycle: true,
      overlay: _buildOverlay(),
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _setupDataSource();
    super.initState();
  }

  void _setupDataSource() async {
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.networkTestVideoEncryptUrl,
    );
    _betterPlayerController.setupDataSource(dataSource);
  }

  Widget _buildOverlay() {
    return Positioned(
      top: 50,
      right: 20,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _overlayTapCount++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Overlay tapped $_overlayTapCount times!'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          width: 100,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              'Tap me!\n$_overlayTapCount',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Overlay Touch Test"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Test overlay touch functionality when controls are disabled.\n"
              "On Android: Overlay should work when controls are disabled.\n"
              "On iOS: Overlay should now work when controls are disabled (fixed).",
              style: TextStyle(fontSize: 16),
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Overlay tap count: $_overlayTapCount",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Wrap(
                  children: [
                    TextButton(
                      child: Text("Disable controls"),
                      onPressed: () {
                        _betterPlayerController.setControlsEnabled(false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Controls disabled - try tapping overlay'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    TextButton(
                      child: Text("Enable controls"),
                      onPressed: () {
                        _betterPlayerController.setControlsEnabled(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Controls enabled'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    TextButton(
                      child: Text("Reset counter"),
                      onPressed: () {
                        setState(() {
                          _overlayTapCount = 0;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
