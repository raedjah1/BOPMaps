# 🎵 BOPMaps

BOPMaps is an immersive music sharing platform that allows users to drop music pins at physical locations, discover new songs in real-world contexts, and build social experiences around music and space.

## 🌐 Frontend Overview
**Version:** 1.0  
**Lead Devs:** Jah, Mason, Eric, Isaiah, Danny  
**Stack:** Flutter (Mobile UI) • Mapbox/flutter_map • Spotify/Apple/Soundcloud SDKs • Geolocation Services

---

## 🚀 Vision
BOPMaps merges **gamification**, **location-based discovery**, and **social listening** to create a unique musical geocaching experience. The app leverages Flutter's powerful rendering capabilities and animation system to deliver an immersive, beautiful experience for music discovery.

---

## 🏗️ Technology Architecture

### Flutter-Powered UI & Visualization
BOPMaps uses a streamlined approach with Flutter handling all aspects of the application:

- **UI/UX and Navigation**
  - Clean, intuitive interface optimized for music discovery
  - Smooth transitions and animations between screens
  - Responsive design for all device sizes

- **Map Visualization**
  - Interactive 3D-like maps using Mapbox GL or flutter_map
  - Custom pin styling and animations
  - Visual "aura" effects using Flutter's powerful animation system
  - Dynamic camera controls for immersive exploration

- **Core Functionality**
  - State management (Provider/Bloc)
  - API communication with backend
  - User authentication
  - Music service integration
  - Location services and geofencing

By using Flutter exclusively, we gain:
- Simplified development workflow
- Better performance on mobile devices
- Easier maintenance and updates
- Consistent experience across platforms

### System Architecture Diagram

```
+-----------------------------------+
|            BOPMaps App            |
|                                   |
| +-------------------------------+ |
| |                               | |
| |       Flutter Framework       | |
| |                               | |
| | +---------------------------+ | |
| | |                           | | |
| | |    Map Visualization      | | |
| | |    (Mapbox GL/flutter_map)| | |
| | |                           | | |
| | +---------------------------+ | |
| |                               | |
| | +---------------------------+ | |
| | |                           | | |
| | |    UI Components          | | |
| | |    (Screens, Navigation)  | | |
| | |                           | | |
| | +---------------------------+ | |
| |                               | |
| | +---------------------------+ | |
| | |                           | | |
| | |    State Management       | | |
| | |    (Provider/Bloc)        | | |
| | |                           | | |
| | +---------------------------+ | |
| |                               | |
| | +---------------------------+ | |
| | |                           | | |
| | |    API Services           | | |
| | |    (REST Client)          | | |
| | |                           | | |
| | +---------------------------+ | |
| |                               | |
| +-------------------------------+ |
|                                   |
| +-------------------------------+ |
| |                               | |
| |       External Services       | |
| |                               | |
| | +---------------------------+ | |
| | |                           | | |
| | |    Music Streaming APIs   | | |
| | |    (Spotify, Apple Music) | | |
| | |                           | | |
| | +---------------------------+ | |
| |                               | |
| | +---------------------------+ | |
| | |                           | | |
| | |    Location Services      | | |
| | |    (GPS, Geofencing)      | | |
| | |                           | | |
| | +---------------------------+ | |
| |                               | |
| | +---------------------------+ | |
| | |                           | | |
| | |    Push Notifications     | | |
| | |    (Firebase)             | | |
| | |                           | | |
| | +---------------------------+ | |
| |                               | |
| +-------------------------------+ |
|                                   |
+-----------------------------------+
```

---

## 🧩 Key Features & Implementation

### 🗺️ Immersive Map Experience
- **3D-Like Map Visualization**: Tilted camera perspective with Mapbox GL
- **Animated Music Pins**: Visual representation of pins with bouncing animations and glow effects based on music genre and popularity
- **Aura Effects**: Proximity-based visual effects using radial gradients and animated containers
- **Spatial Audio Experience**: Fade in/out audio playback based on proximity to pins

### 👤 User Experience
- **Intuitive UI**: Clean, music-focused design language
- **Seamless Authentication**: Easy login with email or social
- **Profile Customization**: User avatars, bio, and music preferences
- **Cross-Platform**: Consistent experience on iOS and Android

### 🎵 Music Integration
- **Multi-Service Support**: Connect with Spotify, Apple Music, and SoundCloud
- **Real-Time Playback**: Stream discovered music directly in-app
- **Music Selection**: Easy interface for selecting tracks to pin
- **Artist Discovery**: Artist profiles and related music

