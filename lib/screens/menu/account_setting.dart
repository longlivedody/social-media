import 'dart:io';

import 'package:facebook_clone/widgets/custom_button.dart';
import 'package:facebook_clone/widgets/custom_icon_button.dart';
import 'package:facebook_clone/widgets/custom_text.dart';
import 'package:facebook_clone/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:facebook_clone/utils/image_picker_utils.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/user_model.dart';
import '../../services/auth_services/auth_service.dart';

class AccountSetting extends StatefulWidget {
  final User user;
  final AuthService authService;

  const AccountSetting({
    super.key,
    required this.user,
    required this.authService,
  });

  @override
  State<AccountSetting> createState() => _AccountSettingState();
}

class _AccountSettingState extends State<AccountSetting> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _obscureText = true;
  String? _errorMessage;
  File? _newProfileImage;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    try {
      final user = await widget.authService.currentUser;
      if (user != null) {
        setState(() {
          _currentUser = user;
          _displayNameController.text = user.displayName ?? '';
          _emailController.text = user.email ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _oldPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final File? imageFile = await ImagePickerUtils.pickImageFromGallery();
      if (imageFile != null) {
        setState(() {
          _newProfileImage = imageFile;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  bool _validateForm() {
    // Check if there are any changes
    final currentDisplayName = _currentUser.displayName ?? '';
    final hasDisplayNameChanged =
        _displayNameController.text != currentDisplayName;
    final hasPasswordChanged = _passwordController.text.isNotEmpty;
    final hasImageChanged = _newProfileImage != null;

    if (!hasDisplayNameChanged && !hasPasswordChanged && !hasImageChanged) {
      setState(() {
        _errorMessage = 'No changes to update';
      });
      return false;
    }

    if (hasPasswordChanged && _oldPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your old password';
      });
      return false;
    }

    return true;
  }

  Future<void> _updateProfile() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentDisplayName = _currentUser.displayName ?? '';
      final hasDisplayNameChanged =
          _displayNameController.text != currentDisplayName;
      final hasPasswordChanged = _passwordController.text.isNotEmpty;
      final hasImageChanged = _newProfileImage != null;

      if (hasDisplayNameChanged || hasImageChanged) {
        final updatedUser = await widget.authService.updateUserProfile(
          displayName:
              hasDisplayNameChanged ? _displayNameController.text : null,
          profileImage: hasImageChanged ? _newProfileImage : null,
        );
        setState(() {
          _currentUser = updatedUser;
        });
      }

      if (hasPasswordChanged) {
        await widget.authService.updatePassword(
          newPassword: _passwordController.text,
          oldPassword: _oldPasswordController.text,
        );
        _clearPasswordFields();
      }

      if (mounted) {
        String message = '';
        if (hasDisplayNameChanged && hasPasswordChanged && hasImageChanged) {
          message = 'Profile updated successfully!';
        } else if (hasDisplayNameChanged && hasPasswordChanged) {
          message = 'Display name and password updated successfully!';
        } else if (hasDisplayNameChanged && hasImageChanged) {
          message = 'Display name and profile image updated successfully!';
        } else if (hasPasswordChanged && hasImageChanged) {
          message = 'Password and profile image updated successfully!';
        } else if (hasDisplayNameChanged) {
          message = 'Display name updated successfully!';
        } else if (hasPasswordChanged) {
          message = 'Password updated successfully!';
        } else if (hasImageChanged) {
          message = 'Profile image updated successfully!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearPasswordFields() {
    _passwordController.clear();
    _oldPasswordController.clear();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CustomIconButton(
          onPressed: () => Navigator.of(context).pop(),
          iconData: Icons.arrow_back_ios_new,
        ),
        const SizedBox(width: 10),
        const CustomText(
          'Account Setting',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 120,
            backgroundImage: widget.user.photoURL != null
                ? NetworkImage(widget.user.photoURL!)
                : null,
            child: widget.user.photoURL == null
                ? Icon(Icons.person, size: 120, color: Colors.grey[400])
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: _pickProfileImage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayNameField() {
    return CustomTextField(
      controller: _displayNameController,
      labelText: 'Display Name',
      enabled: !_isLoading,
    );
  }

  Widget _buildEmailField() {
    return CustomTextField(
      prefixIcon: Icons.email,
      controller: _emailController,
      labelText: 'E-mail',
      enabled: false,
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText('Update Password'),
        const SizedBox(height: 15),
        CustomTextField(
          prefixIcon: Icons.lock,
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          controller: _oldPasswordController,
          labelText: 'Please enter your old password',
          enabled: !_isLoading,
        ),
        const SizedBox(height: 15),
        CustomTextField(
          prefixIcon: Icons.lock_reset,
          obscureText: _obscureText,
          keyboardType: TextInputType.visiblePassword,
          controller: _passwordController,
          labelText: 'New Password',
          enabled: !_isLoading,
          suffixIcon: _obscureText ? Icons.visibility : Icons.visibility_off,
          onSuffixIconTap: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      ],
    );
  }

  Widget _buildShimmerProfileImage() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: CircleAvatar(
        radius: 120,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildShimmerTextField() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  _buildHeader(),
                ],
              ),
              const SizedBox(height: 20),
              _buildShimmerProfileImage(),
              const SizedBox(height: 20),
              _buildShimmerTextField(),
              const SizedBox(height: 25),
              _buildShimmerTextField(),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 120,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildShimmerTextField(),
                  const SizedBox(height: 15),
                  _buildShimmerTextField(),
                ],
              ),
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: CustomButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  text: _isLoading ? 'Updating...' : 'Update',
                  style: const ButtonStyle(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ElevatedButton(
        onPressed: _updateProfile,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Updating...'),
                ],
              )
            : const Text('Update'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return _buildShimmerLoading();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildProfileImage(),
              const SizedBox(height: 20),
              _buildDisplayNameField(),
              const SizedBox(height: 25),
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildPasswordFields(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 25),
              _buildUpdateButton(),
            ],
          ),
        ),
      ),
    );
  }
}
