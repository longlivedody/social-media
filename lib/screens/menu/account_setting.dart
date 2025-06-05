import 'dart:io';

import 'package:facebook_clone/widgets/custom_button.dart';
import 'package:facebook_clone/widgets/custom_icon_button.dart';
import 'package:facebook_clone/widgets/custom_text.dart';
import 'package:facebook_clone/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:facebook_clone/utils/image_picker_utils.dart';
import 'package:facebook_clone/utils/image_utils.dart';

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
    final user = await widget.authService.currentUser;
    if (user != null) {
      setState(() {
        _currentUser = user;
        _displayNameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
      });
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
      final File? imageFile =
          await ImagePickerUtils.pickAndProcessImage(context);
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
            radius: 50,
            backgroundColor: Colors.grey[300],
            backgroundImage: _newProfileImage != null
                ? FileImage(_newProfileImage!)
                : (_currentUser.photoURL?.isNotEmpty ?? false)
                    ? ImageUtils.getImageProvider(_currentUser.photoURL!)
                    : null,
            child: (_currentUser.photoURL?.isEmpty ?? true) &&
                    _newProfileImage == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
}
