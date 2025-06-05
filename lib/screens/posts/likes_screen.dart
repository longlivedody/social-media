import 'package:facebook_clone/widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:facebook_clone/services/post_services/post_service.dart';
import 'package:facebook_clone/widgets/custom_text.dart';

/// A screen that displays the list of users who liked a specific post.
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
            return const Center(child: CircularProgressIndicator());
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