### 🌐 Location Features
- **High-Precision Geolocation**: Accurate pin placement and discovery
- **Background Location**: Optional background tracking for pin discovery
- **Offline Capabilities**: Cache of previously discovered pins
- **Geofencing**: Notifications when entering pin auras

### 🏆 Gamification
- **Pin Collection**: Visual inventory of discovered music
- **Achievements**: Unlock badges and rewards for app activity
- **Leaderboards**: Compare collection stats with friends
- **Custom Pin Skins**: Visual customization options for dropped pins

### 👫 Social Features
- **Friend System**: Connect and follow other music enthusiasts
- **Activity Feed**: See friends' music drops and discoveries
- **Sharing**: Share discoveries via social media or direct messages
- **Communities**: Join location-based music communities

---

## 📁 Project Structure

```
bopmaps_frontend/
│
├── android/                  # Android native code
│
├── ios/                      # iOS native code
│
├── lib/
│   ├── main.dart             # App entry point
│   │
│   ├── config/               # App configuration
│   │   ├── routes.dart       # Navigation routes
│   │   ├── themes.dart       # App themes
│   │   └── constants.dart    # App constants
│   │
│   ├── models/               # Data models
│   │   ├── user.dart
│   │   ├── pin.dart
│   │   ├── friend.dart
│   │   └── music_track.dart
│   │
│   ├── services/             # API and service integration
│   │   ├── api/
│   │   │   ├── api_client.dart
│   │   │   ├── auth_api.dart
│   │   │   ├── pins_api.dart
│   │   │   └── friends_api.dart
│   │   │
│   │   ├── music/
│   │   │   ├── spotify_service.dart
│   │   │   ├── apple_music_service.dart
│   │   │   └── soundcloud_service.dart
│   │   │
│   │   └── location/
│   │       ├── location_service.dart
│   │       └── geofencing_service.dart
│   │
│   ├── providers/            # State management
│   │   ├── auth_provider.dart
│   │   ├── pin_provider.dart
│   │   ├── map_provider.dart
│   │   └── music_provider.dart
│   │
│   ├── screens/              # UI screens
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   │
│   │   ├── map/
│   │   │   ├── map_screen.dart
│   │   │   └── pin_details_screen.dart
│   │   │
│   │   ├── profile/
│   │   │   ├── profile_screen.dart
│   │   │   └── settings_screen.dart
│   │   │
│   │   ├── social/
│   │   │   ├── friends_screen.dart
│   │   │   └── activity_feed_screen.dart
│   │   │
│   │   └── music/
│   │       ├── track_select_screen.dart
│   │       └── player_screen.dart
│   │
│   ├── widgets/              # Reusable UI components
│   │   ├── common/
│   │   │   ├── app_bar.dart
│   │   │   ├── loading_indicator.dart
│   │   │   └── custom_button.dart
│   │   │
│   │   ├── map/
│   │   │   ├── map_widget.dart
│   │   │   ├── pin_widget.dart
│   │   │   ├── aura_effect_widget.dart
│   │   │   └── pin_card.dart
│   │   │
│   │   ├── music/
│   │   │   ├── track_list_item.dart
│   │   │   └── mini_player.dart
│   │   │
│   │   └── social/
│   │       ├── friend_list_item.dart
│   │       └── activity_item.dart
│   │
│   └── utils/                # Utility functions
│       ├── location_utils.dart
│       ├── animation_utils.dart
│       ├── api_exceptions.dart
│       └── formatters.dart
│
├── assets/                   # Static resources
│   ├── images/
│   │   ├── pin_skins/
│   │   └── icons/
│   │
│   ├── animations/           # Lottie animations
│   │
│   └── audio/                # Audio effects
│
├── test/                     # Flutter tests
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── pubspec.yaml              # Flutter dependencies
├── README.md                 # This file
└── .gitignore                # Git ignore file
```

---

## 🛠️ Setup & Development

### Prerequisites
- Flutter SDK (3.0.0 or later)
- Dart SDK (2.17.0 or later)
- Android Studio / XCode
- Git

### First-Time Setup

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/BOPMapsFrontend.git
cd BOPMapsFrontend
```

#### 2. Flutter Setup
```bash
# Install dependencies
flutter pub get

