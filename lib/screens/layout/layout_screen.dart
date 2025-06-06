import 'package:facebook_clone/models/user_model.dart';
import 'package:facebook_clone/screens/menu/menu_screen.dart';
import 'package:facebook_clone/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';

import '../../services/auth_services/auth_service.dart';
import '../posts/posts_screen.dart';

/// A screen that manages the main layout of the app with a bottom navigation bar
/// implemented using TabBar and TabBarView.
class LayoutScreen extends StatelessWidget {
  /// The current authenticated user
  final User user;

  /// The authentication service instance
  final AuthService authService;

  /// Number of tabs in the bottom navigation
  static const int _tabCount = 4;

  /// Padding values for the main content
  static const EdgeInsets _contentPadding = EdgeInsets.symmetric(
    horizontal: 15.0,
    vertical: 10,
  );

  /// Icon size for tab icons
  static const double _tabIconSize = 35.0;

  const LayoutScreen({
    super.key,
    required this.user,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabCount,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: _contentPadding,
            child: Column(
              children: [
                const CustomAppbar(),
                _buildTabBar(),
                Expanded(
                  child: _buildTabBarView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the TabBar with navigation icons
  Widget _buildTabBar() {
    return const TabBar(
      tabs: [
        Tab(icon: Icon(Icons.home, size: _tabIconSize)),
        Tab(icon: Icon(Icons.ondemand_video, size: _tabIconSize)),
        Tab(icon: Icon(Icons.notifications, size: _tabIconSize)),
        Tab(icon: Icon(Icons.menu, size: _tabIconSize)),
      ],
      labelColor: Colors.blue,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Colors.blue,
      indicatorSize: TabBarIndicatorSize.tab,
    );
  }

  /// Builds the TabBarView with all the main screens
  Widget _buildTabBarView() {
    return TabBarView(
      children: [
        PostsScreen(user: user, authService: authService),
        const Center(child: Text('Reels Content')),
        const Center(child: Text('Notifications Content')),
        MenuScreen(user: user, authService: authService),
      ],
    );
  }
}
