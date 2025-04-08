import 'package:flutter/material.dart';

// Auth screens
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';

// Map screens
import '../screens/map/map_screen.dart';
import '../screens/map/pin_details_screen.dart';

// Music screens
import '../screens/music/track_select_screen.dart';
import '../screens/music/player_screen.dart';

// Profile screens
import '../screens/profile/profile_screen.dart';
import '../screens/profile/settings_screen.dart';

// Social screens
import '../screens/social/friends_screen.dart';
import '../screens/social/activity_feed_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth routes
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      
      // Map routes
      case '/map':
        return MaterialPageRoute(builder: (_) => const MapScreen());
      case '/pin_details':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PinDetailsScreen(pin: args['pin']),
        );
      
      // Music routes
      case '/track_select':
        return MaterialPageRoute(builder: (_) => const TrackSelectScreen());
      case '/player':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PlayerScreen(track: args['track']),
        );
      
      // Profile routes
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      
      // Social routes
      case '/friends':
        return MaterialPageRoute(builder: (_) => const FriendsScreen());
      case '/activity':
        return MaterialPageRoute(builder: (_) => const ActivityFeedScreen());
      
      // Default route (404)
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text(
                '404 - Page not found\nRoute: ${settings.name}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
    }
  }
} 