import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../providers/auth_provider.dart';
import '../../config/themes.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../widgets/common/localized_text.dart';
import '../../utils/app_strings.dart';
import '../../services/music/spotify_service.dart';
import '../../services/api/django_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isSpotifyLoading = false;
  bool _isAppleLoading = false;
  bool _isSoundCloudLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final List<Color> _gradientColors = [
    const Color(0xFF121212),
    const Color(0xFF1E1E1E),
    const Color(0xFF0A0A0A),
  ];
  
  // Enhanced color animation for music visualizer with more vibrant colors
  final List<Color> _visualizerColors = [
    const Color(0xFFFF80AB).withOpacity(0.85), // Soft bubblegum pink (slightly less bright)
    const Color(0xFFBA68C8).withOpacity(0.85), // Light orchid purple
    const Color(0xFF80DEEA).withOpacity(0.85), // Soft aqua
    const Color(0xFFFF4081).withOpacity(0.85), // Vibrant neon pink
    const Color(0xFFA7BFFF).withOpacity(0.85), // Periwinkle blue
    const Color(0xFFF06292).withOpacity(0.85), // Muted rose-pink
    const Color(0xFFCE93D8).withOpacity(0.85), // Soft lavender
    const Color(0xFF00E5FF).withOpacity(0.85), // Neon cyan
    const Color(0xFFFF80AB).withOpacity(0.85), // Back to soft pink
  ];
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000), // Much longer duration for smoother animations
    )..repeat(reverse: false); // No reverse animation, just continuous flow
    
    _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate( // No fading, stay fully visible
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate( // No scaling, stay at full size
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSpotifySignIn(BuildContext context) async {
    setState(() => _isSpotifyLoading = true);
    
    try {
      // Get the auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Use Django backend for Spotify authentication
      final djangoAuthService = DjangoAuthService();
      
      // Show a loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting to Spotify...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      print('Starting Spotify authentication flow...');
      // Initiate authentication flow with Django backend
      final success = await djangoAuthService.authenticateWithSpotify();
      
      if (!success) {
        throw Exception('Authentication failed or was cancelled');
      }
      
      print('Spotify authentication successful, getting user profile...');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to Spotify'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Get user profile from backend
      final userProfile = await djangoAuthService.getUserProfile();
      
      if (userProfile == null) {
        throw Exception('Failed to retrieve user profile');
      }
      
      print('User profile retrieved: ${userProfile['username'] ?? 'Unknown user'}');
      
      // Update auth state with real user data if available, otherwise fall back to simulated login
      if (userProfile.containsKey('id') && userProfile.containsKey('username')) {
        print('Logging in with real user data from Spotify');
        await authProvider.simulateLogin(
          userId: userProfile['id'].toString(),
          name: userProfile['username'] ?? 'Spotify User',
          email: userProfile['email'] ?? 'spotify_user@example.com',
          profilePic: userProfile['profile_pic_url'],
          bio: userProfile['bio'] ?? 'Logged in with Spotify',
        );
      } else {
        // Fallback to mock login during development
        print('Using fallback mock login (no user data returned from backend)');
        await authProvider.simulateLogin(
          userId: 'spotify_user_123',
          name: 'Spotify User',
          email: 'spotify_user@example.com',
        );
      }
      
      if (!mounted) return;
      
      // Navigate to the map screen
      print('Navigating to map screen...');
      Navigator.of(context).pushReplacementNamed('/map');
    } catch (e) {
      if (!mounted) return;
      
      print('Spotify authentication error: $e');
      
      // Show error message in a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Spotify login failed: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
      
      // Also show the error dialog for more details
      _showSignInErrorDialog('Spotify', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSpotifyLoading = false);
      }
    }
  }

  Future<void> _handleAppleMusicSignIn(BuildContext context) async {
    setState(() => _isAppleLoading = true);
    
    try {
      // Simulate Apple Music sign-in
      await Future.delayed(const Duration(seconds: 1));
      
      // Navigate directly to the main screen for now
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/map');
    } finally {
      if (mounted) {
        setState(() => _isAppleLoading = false);
      }
    }
  }

  Future<void> _handleSoundCloudSignIn(BuildContext context) async {
    setState(() => _isSoundCloudLoading = true);
    
    try {
      // Simulate SoundCloud sign-in
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/map');
    } finally {
      if (mounted) {
        setState(() => _isSoundCloudLoading = false);
      }
    }
  }

  Future<void> _handleDemoMode(BuildContext context) async {
    setState(() => _isLoading = true);
    
    try {
      // Go straight to main screen during dev phase
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      // Navigate to the map screen directly in dev phase
      Navigator.of(context).pushReplacementNamed('/map');
    } catch (e) {
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to enter demo mode: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showSignInErrorDialog(String service, String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$service Sign-In Failed'),
        content: Text('Unable to sign in with $service: $errorMessage'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(),
          
          // Music Visualizer Effect - positioned behind the content
          _buildMusicVisualizer(),
          
          // Content with Animation
          SafeArea(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50), // Reduced top padding
                    
                    // Logo and App Name
                    _buildHeader(context),
                    
                    const SizedBox(height: 40),
                    
                    // Login Buttons - moved up
                    _buildLoginButtons(),
                    
                    const SizedBox(height: 24), // Spacing between login buttons and demo button
                    
                    // Demo mode button
                    _buildDemoButton(),
                    
                    const SizedBox(height: 16), // Added spacing between demo button and footer
                    
                    // Terms and privacy
                    _buildFooter(context),
                    
                    const Spacer(), // Push everything up, create space at the bottom
                    
                    const SizedBox(height: 30), // Add padding at the bottom to ensure content stays above music visualizer
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Animated gradient background
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _gradientColors,
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Subtle animated overlay
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1 + (0.05 * math.sin(_animationController.value * math.pi * 2)),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80',
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.5),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              
              // Blurred overlay
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Enhanced music visualizer-like effect with improved animation
  Widget _buildMusicVisualizer() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 100, // Reduced height to make sure it doesn't overlap with content
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Create multiple color transitions to ensure color mixing
            final primaryColorIndex = (_animationController.value * (_visualizerColors.length - 1) * 0.1).floor();
            final secondaryColorIndex = (primaryColorIndex + 2) % _visualizerColors.length;
            final tertiaryColorIndex = (primaryColorIndex + 4) % _visualizerColors.length;
            
            final primaryColorPercent = (_animationController.value * (_visualizerColors.length - 1) * 0.1) - primaryColorIndex;
            
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                48, // More bars for more visual impact
                (index) {
                  // Create randomized but smooth-looking bars with varied animations
                  final double height = 5 + 
                    65 * math.sin(
                      (_animationController.value * math.pi * 1.3) + // Smoother wave pattern
                      (index * 0.13) + // Spacing between waves
                      (math.sin(index * 0.3) * 0.4) // More variation
                    ).abs();
                  
                  // Make some bars taller than others for visual interest
                  final multiplier = 1.0 + ((index % 4) * 0.18); // More distinct height variation
                  
                  // Group bars by sections to create visible color clusters
                  int colorGroup = (index ~/ 4) % 3; // Create groups of 4 bars each cycling through 3 color groups
                  Color baseColor;
                  
                  if (colorGroup == 0) {
                    // First color group - main transition color
                    final nextPrimaryIndex = (primaryColorIndex + 1) % _visualizerColors.length;
                    baseColor = Color.lerp(
                      _visualizerColors[primaryColorIndex],
                      _visualizerColors[nextPrimaryIndex],
                      primaryColorPercent,
                    )!;
                  } else if (colorGroup == 1) {
                    // Second color group - secondary color
                    final nextSecondaryIndex = (secondaryColorIndex + 1) % _visualizerColors.length;
                    baseColor = Color.lerp(
                      _visualizerColors[secondaryColorIndex],
                      _visualizerColors[nextSecondaryIndex],
                      primaryColorPercent,
                    )!;
                  } else {
                    // Third color group - tertiary color
                    final nextTertiaryIndex = (tertiaryColorIndex + 1) % _visualizerColors.length;
                    baseColor = Color.lerp(
                      _visualizerColors[tertiaryColorIndex],
                      _visualizerColors[nextTertiaryIndex],
                      primaryColorPercent,
                    )!;
                  }
                  
                  // Add slight variation within groups
                  final withinGroupVariation = (index % 4) * 0.06;
                  final finalOpacity = 0.5 + (height / 130) * 0.4; // Less bright at shorter heights
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 2.6,
                    height: height * multiplier,
                    decoration: BoxDecoration(
                      // Use interpolated color with balanced opacity
                      color: baseColor.withOpacity(finalOpacity),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: baseColor.withOpacity(0.4), // Reduced glow intensity
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
  
  // Build app logo and name with enhanced design
  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // More creative logo design combining music and map concepts
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow circle
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF80AB).withOpacity(0.6), // Pink glow matching main circle
                    const Color(0xFFFF80AB).withOpacity(0.0),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            
            // Subtle pulsating outer ring
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final scale = 1.0 + (math.sin(_animationController.value * math.pi) * 0.05);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF80AB).withOpacity(0.3), // Pink outline
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Main circle with improved gradient and contrast
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withOpacity(0.8), // Black center
                    Colors.black.withOpacity(0.9), // Black outer
                  ],
                  stops: const [0.3, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF80AB).withOpacity(0.6), // Pink glow
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3), // Adding black shadow for contrast
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFFF80AB), // Pink border
                  width: 3,
                ),
              ),
            ),
            
            // Map pin element with improved design - now with black background
            Positioned(
              top: 12,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black, // Changed to black for consistency
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFF80AB).withOpacity(0.6), // Pink border to match main circle
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFFFF80AB), // Matching pink for consistency
                  size: 24,
                ),
              ),
            ),
            
            // Music note (STATIC - not animated)
            Positioned(
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      Colors.white,
                      const Color(0xFFFF80AB).withOpacity(0.9), // Pink gradient on note
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds);
                },
                child: const Icon(
                  Icons.music_note,
                  size: 65,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Small sound wave arcs with animated effect (restored)
            ...List.generate(3, (index) {
              final size = 160.0 + (index * 20.0);
              return Positioned(
                bottom: -5 + (index * 2), // Overlapping waves
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final animValue = (_animationController.value + (index * 0.25)) % 1.0;
                    final opacity = math.sin(animValue * math.pi) * 0.4;
                    return Opacity(
                      opacity: opacity,
                      child: Container(
                        width: size * animValue,
                        height: size * animValue * 0.4, // Flatter arcs
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(size),
                            topRight: Radius.circular(size),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 24),
        
        // App name with solid white color for more professional look
        Stack(
          alignment: Alignment.center,
          children: [
            // Shadow for depth
            Text(
              'BOPMaps',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black.withOpacity(0.6),
                letterSpacing: 2,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            // Main text with solid white color
            const Text(
              'BOPMaps',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Tagline with subtle animation
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                math.sin(_animationController.value * math.pi * 2) * 2,
                0,
              ),
              child: Text(
                'Where Music Meets Location',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9), // More visible
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  // Build login buttons for streaming services
  Widget _buildLoginButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Spotify login button
        _buildServiceButton(
          text: 'Continue with Spotify',
          onPressed: () => _handleSpotifySignIn(context),
          gradient: const LinearGradient(
            colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          icon: 'assets/images/spotify_icon.png',
          fallbackIcon: Icons.music_note,
          isLoading: _isSpotifyLoading,
        ),
        const SizedBox(height: 16),
        
        // Apple Music login button
        _buildServiceButton(
          text: 'Continue with Apple Music',
          onPressed: () => _handleAppleMusicSignIn(context),
          gradient: const LinearGradient(
            colors: [Colors.white, Colors.white],
          ),
          icon: 'assets/images/apple_music_icon.png',
          fallbackIcon: Icons.apple,
          textColor: Colors.black,
          isLoading: _isAppleLoading,
        ),
        const SizedBox(height: 16),
        
        // SoundCloud login button
        _buildServiceButton(
          text: 'Continue with SoundCloud',
          onPressed: () => _handleSoundCloudSignIn(context),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7700), Color(0xFFFF5500)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          icon: 'assets/images/soundcloud_icon.png',
          fallbackIcon: Icons.cloud,
          isLoading: _isSoundCloudLoading,
        ),
      ],
    );
  }
  
  // Build a service login button with gradient background - improved styling
  Widget _buildServiceButton({
    required String text,
    required VoidCallback onPressed,
    required LinearGradient gradient,
    required String icon,
    required IconData fallbackIcon,
    Color textColor = Colors.white,
    bool isLoading = false,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Icon (showing directly without background overlay)
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Center(
                    child: Icon(fallbackIcon, color: textColor, size: 24),
                    // In a real app with assets, you'd use:
                    // Image.asset(icon, width: 24, height: 24)
                  ),
                ),
                const SizedBox(width: 16),
                
                // Text
                Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                
                const Spacer(),
                
                // Loading indicator or arrow
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: textColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Build a demo mode button - improved styling
  Widget _buildDemoButton() {
    return Container(
      width: 200, // Set a specific width for better centering
      margin: const EdgeInsets.symmetric(vertical: 10), // Improved vertical spacing
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withOpacity(0.2), // Added slight background for better visibility
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoading ? null : () => _handleDemoMode(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center, // Center the content
              children: [
                Icon(
                  Icons.remove_red_eye,
                  size: 18,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Try Demo Mode',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Build footer with terms and privacy links - improved styling
  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), // Reduced padding
      child: Column(
        children: [
          Text(
            'By continuing, you agree to our',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  // Navigate to terms screen
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                'and',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to privacy policy screen
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 