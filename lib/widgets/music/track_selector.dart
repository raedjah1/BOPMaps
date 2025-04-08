import 'package:flutter/material.dart';
import '../../config/themes.dart';
import '../common/shimmer_loading.dart';
import 'track_card.dart';

class TrackSelector extends StatefulWidget {
  final Function(Map<String, dynamic>) onTrackSelected;
  final bool showSearchBar;
  final bool showRecentlyPlayed;
  final bool showTopTracks;
  
  const TrackSelector({
    Key? key,
    required this.onTrackSelected,
    this.showSearchBar = true,
    this.showRecentlyPlayed = true,
    this.showTopTracks = true,
  }) : super(key: key);

  @override
  State<TrackSelector> createState() => _TrackSelectorState();
}

class _TrackSelectorState extends State<TrackSelector> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Dummy track data for demonstration
  final List<Map<String, dynamic>> _recentlyPlayed = [
    {
      'id': '1',
      'title': 'Blinding Lights',
      'artist': 'The Weeknd',
      'albumArt': 'https://via.placeholder.com/300/ff4080/ffffff?text=BL',
      'duration': '3:22',
    },
    {
      'id': '2',
      'title': 'Savage',
      'artist': 'Megan Thee Stallion',
      'albumArt': 'https://via.placeholder.com/300/40ff80/ffffff?text=S',
      'duration': '2:58',
    },
    {
      'id': '3',
      'title': 'Watermelon Sugar',
      'artist': 'Harry Styles',
      'albumArt': 'https://via.placeholder.com/300/ff8040/ffffff?text=WS',
      'duration': '2:54',
    },
    {
      'id': '4',
      'title': 'Don\'t Start Now',
      'artist': 'Dua Lipa',
      'albumArt': 'https://via.placeholder.com/300/4080ff/ffffff?text=DSN',
      'duration': '3:03',
    },
    {
      'id': '5',
      'title': 'Rain On Me',
      'artist': 'Lady Gaga, Ariana Grande',
      'albumArt': 'https://via.placeholder.com/300/8040ff/ffffff?text=ROM',
      'duration': '3:02',
    },
  ];
  
  final List<Map<String, dynamic>> _topTracks = [
    {
      'id': '6',
      'title': 'Bad Guy',
      'artist': 'Billie Eilish',
      'albumArt': 'https://via.placeholder.com/300/80ff40/ffffff?text=BG',
      'duration': '3:14',
    },
    {
      'id': '7',
      'title': 'Circles',
      'artist': 'Post Malone',
      'albumArt': 'https://via.placeholder.com/300/4040ff/ffffff?text=C',
      'duration': '3:35',
    },
    {
      'id': '8',
      'title': 'Sunflower',
      'artist': 'Post Malone, Swae Lee',
      'albumArt': 'https://via.placeholder.com/300/ffff40/000000?text=SF',
      'duration': '2:38',
    },
    {
      'id': '9',
      'title': 'Dance Monkey',
      'artist': 'Tones and I',
      'albumArt': 'https://via.placeholder.com/300/ff4040/ffffff?text=DM',
      'duration': '3:29',
    },
    {
      'id': '10',
      'title': 'The Box',
      'artist': 'Roddy Ricch',
      'albumArt': 'https://via.placeholder.com/300/404040/ffffff?text=TB',
      'duration': '3:16',
    },
  ];
  
  List<Map<String, dynamic>> _searchResults = [];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tab controller
    _tabController = TabController(
      length: widget.showTopTracks && widget.showRecentlyPlayed ? 2 : 1,
      vsync: this,
    );
    
    // Simulate loading data
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      // Simulate search results by filtering from both lists
      if (_searchQuery.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults = [
          ..._recentlyPlayed,
          ..._topTracks,
        ].where((track) {
          return track['title'].toLowerCase().contains(_searchQuery) ||
              track['artist'].toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        if (widget.showSearchBar)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a song or artist',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: _onSearch,
            ),
          ),
          
        // Show search results if there's a query
        if (_searchQuery.isNotEmpty)
          Expanded(
            child: _buildSearchResults(),
          )
        else
          Expanded(
            child: Column(
              children: [
                // Tab bar
                if (widget.showRecentlyPlayed && widget.showTopTracks)
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryColor,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Recently Played'),
                      Tab(text: 'Your Top Tracks'),
                    ],
                  ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      if (widget.showRecentlyPlayed)
                        _buildTrackList(_recentlyPlayed),
                      if (widget.showTopTracks)
                        _buildTrackList(_topTracks),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildTrackList(List<Map<String, dynamic>> tracks) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: 5,
        itemBuilder: (context, index) => const TrackCardShimmer(),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return TrackCard(
          title: track['title'],
          artist: track['artist'],
          albumArt: track['albumArt'],
          duration: track['duration'],
          onTap: () => widget.onTrackSelected(track),
          isSelected: false,
          showPlayButton: true,
          onPlay: () {
            // Implement preview playback
          },
        );
      },
    );
  }
  
  Widget _buildSearchResults() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: 3,
        itemBuilder: (context, index) => const TrackCardShimmer(),
      );
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final track = _searchResults[index];
        return TrackCard(
          title: track['title'],
          artist: track['artist'],
          albumArt: track['albumArt'],
          duration: track['duration'],
          onTap: () => widget.onTrackSelected(track),
          isSelected: false,
          showPlayButton: true,
          onPlay: () {
            // Implement preview playback
          },
        );
      },
    );
  }
} 