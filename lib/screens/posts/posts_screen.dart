import 'package:flutter/material.dart';

// You'll create this file next
import '../../models/post_data_model.dart'; // Assuming this exists
import '../../models/user_model.dart'; // Assuming this exists
import 'post_item.dart'; // Assuming this exists
import 'post_shimmer_item.dart'; // Assuming this exists
import 'create_post_screen.dart'; // Assuming this exists
import 'package:facebook_clone/services/auth_services/auth_service.dart'; // Assuming this exists
// Assuming PostService is the correct name for the service providing getPosts()
import 'package:facebook_clone/services/post_services/post_service.dart'; // Or your actual PostService file
import 'package:facebook_clone/widgets/custom_text.dart'; // Assuming this exists

/// A screen that displays a list of posts with pull-to-refresh functionality
/// and the ability to create new posts.
class PostsScreen extends StatefulWidget {
  final User user; // Assuming User model exists
  final AuthService authService; // Assuming AuthService exists

  const PostsScreen({
    super.key,
    required this.user,
    required this.authService,
  });

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen>
    with AutomaticKeepAliveClientMixin {
  final PostService _postService = PostService();
  bool _isRefreshing = false;
  late final Stream<List<PostDataModel>> _postsStream;

  @override
  void initState() {
    super.initState();
    _postsStream = _postService.getPosts();
  }

  void _navigateToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          postService: _postService,
        ),
      ),
    );

    if (result == true) {
      _refreshPosts();
    }
  }

  /// Refreshes the posts list
  Future<void> _refreshPosts() async {
    if (!mounted) return;
    setState(() {
      _isRefreshing = true;
    });

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshPosts,
                  child: _buildPostsList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds the main posts list with error handling and empty state
  Widget _buildPostsList() {
    return StreamBuilder<List<PostDataModel>>(
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ShimmerList();
        }

        // Handle error state
        if (snapshot.hasError) {
          if (_isRefreshing && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _isRefreshing = false;
              });
            });
          }
          return _ErrorView(
            icon: Icons.error_outline,
            message: 'Error: ${snapshot.error}',
            color: Colors.red,
            onRetry: _refreshPosts,
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          if (_isRefreshing && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _isRefreshing = false;
              });
            });
          }
          return const Center(
            child: CustomText('No posts available or failed to load.'),
          );
        }

        // Handle data successfully received
        final posts = snapshot.data!;
        if (_isRefreshing && mounted) {
          // Data received, refresh is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isRefreshing = false;
            });
          });
        }

        if (posts.isEmpty) {
          return const Center(
            child: CustomText('No posts yet. Be the first to post!'),
          );
        }

        return _PostsListView(
          posts: posts,
          onRefresh: _refreshPosts,
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// A widget that displays a list of posts with separators
class _PostsListView extends StatelessWidget {
  final List<PostDataModel> posts;
  final VoidCallback onRefresh;

  const _PostsListView({
    required this.posts,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      separatorBuilder: _buildSeparator,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) => PostItem(
        postData: posts[index],
        onPostDeleted: onRefresh,
      ),
    );
  }

  Widget _buildSeparator(BuildContext context, int index) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: 5),
      ],
    );
  }
}

/// A widget that displays a shimmer loading list
class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      separatorBuilder: (context, index) => Column(
        children: [
          const SizedBox(height: 10),
          Divider(
            color: Theme.of(context).dividerColor.withAlpha(50),
          ),
          const SizedBox(height: 5),
        ],
      ),
      itemCount: 5, // Show a few shimmer items
      itemBuilder: (_, __) => const PostShimmerItem(),
    );
  }
}

/// A widget that displays an error view with icon, message and retry button
class _ErrorView extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.icon,
    required this.message,
    required this.color,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            CustomText(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const CustomText('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
