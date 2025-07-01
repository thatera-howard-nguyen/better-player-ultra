import 'package:better_player/better_player.dart';
import 'package:example/constants.dart';
import 'package:flutter/material.dart';

class WidgetInTopbarLeftPage extends StatefulWidget {
  @override
  _WidgetInTopbarLeftPageState createState() => _WidgetInTopbarLeftPageState();
}

class _WidgetInTopbarLeftPageState extends State<WidgetInTopbarLeftPage> {
  late BetterPlayerController _betterPlayerController;
  int _currentExample = 0;

  final List<String> _exampleNames = [
    "HD Indicator",
    "Quality Selector",
    "Chapter Info",
    "Custom Button",
  ];

  @override
  void initState() {
    _setupPlayer();
    super.initState();
  }

  void _setupPlayer() {
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      widgetInTopBarLeft: _getCurrentExampleWidget(),
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enablePip: true,
        playerTheme: BetterPlayerTheme.material,
      ),
    );
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.hlsPlaylistUrl,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
  }

  Widget _getCurrentExampleWidget() {
    switch (_currentExample) {
      case 0:
        return _buildHDIndicator();
      case 1:
        return _buildQualitySelector();
      case 2:
        return _buildChapterInfo();
      case 3:
        return _buildCustomButton();
      default:
        return _buildHDIndicator();
    }
  }

  void _changeExample(int index) {
    setState(() {
      _currentExample = index;
      _setupPlayer();
    });
  }

  Widget _buildHDIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hd,
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

  Widget _buildQualitySelector() {
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
            Icons.settings,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            "1080p",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.arrow_drop_down,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterInfo() {
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
            Icons.bookmark,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            "Ch. 1",
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

  Widget _buildCustomButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            "Like",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Widget in Top Bar Left"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "This demonstrates the widgetInTopBarLeft feature. The widget on the left side of the top bar can have any height without affecting the widgets on the right side.",
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          // Example selector
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _exampleNames.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () => _changeExample(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentExample == index ? Colors.blue : Colors.grey,
                    ),
                    child: Text(_exampleNames[index]),
                  ),
                );
              },
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