# Set up code generation (if used)
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 3. Environment Configuration
- Create a `.env` file from the example:
```bash
cp .env.example .env
# Edit .env with your API keys and endpoints
```

### Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  # State management
  provider: ^6.0.3
  flutter_bloc: ^8.0.1
  
  # UI components
  flutter_map: ^4.0.0        # For OpenStreetMap style maps
  mapbox_gl: ^0.16.0         # For Mapbox 3D-like maps
  
  # Location services
  geolocator: ^9.0.0
  geofencing: ^2.0.0
  
  # Music services
  spotify_sdk: ^2.3.0
  audio_service: ^0.18.7
  
  # Networking
  dio: ^5.0.0
  retrofit: ^4.0.1
  
  # Animation
  lottie: ^2.3.0
  
  # Storage
  hive: ^2.2.3
  flutter_secure_storage: ^8.0.0
  
  # Other utilities
  intl: ^0.18.0
  firebase_messaging: ^14.2.5
  firebase_core: ^2.7.0
```

### Running the App
```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

### Building for Production
```bash
# Android
flutter build apk --release
# or
flutter build appbundle --release

# iOS
flutter build ios --release
# Then archive through XCode
```

---

## 🔄 Integration with Backend

BOPMaps frontend communicates with the Django backend through a RESTful API:

### Authentication Flow
- JWT token-based authentication 
- Secure token storage using Flutter Secure Storage
- Automatic token refresh mechanism

### API Service Structure
The API services are organized to match backend endpoints:

```dart
// Example API service for Music Pins
class PinsApiService {
  final ApiClient _apiClient;
  
  PinsApiService(this._apiClient);
  
  // Get nearby pins based on user location
  Future<List<Pin>> getNearbyPins(double lat, double lng, double radius) async {
    final response = await _apiClient.get(
      '/api/pins/',
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
      },
    );
    
    return (response.data as List)
        .map((json) => Pin.fromJson(json))
        .toList();
  }
  
  // Create a new pin
  Future<Pin> createPin(Pin pin) async {
    final response = await _apiClient.post(
      '/api/pins/',
      data: pin.toJson(),
    );
    
    return Pin.fromJson(response.data);
  }
  
  // Other pin-related API methods...
}
```

---

## 🎨 Key UI Components Implementation

### Main Map Screen
```dart
class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMapController? _mapController;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map layer
          MapboxMap(
            accessToken: MAPBOX_ACCESS_TOKEN,
            initialCameraPosition: CameraPosition(
              target: LatLng(37.7749, -122.4194), // Starting position
              zoom: 15.0,
              pitch: 45.0, // Tilted camera for 3D-like effect
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          
          // Aura effect around user (when close to pins)
          Consumer<LocationProvider>(
            builder: (context, locationProvider, child) {
              return AuraEffectWidget(
                radius: locationProvider.auraRadius,
                position: locationProvider.userScreenPosition,
              );
            },
          ),
          
          // Pins layer
          Consumer<PinsProvider>(
            builder: (context, pinsProvider, child) {
              return Stack(
                children: pinsProvider.nearbyPins.map((pin) => 
                  Positioned(
                    left: pin.screenX,
                    top: pin.screenY,
                    child: MusicPinWidget(
                      pin: pin,
                      onTap: () => _showPinDetails(pin),
                    ),
                  )
                ).toList(),
              );
            },
          ),
          
          // Top navigation buttons
          Positioned(
            top: 50,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "profile",
                  child: Icon(Icons.person),
                  onPressed: () => Navigator.pushNamed(context, '/profile'),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "store",
                  child: Icon(Icons.shopping_cart),
                  onPressed: () => Navigator.pushNamed(context, '/store'),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Bottom navigation
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.explore),
              onPressed: () {
                // Already on map screen
              },
            ),
            SizedBox(width: 48), // Space for FAB
            IconButton(
              icon: Icon(Icons.people),
              onPressed: () => Navigator.pushNamed(context, '/friends'),
            ),
          ],
        ),
      ),
      
      // Floating action button for dropping pins
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add_location),
        onPressed: () => _showDropPinScreen(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
  
  void _showPinDetails(Pin pin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PinDetailsSheet(pin: pin),
    );
  }
  
  void _showDropPinScreen() {
    Navigator.pushNamed(context, '/drop_pin');
  }
}
```

