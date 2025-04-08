import 'package:flutter/material.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String? albumArtUrl;
  final String previewUrl;
  
  Track({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArtUrl,
    required this.previewUrl,
  });
}

class MusicProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Track? _currentTrack;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // Search results
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  String? _errorMessage;
  
  // Getters
  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get duration => _duration;
  Duration get position => _position;
  List<Track> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;
  
  MusicProvider() {
    _initAudioPlayer();
  }
  
  void _initAudioPlayer() {
    // Listen to position changes
    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    
    // Listen to player state changes
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.playing != _isPlaying) {
        _isPlaying = state.playing;
      }
      
      if (state.processingState == ProcessingState.completed) {
        stop();
      }
      
      notifyListeners();
    });
    
    // Duration changes
    _audioPlayer.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }
  
  // Set the current track
  Future<void> setCurrentTrack(Track track) async {
    if (_currentTrack?.id == track.id && _isPlaying) {
      await pause();
      return;
    }
    
    _currentTrack = track;
    _isLoading = true;
    notifyListeners();
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(track.previewUrl);
      _duration = await _audioPlayer.duration ?? Duration.zero;
      await play();
    } catch (e) {
      _errorMessage = 'Error playing track: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Play the current track
  Future<void> play() async {
    if (_currentTrack == null) return;
    
    try {
      await _audioPlayer.play();
    } catch (e) {
      _errorMessage = 'Error playing track: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Pause the current track
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      _errorMessage = 'Error pausing track: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Stop the current track
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _position = Duration.zero;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error stopping track: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Seek to a specific position
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _errorMessage = 'Error seeking track: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Search for tracks
  Future<void> searchTracks(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      _searchQuery = '';
      notifyListeners();
      return;
    }
    
    _isSearching = true;
    _searchQuery = query;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // This is a placeholder until we implement the actual API call
      // In a real app, you would call an API service to search for tracks
      await Future.delayed(const Duration(seconds: 1));
      
      // Sample mock data
      _searchResults = [
        Track(
          id: '1',
          title: 'Sample Track 1',
          artist: 'Artist 1',
          albumArtUrl: 'https://via.placeholder.com/300',
          previewUrl: 'https://sample-music.com/preview1.mp3',
        ),
        Track(
          id: '2',
          title: 'Sample Track 2',
          artist: 'Artist 2',
          albumArtUrl: 'https://via.placeholder.com/300',
          previewUrl: 'https://sample-music.com/preview2.mp3',
        ),
      ];
      
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _isSearching = false;
      _errorMessage = 'Error searching tracks: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Clear search results
  void clearSearch() {
    _searchResults = [];
    _searchQuery = '';
    notifyListeners();
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
} 