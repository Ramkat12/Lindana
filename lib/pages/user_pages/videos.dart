import 'package:flutter/material.dart';
import 'package:is_project_1/pages/user_pages/player.dart' show playerClass;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final videoUrls = [
  'https://www.youtube.com/watch?v=eANy2M_Filw',
  'https://www.youtube.com/watch?v=7zhX02q-b5w',
  'https://www.youtube.com/watch?v=uI4ATOriCIw',
];

class VideoInfo {
  final String url;
  final String? title;
  final String? description;

  VideoInfo({required this.url, this.title, this.description});
}

class videosClass extends StatefulWidget {
  const videosClass({super.key});

  @override
  State<videosClass> createState() => videosClassState();
}

class videosClassState extends State<videosClass> {
  List<VideoInfo> videoInfoList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideoInfo();
  }

  Future<void> _loadVideoInfo() async {
    List<VideoInfo> tempList = [];

    for (String url in videoUrls) {
      final videoID = YoutubePlayer.convertUrlToId(url);
      if (videoID != null) {
        String? title = await _fetchVideoTitle(videoID);
        tempList.add(
          VideoInfo(url: url, title: title ?? _getDefaultTitle(videoID)),
        );
      }
    }

    setState(() {
      videoInfoList = tempList;
      isLoading = false;
    });
  }

  Future<String?> _fetchVideoTitle(String videoId) async {
    try {
      // Using YouTube oEmbed API to get video title
      final response = await http.get(
        Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['title'];
      }
    } catch (e) {
      print('Error fetching video title: $e');
    }
    return null;
  }

  String _getDefaultTitle(String videoId) {
    // Fallback titles if API fails
    switch (videoId) {
      case 'eANy2M_Filw':
        return 'Educational Video 1';
      case '7zhX02q-b5w':
        return 'Educational Video 2';
      case 'uI4ATOriCIw':
        return 'Educational Video 3';
      default:
        return 'Video';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: videoInfoList.length,
              itemBuilder: (context, index) {
                final videoInfo = videoInfoList[index];
                final videoID = YoutubePlayer.convertUrlToId(videoInfo.url);

                if (videoID == null) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => playerClass(
                            videoID: videoID,
                            title: videoInfo.title,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Video Thumbnail with play overlay
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              Image.network(
                                YoutubePlayer.getThumbnail(
                                  videoId: videoID,
                                  quality: ThumbnailQuality.high,
                                ),
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: double.infinity,
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.video_library,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                              // Play button overlay
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black26,
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Video title
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            videoInfo.title ?? 'Loading...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget thumbnail() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(10),
      color: const Color.fromARGB(255, 91, 171, 237),
      child: const Center(
        child: Text(
          'Videos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