### Aura Effect Widget
```dart
class AuraEffectWidget extends StatelessWidget {
  final double radius;
  final Point position;
  
  const AuraEffectWidget({
    Key? key,
    required this.radius,
    required this.position,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.x - radius,
      top: position.y - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.5),
              Theme.of(context).primaryColor.withOpacity(0.0)
            ],
            stops: [0.2, 1.0],
          ),
        ),
      ),
    );
  }
}
```

### Music Pin Widget
```dart
class MusicPinWidget extends StatefulWidget {
  final Pin pin;
  final VoidCallback onTap;
  
  const MusicPinWidget({
    Key? key,
    required this.pin,
    required this.onTap,
  }) : super(key: key);
  
  @override
  _MusicPinWidgetState createState() => _MusicPinWidgetState();
}

class _MusicPinWidgetState extends State<MusicPinWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup bounce animation
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_bounceAnimation.value),
            child: child,
          );
        },
        child: Container(
          width: getPinSizeForRarity(widget.pin.rarity),
          height: getPinSizeForRarity(widget.pin.rarity),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: getPinColorForRarity(widget.pin.rarity).withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/pin_skins/${widget.pin.skin}.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
  
  double getPinSizeForRarity(String rarity) {
    switch (rarity) {
      case 'common': return 60;
      case 'uncommon': return 70;
      case 'rare': return 80;
      case 'epic': return 90;
      case 'legendary': return 100;
      default: return 60;
    }
  }
  
  Color getPinColorForRarity(String rarity) {
    switch (rarity) {
      case 'common': return Colors.grey;
      case 'uncommon': return Colors.green;
      case 'rare': return Colors.blue;
      case 'epic': return Colors.purple;
      case 'legendary': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
```

---

## 📝 Development Workflow

### Code Style & Linting
- Strictly follow [Flutter style guide](https://flutter.dev/docs/development/tools/formatting)
- Run `flutter analyze` before each commit

### Git Flow
- `main` branch: Production-ready code
- `develop` branch: Integration branch
- Feature branches: `feature/feature-name`
- Bugfix branches: `bugfix/bug-name`

### Pull Request Process
1. Create branches from `develop`
2. Pass all tests and linting
3. Require at least one code review
4. Squash and merge to `develop`

### Testing
```bash
# Run unit tests
flutter test

# Run specific test file
flutter test test/services/pin_service_test.dart

# Run with coverage
flutter test --coverage
```

---

## 🧪 Testing Strategy

### Unit Tests
- Services and utility functions
- Model serialization/deserialization
- Provider state management

### Widget Tests
- UI components in isolation
- Screen widget interaction
- Navigation flows

### Integration Tests
- End-to-end user flows
- API communication
- Location-based features

### Performance Testing
- Startup time
- Map rendering performance
- Memory usage under load

---

## 📱 Supported Platforms
- Android 8.0+ (API level 26+)
- iOS 13.0+
- *Future expansion:* Web version with limited functionality

---

## 🧠 Architecture Decisions

### State Management
- **Provider** for simple state management
- **Bloc** for complex flows like authentication and map interaction

### API Communication
- **Dio** for HTTP requests
- **Retrofit** for API client generation
- Custom error handling middleware

### Map Visualization Strategy
- Mapbox GL for 3D-like tilted camera views
- Custom Flutter animations for pin and aura effects
- Canvas-based optimizations for handling many pins simultaneously

### Offline & Performance Optimizations
- Aggressive caching of map tiles
- Local storage of previously discovered pins
- Background location tracking with battery optimizations
- Lazy loading of distant pins

---

## 📈 Roadmap

### Phase 1: MVP (Current)
- Basic map visualization with pin placement
- Pin creation and discovery
- Spotify integration
- Friend connections
- Core gamification features

### Phase 2: Enhanced Experience
- Apple Music and SoundCloud integration
- Advanced pin customization
- Rich profile features
- Achievement system
- Performance optimizations

### Phase 3: Social Expansion
- Music communities
- Collaborative playlists
- Enhanced sharing capabilities
- AR pin visualization (using ARKit/ARCore)
- Cross-platform messaging

### Phase 4: Monetization
- Premium pin skins
- Extended discovery range
- Ad-free experience
- Enhanced analytics for artists

---

## 👥 Team & Contributions
- **Jah**: Project Lead & Architecture
- **Mason**: Flutter Development
- **Eric**: Map Visualization & Animations
- **Isaiah**: Design & UI/UX
- **Danny**: API Integration & State Management

---

## 📜 License
[MIT License](LICENSE)
