# 🎵 BOPMaps

BOPMaps is an immersive music sharing platform that allows users to drop music pins at physical locations, discover new songs in real-world contexts, and build social experiences around music and space.

## 🌐 Frontend Overview
**Version:** 1.0  
**Lead Devs:** Jah, Mason, Eric, Isaiah, Danny  
**Stack:** Flutter (Mobile UI) • Unity (3D Visualization) • Spotify/Apple/Soundcloud SDKs • Geolocation Services

---

## 🚀 Vision
BOPMaps merges **gamification**, **location-based discovery**, and **social listening** to create a unique musical geocaching experience. The app's frontend leverages Flutter's cross-platform capabilities with Unity's powerful 3D rendering to deliver an immersive, beautiful experience for music discovery.

---

## 🏗️ Technology Architecture

### Flutter + Unity Integration
BOPMaps uses a hybrid approach combining:

- **Flutter**: Primary application framework handling:
  - UI/UX and navigation
  - State management
  - API communication
  - User authentication
  - Social features
  - Music service integration

- **Unity**: 3D visualization engine handling:
  - Interactive 3D map rendering
  - Pin visualization and animation
  - Immersive "aura" effects
  - Visual gamification elements
  - Spatial audio experiences

The integration is facilitated through the [flutter_unity_widget](https://github.com/juicycleff/flutter-unity-view-widget) package, enabling seamless communication between Flutter and Unity components.

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
| | |    Unity Integration      | | |
| | |    (3D Map & Pins)        | | |
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
- **3D World Visualization**: Unity-powered interactive map with custom styling
- **Animated Music Pins**: Visual representation of pins with animations based on music genre and popularity
- **Aura Effects**: Proximity-based visual effects showing pin discovery radius
- **Spatial Audio**: Hear snippets of music when approaching pins

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
│   │   ├── location/
│   │   │   ├── location_service.dart
│   │   │   └── geofencing_service.dart
│   │   │
│   │   └── unity/
│   │       ├── unity_bridge.dart
│   │       └── map_controller.dart
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
│   │   │   ├── unity_map_widget.dart
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
│       ├── api_exceptions.dart
│       └── formatters.dart
│
├── unity/                    # Unity Project
│   ├── Assets/
│   │   ├── Scripts/
│   │   │   ├── MapController.cs
│   │   │   ├── PinBehavior.cs
│   │   │   ├── AuraEffect.cs
│   │   │   └── FlutterBridge.cs
│   │   │
│   │   ├── Prefabs/
│   │   │   ├── MusicPin.prefab
│   │   │   ├── MapTerrain.prefab
│   │   │   └── AuraEffect.prefab
│   │   │
│   │   ├── Materials/
│   │   │   ├── PinMaterials/
│   │   │   └── MapMaterials/
│   │   │
│   │   └── Scenes/
│   │       └── MainMap.unity
│   │
│   └── ProjectSettings/
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
- Flutter SDK (2.10.0 or later)
- Dart SDK (2.16.0 or later)
- Unity 2021.3 LTS or later
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

#### 3. Unity Setup
```bash
# Open Unity Hub and add the project from the unity/ directory
# Open the project and build for both Android and iOS
# Export to the appropriate locations in the Flutter project
```

#### 4. Environment Configuration
- Create a `.env` file from the example:
```bash
cp .env.example .env
# Edit .env with your API keys and endpoints
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

### Unity-Flutter Communication
Communication between Flutter and Unity uses message passing:

```dart
// Flutter side
class UnityMapController {
  final UnityWidgetController _unityWidgetController;
  
  UnityMapController(this._unityWidgetController);
  
  // Add a pin to the Unity map
  void addPin(Pin pin) {
    _unityWidgetController.postMessage(
      'MapController',
      'AddPin',
      jsonEncode(pin.toUnityJson()),
    );
  }
  
  // Set user location
  void updateUserLocation(double lat, double lng) {
    _unityWidgetController.postMessage(
      'MapController',
      'UpdateUserLocation',
      jsonEncode({
        'latitude': lat,
        'longitude': lng,
      }),
    );
  }
  
  // Handle messages from Unity
  void handleUnityMessage(dynamic message) {
    // Process message from Unity...
  }
}
```

```csharp
// Unity side (C#)
public class FlutterBridge : MonoBehaviour
{
    // Add a pin based on data from Flutter
    public void AddPin(string pinJson)
    {
        var pinData = JsonUtility.FromJson<PinData>(pinJson);
        // Create pin GameObject with data...
    }
    
    // Update user position
    public void UpdateUserLocation(string locationJson)
    {
        var locationData = JsonUtility.FromJson<LocationData>(locationJson);
        // Update user marker position...
    }
    
    // Send message to Flutter
    public void SendMessageToFlutter(string eventName, string data)
    {
        #if UNITY_ANDROID
        using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        {
            // Android-specific communication...
        }
        #elif UNITY_IOS
        // iOS-specific communication...
        #endif
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
- Unity-Flutter communication
- API communication

### Performance Testing
- Startup time
- Map rendering performance
- Memory usage under load

---

## 📱 Supported Platforms
- Android 8.0+ (API level 26+)
- iOS 12.0+
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

### Unity Integration Strategy
- Limited Unity context to map visualization only
- Communication through serialized messages
- Performance optimization through asset bundling

### Asset Management
- Aggressive caching for map assets
- Progressive loading for Unity scenes
- Offline-first approach for previously visited areas

---

## 📈 Roadmap

### Phase 1: MVP (Current)
- Basic map visualization with Unity
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
- AR pin visualization
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
- **Eric**: Unity Integration
- **Isaiah**: Design & UI/UX
- **Danny**: API Integration & State Management

---

## 📜 License
[MIT License](LICENSE)
