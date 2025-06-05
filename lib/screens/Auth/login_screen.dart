import 'package:facebook_clone/screens/Auth/signup_screen.dart';
import 'package:facebook_clone/screens/layout/layout_screen.dart';
import 'package:facebook_clone/services/auth_services/auth_service.dart';
import 'package:facebook_clone/widgets/custom_button.dart';
import 'package:facebook_clone/widgets/custom_text.dart';
import 'package:facebook_clone/widgets/custom_text_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  // Add this parameter
  final AuthService authService;

  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  bool obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    // Access authService from the widget instance
    final authService = widget.authService;

    // IMPORTANT: Get the user *after* successful sign-in
    // final user = authService.currentUser; // MOVE THIS LINE

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // Use the passed-in authService
      final user = await authService.signInWithEmailAndPassword(
        // Capture the returned user
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Check if sign-in was successful and a user object was returned
      if (mounted) {
        // Add mounted check before navigation
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LayoutScreen(
              user: user,
              authService: authService,
            ), // Pass the signed-in user
          ),
        );
      } else if (mounted) {
        // Handle case where signInWithEmailAndPassword returns null but no exception
        // This might not happen with your current AuthService setup if it always rethrows
        // or returns a user, but it's good practice.
        setState(() {
          _errorMessage = 'Login failed. Please try again.';
          _isLoading = false; // Ensure loading is stopped
        });
      }
      // If navigation occurs, _isLoading will be handled by the widget being disposed.
      // If not, it's handled in finally or the else block above.
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided for that user.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message =
              'Network error. Please check your connection and try again.';
          break;
        default:
          message = 'An unexpected error occurred. Please try again.';
      }
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
      }
      debugPrint(
        "Sign in failed with FirebaseAuthException: ${e.code} - ${e.message}",
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
      debugPrint("Sign in failed with general error: $e");
    } finally {
      if (mounted && _isLoading) {
        // Only set if still loading (i.e., navigation didn't happen)
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access authService from the widget instance for SignupScreen navigation
    final authService = widget.authService;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CustomText(
                      'Welcome Back!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      controller: _emailController,
                      labelText: 'Email',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                      controller: _passwordController,
                      labelText: 'Password',
                      obscureText: obscureText,
                      prefixIcon: Icons.lock_outline,
                      keyboardType: TextInputType.visiblePassword,
                      suffixIcon: obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      onSuffixIconTap: () {
                        setState(() {
                          obscureText = !obscureText;
                        });
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _signIn(),
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : CustomButton(onPressed: _signIn, text: 'Login'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) {
                                    // Pass the authService instance here
                                    return SignupScreen(
                                      authService: authService,
                                    );
                                  },
                                ),
                              );
                              debugPrint('Navigate to Sign Up');
                            },
                      child: const Text('Don\'t have an account? Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
