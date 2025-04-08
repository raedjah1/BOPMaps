import 'package:flutter/material.dart';
import '../../config/themes.dart';

// Simple version of Friend class for UI presentation
class FriendUI {
  final String id;
  final String username;
  final String? bio;
  final String? photoUrl;
  final bool isFollowing;
  final bool isFollowedBy;

  FriendUI({
    required this.id,
    required this.username,
    this.bio,
    this.photoUrl,
    required this.isFollowing,
    required this.isFollowedBy,
  });
  
  // Create a copy with modified properties
  FriendUI copyWith({
    String? id,
    String? username,
    String? bio,
    String? photoUrl,
    bool? isFollowing,
    bool? isFollowedBy,
  }) {
    return FriendUI(
      id: id ?? this.id,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
    );
  }
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  
  // Mock data
  final List<FriendUI> _friends = [
    FriendUI(
      id: '1',
      username: 'johndoe',
      bio: 'Music lover and guitarist 🎸',
      photoUrl: 'https://via.placeholder.com/150',
      isFollowing: true,
      isFollowedBy: true,
    ),
    FriendUI(
      id: '2',
      username: 'janesmith',
      bio: 'EDM enthusiast and dancer 💃',
      photoUrl: 'https://via.placeholder.com/150',
      isFollowing: true,
      isFollowedBy: true,
    ),
    FriendUI(
      id: '3',
      username: 'mikej',
      bio: 'Jazz and blues fan 🎷',
      photoUrl: 'https://via.placeholder.com/150',
      isFollowing: true,
      isFollowedBy: true,
    ),
    FriendUI(
      id: '4',
      username: 'emmaw',
      bio: 'Classical music lover 🎻',
      photoUrl: 'https://via.placeholder.com/150',
      isFollowing: true,
      isFollowedBy: false,
    ),
  ];
  
  final List<FriendUI> _suggestions = [
    FriendUI(
      id: '5',
      username: 'alexb',
      bio: 'Hip-hop producer 🎧',
      photoUrl: 'https://via.placeholder.com/150',
      isFollowing: false,
      isFollowedBy: false,
    ),
    FriendUI(
      id: '6',
      username: 'sarahd',
      bio: 'Indie rock lover 🎸',
      photoUrl: 'https://via.placeholder.com/150',
      isFollowing: false,
      isFollowedBy: true,
    ),
    FriendUI(
      id: '7',
      username: 'chrism',
      bio: 'Pop music fan 🎤',
      photoUrl: 'https://via.placeholder.com/150',
      isFollowing: false,
      isFollowedBy: false,
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                // Filter friends based on search query
                setState(() {});
              },
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Friends tab
                _buildFriendsTab(),
                
                // Followers tab
                _buildFollowersTab(),
                
                // Following tab
                _buildFollowingTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFindFriendsBottomSheet(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }
  
  Widget _buildFriendsTab() {
    final filteredFriends = _friends
        .where((friend) => 
            friend.username.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (filteredFriends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people,
        message: 'No friends found',
        buttonText: 'Find Friends',
        onPressed: () => _showFindFriendsBottomSheet(context),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = filteredFriends[index];
        return _buildFriendListItem(friend);
      },
    );
  }
  
  Widget _buildFollowersTab() {
    final followers = _friends
        .where((friend) => friend.isFollowedBy)
        .where((friend) => 
            friend.username.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();
    
    // Add suggestion that is following you
    final followerSuggestions = _suggestions
        .where((friend) => friend.isFollowedBy)
        .where((friend) => 
            friend.username.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();
    
    final allFollowers = [...followers, ...followerSuggestions];
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (allFollowers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people,
        message: 'No followers yet',
        buttonText: 'Find Friends',
        onPressed: () => _showFindFriendsBottomSheet(context),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: allFollowers.length,
      itemBuilder: (context, index) {
        final friend = allFollowers[index];
        return _buildFriendListItem(friend);
      },
    );
  }
  
  Widget _buildFollowingTab() {
    final following = _friends
        .where((friend) => friend.isFollowing)
        .where((friend) => 
            friend.username.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (following.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people,
        message: 'Not following anyone yet',
        buttonText: 'Find Friends',
        onPressed: () => _showFindFriendsBottomSheet(context),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: following.length,
      itemBuilder: (context, index) {
        final friend = following[index];
        return _buildFriendListItem(friend);
      },
    );
  }
  
  Widget _buildFriendListItem(FriendUI friend) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
        child: friend.photoUrl == null ? const Icon(Icons.person) : null,
        radius: 24,
      ),
      title: Text(
        friend.username,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: friend.bio != null ? Text(
        friend.bio!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ) : null,
      trailing: OutlinedButton(
        onPressed: () {
          // This is just a UI prototype, so we're not actually changing the data
          // In a real app, you would call an API to follow/unfollow
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friend.isFollowing 
                  ? 'Unfollowed ${friend.username}'
                  : 'Now following ${friend.username}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Text(
          friend.isFollowing ? 'Unfollow' : 'Follow',
        ),
      ),
      onTap: () {
        // Navigate to friend profile
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing ${friend.username}\'s profile coming soon')),
        );
      },
    );
  }
  
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
  
  void _showFindFriendsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle and title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Find Friends',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name or username',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
                
                // Section title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text(
                        'Suggested for You',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // Refresh suggestions
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Refreshing suggestions...')),
                          );
                        },
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
                
                // Friend suggestions list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return _buildFriendListItem(suggestion);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
} 