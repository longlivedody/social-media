import 'package:facebook_clone/models/comments_model.dart';
import 'package:facebook_clone/models/user_model.dart';
import 'package:facebook_clone/screens/posts/likes_screen.dart';
import 'package:facebook_clone/services/auth_services/auth_service.dart';
import 'package:facebook_clone/services/post_services/post_service.dart';
import 'package:facebook_clone/utils/image_utils.dart';
import 'package:facebook_clone/widgets/custom_text.dart';
import 'package:facebook_clone/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

/// Shows a modal bottom sheet containing comments for a specific post
void showCommentsModal({
  required BuildContext context,
  required String postId,
  required Function(String) onCommentSent,
}) {
  final TextEditingController controller = TextEditingController();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    builder: (BuildContext modalContext) {
      return CommentsModalContent(
        postId: postId,
        controller: controller,
        onCommentSent: onCommentSent,
      );
    },
  );
}

/// The main content widget for the comments modal
class CommentsModalContent extends StatefulWidget {
  final String postId;
  final TextEditingController controller;
  final Function(String) onCommentSent;

  const CommentsModalContent({
    super.key,
    required this.postId,
    required this.controller,
    required this.onCommentSent,
  });

  @override
  State<CommentsModalContent> createState() => _CommentsModalContentState();
}

class _CommentsModalContentState extends State<CommentsModalContent> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.only(top: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DragHandle(),
                const Divider(),
                _PostStats(postId: widget.postId),
                const Divider(),
                Expanded(
                  child: _CommentsList(
                    postId: widget.postId,
                    scrollController: scrollController,
                  ),
                ),
                _CommentInputField(
                  controller: widget.controller,
                  onCommentSent: widget.onCommentSent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A visual handle for dragging the modal sheet
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 100,
        height: 5,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

/// Displays a list of comments for the post
class _CommentsList extends StatelessWidget {
  final String postId;
  final ScrollController scrollController;
  final PostService _postService = PostService();

  _CommentsList({
    required this.postId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommentModel>>(
      stream: _postService.getCommentsForPost(postId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: _ErrorText('Error loading comments'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data!;

        if (comments.isEmpty) {
          return const Center(
            child: CustomText(
              'No comments yet. Be the first to comment!',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          separatorBuilder: (_, __) => const Divider(),
          controller: scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: 10.0,
            vertical: 5.0,
          ),
          itemCount: comments.length,
          itemBuilder: (context, index) => _CommentItem(
            comment: comments[index],
            postId: postId,
          ),
        );
      },
    );
  }
}

/// Individual comment item widget
class _CommentItem extends StatefulWidget {
  final CommentModel comment;
  final String postId;

  const _CommentItem({
    required this.comment,
    required this.postId,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  bool isEditing = false;
  late TextEditingController _editController;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.commentText);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.currentUser;
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _handleEdit() async {
    if (_editController.text.trim().isEmpty) return;

    try {
      await _postService.updateComment(
        postId: widget.postId,
        commentId: widget.comment.commentId,
        newCommentText: _editController.text,
        userId: widget.comment.userId,
      );
      setState(() => isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    try {
      await _postService.deleteComment(
        postId: widget.postId,
        commentId: widget.comment.commentId,
        userId: widget.comment.userId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _UserAvatar(imageUrl: widget.comment.profileImageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  widget.comment.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _editController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _handleEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            isEditing = false;
                            _editController.text = widget.comment.commentText;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                else
                  CustomText(
                    widget.comment.commentText,
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(height: 4),
                CustomText(
                  _getTimeAgo(widget.comment.timestamp.toDate()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (widget.comment.userId == _currentUser?.uid)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  setState(() => isEditing = true);
                } else if (value == 'delete') {
                  _handleDelete();
                }
              },
            ),
        ],
      ),
    );
  }
}

/// User avatar widget
class _UserAvatar extends StatelessWidget {
  final String imageUrl;

  const _UserAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey[300],
      backgroundImage:
          imageUrl.isNotEmpty ? ImageUtils.getImageProvider(imageUrl) : null,
      child: imageUrl.isEmpty
          ? const Icon(
              Icons.person,
              size: 25,
              color: Colors.white,
            )
          : null,
    );
  }
}

/// Comment input field widget
class _CommentInputField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onCommentSent;

  const _CommentInputField({
    required this.controller,
    required this.onCommentSent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      child: CustomTextField(
        controller: controller,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          hintText: 'Add comment',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleCommentSubmission(),
          ),
        ),
        onFieldSubmitted: (_) => _handleCommentSubmission(),
      ),
    );
  }

  void _handleCommentSubmission() {
    if (controller.text.trim().isNotEmpty) {
      onCommentSent(controller.text.trim());
      controller.clear();
    }
  }
}

/// Error text widget
class _ErrorText extends StatelessWidget {
  final String message;

  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: CustomText(
        message,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

/// Returns a human-readable time ago string
String _getTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 365) {
    return '${(difference.inDays / 365).floor()}y';
  } else if (difference.inDays > 30) {
    return '${(difference.inDays / 30).floor()}mo';
  } else if (difference.inDays > 0) {
    return '${difference.inDays}d';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m';
  } else {
    return 'now';
  }
}

/// Widget to display post statistics (likes and comments count)
class _PostStats extends StatelessWidget {
  final String postId;
  final PostService _postService = PostService();

  _PostStats({required this.postId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LikesScreen(postId: postId),
                ),
              );
            },
            child: StreamBuilder<int>(
              stream: _postService.getLikesCountForPost(postId),
              builder: (context, snapshot) {
                final likesCount = snapshot.data ?? 0;
                return Row(
                  children: [
                    const Icon(Icons.thumb_up, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    CustomText(
                      '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 20,
                    )
                  ],
                );
              },
            ),
          ),
          Spacer(),
          StreamBuilder<List<CommentModel>>(
            stream: _postService.getCommentsForPost(postId),
            builder: (context, snapshot) {
              final commentsCount = snapshot.data?.length ?? 0;
              return Row(
                children: [
                  const Icon(Icons.comment, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  CustomText(
                    '$commentsCount ${commentsCount == 1 ? 'comment' : 'comments'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
