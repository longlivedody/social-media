import 'package:facebook_clone/models/comments_model.dart';
import 'package:facebook_clone/models/post_data_model.dart';
import 'package:facebook_clone/services/auth_services/auth_service.dart'; // For AuthService
import 'package:facebook_clone/services/post_services/post_service.dart'; // Your PostService
import 'package:facebook_clone/utils/image_utils.dart';
import 'package:facebook_clone/widgets/custom_text.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import 'comments_modal_sheet.dart'; // Your comments modal
import 'update_post_screen.dart'; // Import the UpdatePostScreen

class PostItem extends StatefulWidget {
  final PostDataModel postData;

  const PostItem({super.key, required this.postData});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  final PostService _postService = PostService();
  firebase_auth.User? _currentUser;
  Stream<List<CommentModel>>? _commentsListStream;
  Stream<int>? _likesCountStream;
  Stream<bool>? _userLikeStatusStream;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (_currentUser == null) {
      debugPrint(
          "PostItem InitState: Current user is null. Functionality might be limited.");
    }

    if (widget.postData.documentId.isNotEmpty) {
      debugPrint(
          "PostItem InitState: Initializing for documentId: ${widget.postData.documentId}");
      _commentsListStream =
          _postService.getCommentsForPost(widget.postData.documentId);
      _likesCountStream =
          _postService.getLikesCountForPost(widget.postData.documentId);
      if (_currentUser != null) {
        _userLikeStatusStream = _postService.hasUserLikedPost(
          widget.postData.documentId,
          _currentUser!.uid,
        );
      }
    } else {
      debugPrint(
          "Error: PostItem received postData with empty documentId. Post ID (custom): ${widget.postData.postId}");
    }
  }

  void _showCommentsModal() {
    debugPrint(
        "_showCommentsModal called for post: ${widget.postData.documentId}");
    if (widget.postData.documentId.isEmpty) {
      debugPrint("Error: Post documentId is empty, cannot show comments.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Cannot load comments. Post information is missing.")),
      );
      return;
    }
    if (_currentUser == null) {
      debugPrint("Error: Current user is null, cannot add comment.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You need to be logged in to comment.")),
      );
      return;
    }

    showCommentsModal(
      context: context,
      postId: widget.postData.documentId,
      onCommentSent: (commentText) {
        debugPrint("onCommentSent triggered with text: $commentText");
        if (_currentUser != null) {
          _postService
              .addCommentToPost(
            postId: widget.postData.documentId,
            commentText: commentText,
            commentingUserId: _currentUser!.uid,
            commentingUserName: _currentUser!.displayName ?? "Anonymous",
            commentingUserProfileImageUrl: widget.postData.profileImageUrl,
          )
              .then((_) {
            debugPrint(
                'Comment added successfully for post ${widget.postData.documentId}!');
          }).catchError((error) {
            debugPrint(
                'Error adding comment for post ${widget.postData.documentId}: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed to add comment: $error")),
              );
            }
          });
        }
      },
    );
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDelete() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to delete posts')),
      );
      return;
    }

    final shouldDelete = await _showDeleteConfirmationDialog();
    if (shouldDelete != true) return;

    setState(() => _isDeleting = true);
    try {
      await _postService.deletePost(
        postId: widget.postData.documentId,
        userId: _currentUser!.uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _handleUpdate() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to update posts')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdatePostScreen(post: widget.postData),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final estimatedImageHeight = screenWidth * 0.8;
    final theme = Theme.of(context);

    if (widget.postData.documentId.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              "Error: Post data is incomplete. DocumentId is missing.",
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      );
    }

    if (_isDeleting) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Deleting post...',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostUserSection(
            postData: widget.postData,
            onDelete: _handleDelete,
            onUpdate: _handleUpdate,
          ),
          const SizedBox(height: 12),
          if (widget.postData.postText.isNotEmpty) ...[
            CustomText(
              widget.postData.postText,
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.postData.postImageUrl != null &&
              widget.postData.postImageUrl!.isNotEmpty) ...[
            _PostImage(
              imageUrl: widget.postData.postImageUrl!,
              height: estimatedImageHeight,
            ),
            const SizedBox(height: 12),
          ],
          InkWell(onTap: _showCommentsModal, child: _buildReactsSection()),
          _buildInteractionButtons(),
        ],
      ),
    );
  }

  Widget _buildReactsSection() {
    final theme = Theme.of(context);

    return StreamBuilder<List<CommentModel>>(
      stream: _commentsListStream,
      builder: (context, commentsSnapshot) {
        return StreamBuilder<int>(
          stream: _likesCountStream,
          builder: (context, likesSnapshot) {
            final likesCount = likesSnapshot.data ?? 0;
            final commentsCount = commentsSnapshot.data?.length ?? 0;

            // Show a container with divider if there are no likes and no comments
            if (likesCount == 0 && commentsCount == 0) {
              return Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  if (likesCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.thumb_up_alt_rounded,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        CustomText('$likesCount',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  const Spacer(),
                  if (commentsCount > 0)
                    CustomText(
                      '$commentsCount ${commentsCount == 1 ? 'Comment' : 'Comments'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (widget.postData.sharesCount > 0) ...[
                    const SizedBox(width: 16),
                    CustomText('${widget.postData.sharesCount} Shares',
                        style: theme.textTheme.bodySmall),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInteractionButtons() {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildLikeButton()),
          Expanded(child: _buildCommentButton()),
          Expanded(child: _buildShareButton()),
        ],
      ),
    );
  }

  Widget _buildLikeButton() {
    final theme = Theme.of(context);

    return StreamBuilder<bool>(
      stream: _userLikeStatusStream,
      builder: (context, snapshot) {
        final hasLiked = snapshot.data ?? false;

        final IconData iconData =
            hasLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined;
        // Use blue color when liked, same as comment button when not liked
        final Color iconColor =
            hasLiked ? Colors.blue : theme.colorScheme.onSurface.withAlpha(150);
        final Color textColor =
            hasLiked ? Colors.blue : theme.colorScheme.onSurface.withAlpha(150);

        return TextButton.icon(
          onPressed: _currentUser == null ? null : () => _handleLikeToggle(),
          icon: Icon(iconData, color: iconColor, size: 20),
          label: CustomText(
            'Like',
            style: theme.textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: hasLiked ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: hasLiked
                ? Colors.blue
                : theme.colorScheme.onSurface.withAlpha(150),
          ),
        );
      },
    );
  }

  Future<void> _handleLikeToggle() async {
    if (_currentUser == null) return;

    try {
      await _postService.toggleLike(
        postId: widget.postData.documentId,
        userId: _currentUser!.uid,
        username: _currentUser!.displayName ?? 'Anonymous',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: $e')),
        );
      }
    }
  }

  Widget _buildCommentButton() {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: _showCommentsModal,
      icon: Icon(Icons.chat_bubble_outline_rounded,
          color: theme.colorScheme.onSurface.withAlpha(150), size: 20),
      label: CustomText(
        'Comment',
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
      ),
    );
  }

  Widget _buildShareButton() {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: () {
        debugPrint(
            "Share button pressed for post: ${widget.postData.documentId}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Share feature not implemented yet.")),
        );
      },
      icon: Icon(Icons.share_outlined,
          color: theme.colorScheme.onSurface.withAlpha(150), size: 20),
      label: CustomText(
        'Share',
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
      ),
    );
  }
}

