import 'package:facebook_clone/features/layout/model/layout_model.dart';
import 'package:facebook_clone/screens/posts/create_update_post/create_post_screen.dart';
import 'package:facebook_clone/screens/posts/post_section/posts_list.dart';
import 'package:facebook_clone/core/utlis/animation_navigate.dart';
import 'package:facebook_clone/core/widgets/shimmer.dart';
import 'package:flutter/material.dart';

import '../../models/post_data_model.dart';
import 'package:facebook_clone/services/post_services/post_service.dart';
import 'package:facebook_clone/core/widgets/custom_text.dart';

class PostsScreen extends StatefulWidget {
  final UserModel user;
  const PostsScreen({super.key, required this.user});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen>
    with AutomaticKeepAliveClientMixin<PostsScreen> {
  final PostService _postService = PostService();
  late Future<List<PostDataModel>> _postsFuture;
  // final user = supabase.Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  void _loadPosts() {
    setState(() {
      _postsFuture = _postService.getFriendsPosts(widget.user.id);
    });
  }

  Future<void> _handleRefresh() async {
    _loadPosts();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: _buildPostsContent(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create Post',
        onPressed: () async {
          await navigateWithTransition(
            context,
            const CreatePostScreen(),
            type: TransitionType.slideFromBottom,
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPostsContent() {
    return FutureBuilder<List<PostDataModel>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListShimmer();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildEmptyState(scrollable: true);
        }

        final posts = snapshot.data!;

        if (posts.isEmpty) {
          return _buildEmptyState();
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            PostsList(
              posts: posts,
              onRefresh: _handleRefresh,
              postService: _postService,
              userId: widget.user.id,
              onPostDeleted: _loadPosts,
              user: widget.user,
            )
          ],
        );
      },
    );
  }

  Widget _buildEmptyState({bool scrollable = false}) {
    final content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 60, color: Colors.grey[500]),
          const SizedBox(height: 16),
          CustomText(
            'You have no Posts yet.',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          CustomText(
            'Be the first to post!',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(
            height: 15,
          ),
          ElevatedButton(
            onPressed: () {
              _loadPosts();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );

    return scrollable
        ? CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                child: content,
              ),
            ],
          )
        : content;
  }
}
