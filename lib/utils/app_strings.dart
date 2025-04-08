/// Centralized string management for the app.
/// All user-facing strings should be defined here to support easier localization in the future.
class AppStrings {
  // App Name
  static const String appName = 'BOPMaps';
  
  // Auth Screens
  static const String login = 'Login';
  static const String register = 'Register';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String loginWithGoogle = 'Login with Google';
  static const String dontHaveAccount = 'Don\'t have an account?';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String signUp = 'Sign Up';
  
  // Map Screen
  static const String map = 'Map';
  static const String dropPin = 'Drop a Pin';
  static const String pinDetails = 'Pin Details';
  static const String noPinsFound = 'No pins found nearby';
  static const String beFirstToDropPin = 'Be the first to drop a pin in this area!';
  static const String pinDropped = 'Music pin dropped! 🎵';
  static const String pinDropFailed = 'Failed to drop pin. Please try again.';
  static const String collectPin = 'Collect';
  static const String sharePin = 'Share';
  static const String reportPin = 'Report';
  static const String privatePin = 'Private';
  static const String publicPin = 'Public';
  
  // Music
  static const String selectTrack = 'Select a Track';
  static const String searchTrack = 'Search for a song...';
  static const String recentlyPlayed = 'Recently Played';
  static const String recommendedTracks = 'Recommended Tracks';
  static const String nowPlaying = 'Now Playing';
  static const String byArtist = 'by';
  
  // Friends
  static const String friends = 'Friends';
  static const String findFriends = 'Find Friends';
  static const String pendingRequests = 'Pending Requests';
  static const String accept = 'Accept';
  static const String reject = 'Reject';
  static const String noFriendsYet = 'No friends yet';
  static const String searchForFriends = 'Search for friends or invite them to BOPMaps';
  
  // Profile
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String pins = 'Pins';
  static const String collections = 'Collections';
  static const String settings = 'Settings';
  static const String logout = 'Logout';
  
  // Errors
  static const String errorOccurred = 'An error occurred';
  static const String networkError = 'Network error. Please check your connection and try again.';
  static const String invalidCredentials = 'Invalid credentials. Please try again.';
  static const String requiredField = 'This field is required';
  static const String retry = 'Retry';
  
  // Success Messages
  static const String success = 'Success';
  
  // Permissions
  static const String locationPermissionTitle = 'Location Permission Required';
  static const String locationPermissionMessage = 'BOPMaps needs access to your location to show nearby music pins.';
  static const String cameraPermissionTitle = 'Camera Permission Required';
  static const String cameraPermissionMessage = 'BOPMaps needs access to your camera to take profile photos.';
  
  // Misc
  static const String cancel = 'Cancel';
  static const String ok = 'OK';
  static const String loading = 'Loading...';
  static const String search = 'Search';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String areYouSure = 'Are you sure?';
} 