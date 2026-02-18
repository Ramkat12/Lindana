import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class playerClass extends StatefulWidget {
  const playerClass({super.key, required this.videoID, this.title});

  final String videoID;
  final String? title;

  @override
  State<playerClass> createState() => playerClassState();
}

class playerClassState extends State<playerClass> {
  late final YoutubePlayerController _controller = YoutubePlayerController(
    initialVideoId: widget.videoID,
    flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? "Player"),
        backgroundColor: const Color.fromARGB(255, 91, 171, 237),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: const Color.fromARGB(255, 91, 171, 237),
          ),
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
