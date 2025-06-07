import 'package:facebook_clone/widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:facebook_clone/services/post_services/post_service.dart';
import 'package:facebook_clone/widgets/custom_text.dart';
import 'package:shimmer/shimmer.dart';

class LikesScreen extends StatelessWidget {
  final String postId;
  final PostService _postService = PostService();

  LikesScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Row(
          children: [
            CustomIconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                iconData: Icons.arrow_back_ios),
            const Text('Likes'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postService.getLikesForPost(postId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: CustomText(
                'Error loading likes',
                style: TextStyle(color: Colors.red[700]),
              ),
            );
          }

          if (!snapshot.hasData) {
            // Shimmer loading placeholder
            return ListView.builder(
              itemCount: 8,
              itemBuilder: (context, index) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 120,
                          height: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          final likes = snapshot.data!;

          if (likes.isEmpty) {
            return const Center(
              child: CustomText(
                'No likes yet',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: likes.length,
            itemBuilder: (context, index) {
              final like = likes[index];
              return ListTile(
                leading: Icon(
                  Icons.thumb_up_alt,
                  color: Colors.blue,
                ),
                title: CustomText(
                  like['username'] ?? 'Anonymous',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
