import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart'; // Commented out for now
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Config imports
import 'config/themes.dart';
import 'config/routes.dart';

// Provider imports
import 'providers/auth_provider.dart';
import 'providers/pin_provider.dart';
import 'providers/map_provider.dart';
import 'providers/music_provider.dart';

// Screen imports
import 'screens/auth/login_screen.dart';
import 'screens/map/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables - make it resilient to missing .env file
  try {
    await dotenv.load(fileName: ".env");
    print("Environment variables loaded successfully");
  } catch (e) {
    print("Warning: No .env file found or failed to load environment variables: $e");
    // Continue execution without the .env file
  }
  
  // Initialize Firebase - Temporarily disabled
  // await Firebase.initializeApp();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PinProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => MusicProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'BOPMaps',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            initialRoute: authProvider.isAuthenticated ? '/map' : '/login',
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: authProvider.isAuthenticated ? const MapScreen() : const LoginScreen(),
          );
        },
      ),
    );
  }
} 