// --- Helper Widgets ---

class _PostUserSection extends StatefulWidget {
  final PostDataModel postData;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _PostUserSection({
    required this.postData,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_PostUserSection> createState() => _PostUserSectionState();
}

class _PostUserSectionState extends State<_PostUserSection> {
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService().currentUser;
    if (mounted) {
      setState(() => _currentUserUid = user?.uid);
    }
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '...';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 5) return 'now';
    if (difference.inSeconds < 60) return '${difference.inSeconds}s';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 365) return '${(difference.inDays / 7).floor()}w';
    return '${(difference.inDays / 365).floor()}y';
  }

  bool _isPostOwner(String? currentUserUid) {
    return currentUserUid != null &&
        currentUserUid.isNotEmpty &&
        widget.postData.userId.isNotEmpty &&
        currentUserUid == widget.postData.userId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = _isPostOwner(_currentUserUid);

    return Row(
      children: [
        _ProfileImage(imageUrl: widget.postData.profileImageUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomText(
                    widget.postData.username,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              CustomText(
                _getTimeAgo(widget.postData.postTime.toDate()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
        if (isOwner)
          _PostOptionsMenu(
            onDelete: widget.onDelete,
            onUpdate: widget.onUpdate,
          ),
      ],
    );
  }
}

class _ProfileImage extends StatelessWidget {
  final String? imageUrl;

  const _ProfileImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primaryContainer.withAlpha(100),
      backgroundImage: hasImage ? ImageUtils.getImageProvider(imageUrl!) : null,
      child: !hasImage
          ? Icon(Icons.person,
              size: 28, color: theme.colorScheme.onPrimaryContainer)
          : null,
    );
  }
}

class _PostImage extends StatelessWidget {
  final String imageUrl;
  final double height;

  const _PostImage({required this.imageUrl, required this.height});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image(
        image: ImageUtils.getImageProvider(imageUrl),
        width: double.infinity,
        fit: BoxFit.cover,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: height,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint("Error loading post image ($imageUrl): $error");
          return Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 40, color: theme.colorScheme.onErrorContainer),
                const SizedBox(height: 8),
                Text("Image failed to load",
                    style: TextStyle(color: theme.colorScheme.onErrorContainer))
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostOptionsMenu extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _PostOptionsMenu({required this.onDelete, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded,
          color: theme.colorScheme.onSurface.withAlpha(180)),
      tooltip: "Post options",
      onSelected: (value) {
        debugPrint("Post option selected: $value");
        if (value == 'update') {
          onUpdate();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'update',
          child: const Row(children: [
            Icon(Icons.edit_outlined),
            SizedBox(width: 8),
            Text('Edit Post')
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text('Delete Post',
                style: TextStyle(color: theme.colorScheme.error))
          ]),
        ),
      ],
    );
  }
}
