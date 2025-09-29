import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BetterPlayerDemo(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BetterPlayerDemo extends StatefulWidget {
  const BetterPlayerDemo({super.key});

  @override
  State<BetterPlayerDemo> createState() => _BetterPlayerDemoState();
}

class _BetterPlayerDemoState extends State<BetterPlayerDemo> {
  late final BetterPlayerController _controller;

  @override
  void initState() {
    super.initState();
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
    );
    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        autoDetectFullscreenDeviceOrientation: true,
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Better Player Demo")),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: BetterPlayer(controller: _controller),
        ),
      ),
    );
  }
}
