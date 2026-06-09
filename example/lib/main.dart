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

class VideoItem {
  const VideoItem({required this.title, required this.url});

  final String title;
  final String url;
}

const List<VideoItem> _videos = <VideoItem>[
  VideoItem(
    title: 'Accrobra',
    url: 'https://www.papytane.com/mp4/accrobra.mp4',
  ),
  VideoItem(
    title: 'Airelles',
    url: 'https://www.papytane.com/mp4/airelles.mp4',
  ),
  VideoItem(
    title: 'Anni 18 ans',
    url: 'https://www.papytane.com/mp4/anni18an.mp4',
  ),
  VideoItem(
    title: 'Arnaudin',
    url: 'https://www.papytane.com/mp4/arnaudin.mp4',
  ),
];

class BetterPlayerDemo extends StatefulWidget {
  const BetterPlayerDemo({super.key});

  @override
  State<BetterPlayerDemo> createState() => _BetterPlayerDemoState();
}

class _BetterPlayerDemoState extends State<BetterPlayerDemo> {
  late final BetterPlayerController _controller;
  // PiP (iOS) cần GlobalKey gắn vào widget BetterPlayer để định vị render box.
  final GlobalKey _betterPlayerKey = GlobalKey();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        autoDetectFullscreenDeviceOrientation: true,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          playerTheme: BetterPlayerTheme.material,
          // Hiện nút Picture-in-Picture trong menu overflow của controls.
          enablePip: true,
        ),
      ),
      betterPlayerDataSource: _buildDataSource(_videos[_selectedIndex].url),
    );
    // Cho controller biết GlobalKey để nút PiP trong controls hoạt động.
    _controller.setBetterPlayerGlobalKey(_betterPlayerKey);
  }

  BetterPlayerDataSource _buildDataSource(String url) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
    );
  }

  Future<void> _playVideo(int index) async {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    await _controller.setupDataSource(_buildDataSource(_videos[index].url));
    _controller.play();
  }

  Future<void> _enterPip() async {
    final isSupported = await _controller.isPictureInPictureSupported();
    if (!isSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Picture in Picture không khả dụng')),
      );
      return;
    }
    await _controller.enablePictureInPicture(_betterPlayerKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Better Player Demo')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(
              key: _betterPlayerKey,
              controller: _controller,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _enterPip,
              icon: const Icon(Icons.picture_in_picture_alt),
              label: const Text('Picture in Picture'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _videos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final video = _videos[index];
                final isSelected = index == _selectedIndex;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.play_circle_fill
                        : Icons.play_circle_outline,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    video.title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    video.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: isSelected,
                  onTap: () => _playVideo(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
