import 'dart:io';

import 'package:facebook_clone/services/auth_services/auth_service.dart';
import 'package:facebook_clone/services/post_services/post_service.dart';
import 'package:facebook_clone/utils/image_picker_utils.dart';
import 'package:facebook_clone/utils/video_picker_utils.dart';
import 'package:facebook_clone/utils/image_utils.dart';
import 'package:facebook_clone/widgets/custom_button.dart';
import 'package:facebook_clone/widgets/custom_icon_button.dart';
import 'package:facebook_clone/widgets/custom_text.dart';
import 'package:facebook_clone/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../consts/theme.dart';

/// A screen that allows users to create a new post with text and optional media.
class CreatePostScreen extends StatefulWidget {
  final PostService postService;
  final String? photoURL;

  const CreatePostScreen({
    super.key,
    required this.postService,
    this.photoURL,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _postController = TextEditingController();
  final _authService = AuthService();

  String? _postImageBase64;
  String? _videoUrl;
  File? _videoFile;
  VideoPlayerController? _videoController;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _postController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// Picks an image from the gallery and converts it to base64
  Future<void> _pickImage() async {
    try {
      final File? imageFile =
          await ImagePickerUtils.pickAndProcessImage(context);
      if (imageFile == null) return;

      final base64Image = ImagePickerUtils.getBase64Image(imageFile);
      setState(() {
        _postImageBase64 = base64Image;
        _videoUrl = null;
        _videoFile = null;
        _videoController?.dispose();
        _videoController = null;
        _errorMessage = null;
      });
    } catch (e) {
      _setError('Failed to pick image: $e');
    }
  }

  /// Picks a video from the gallery or camera
  Future<void> _pickVideo() async {
    try {
      final File? videoFile =
          await VideoPickerUtils.pickAndProcessVideo(context);
      if (videoFile == null) return;

      setState(() {
        _videoFile = videoFile;
        _videoUrl = videoFile.path;
        _postImageBase64 = null;
        _errorMessage = null;
      });

      // Initialize video controller for preview
      _videoController = VideoPlayerController.file(videoFile);
      await _videoController!.initialize();
      setState(() {});
    } catch (e) {
      _setError('Failed to pick video: $e');
    }
  }

  /// Creates a new post with the provided text and media
  Future<void> _createPost() async {
    if (!_validatePost()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = await _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      await widget.postService.createPost(
        postText: _postController.text.trim(),
        postImageUrl: _postImageBase64,
        videoUrl: _videoUrl,
        user: currentUser,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _setError('Failed to create post: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Validates the post content
  bool _validatePost() {
    if (_postController.text.trim().isEmpty &&
        _postImageBase64 == null &&
        _videoUrl == null) {
      _setError('Please add some text, an image, or a video to your post');
      return false;
    }
    return true;
  }

  void _setError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 70,
        leading: CustomIconButton(
          onPressed: () => Navigator.of(context).pop(),
          iconData: Icons.arrow_back_ios,
        ),
        title: const CustomText('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildPostButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPostInput(),
                const SizedBox(height: 20),
                if (_postImageBase64 != null) _buildImagePreview(),
                if (_videoUrl != null && _videoController != null)
                  _buildVideoPreview(),
                const SizedBox(height: 20),
                _buildActionButtons(),
                if (_errorMessage != null) _buildErrorMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 25,
        ),
      ),
      onPressed: _createPost,
      child: _isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            )
          : const Text(
              'POST',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildPostInput() {
    return CustomTextField(
      decoration: const InputDecoration(
        fillColor: Colors.transparent,
        enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
        border: OutlineInputBorder(borderSide: BorderSide.none),
        disabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide.none),
      ),
      controller: _postController,
      hintText: "What's on your mind?",
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter some text';
        }
        return null;
      },
    );
  }

  Widget _buildImagePreview() {
    final screenWidth = MediaQuery.of(context).size.width;
    final estimatedImageHeight = screenWidth * 1.1;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image(
            image: ImageUtils.getImageProvider(_postImageBase64!),
            height: estimatedImageHeight,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _postImageBase64 = null),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                _videoUrl = null;
                _videoFile = null;
                _videoController?.dispose();
                _videoController = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomButton(
          onPressed: _pickImage,
          text: 'Add Photo',
          icon: const Icon(Icons.photo_library),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            foregroundColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primary,
            ),
            side: WidgetStateProperty.all(
              BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            minimumSize: WidgetStateProperty.all(const Size(120, 40)),
          ),
        ),
        const SizedBox(width: 16),
        CustomButton(
          onPressed: _pickVideo,
          text: 'Add Video',
          icon: const Icon(Icons.videocam),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            foregroundColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primary,
            ),
            side: WidgetStateProperty.all(
              BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            minimumSize: WidgetStateProperty.all(const Size(120, 40)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        _errorMessage!,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
