import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/themes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header
            _buildProfileHeader(context, user),
            
            const SizedBox(height: 24),
            
            // Stats section
            _buildStatsSection(context),
            
            const SizedBox(height: 24),
            
            // Activity section
            _buildActivitySection(context),
            
            const SizedBox(height: 24),
            
            // My pins section
            _buildMyPinsSection(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        children: [
          // Profile picture
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              image: user?.photoURL != null
                  ? DecorationImage(
                      image: NetworkImage(user!.photoURL!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: user?.photoURL == null ? Colors.grey[300] : null,
            ),
            child: user?.photoURL == null
                ? const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.grey,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          
          // Username
          Text(
            user?.displayName ?? 'Anonymous User',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // User status or description
          Text(
            'Music Enthusiast',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Edit profile button
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            onPressed: () {
              // Navigate to edit profile screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile feature coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stats',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, '8', 'Pins Dropped'),
              _buildStatItem(context, '23', 'Pins Collected'),
              _buildStatItem(context, '12', 'Friends'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActivitySection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                child: const Text('View All'),
                onPressed: () {
                  Navigator.pushNamed(context, '/activity');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Activity items
          _buildActivityItem(
            context,
            icon: Icons.add_location,
            title: 'You dropped a pin',
            subtitle: '"Bohemian Rhapsody" at Downtown',
            timeAgo: '2 hours ago',
          ),
          _buildActivityItem(
            context,
            icon: Icons.music_note,
            title: 'You collected a pin',
            subtitle: '"Billie Jean" by Michael Jackson',
            timeAgo: '1 day ago',
          ),
          _buildActivityItem(
            context,
            icon: Icons.people,
            title: 'New friend',
            subtitle: 'John Doe started following you',
            timeAgo: '3 days ago',
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String timeAgo,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMyPinsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Pins',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                child: const Text('View All'),
                onPressed: () {
                  // Navigate to my pins screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('My pins page coming soon')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Grid of pins
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: 4, // Show only a few pins
            itemBuilder: (context, index) {
              return _buildPinCard(context, index);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildPinCard(BuildContext context, int index) {
    final dummyData = [
      {
        'title': 'Bohemian Rhapsody',
        'artist': 'Queen',
        'imageUrl': 'https://via.placeholder.com/150',
      },
      {
        'title': 'Billie Jean',
        'artist': 'Michael Jackson',
        'imageUrl': 'https://via.placeholder.com/150',
      },
      {
        'title': 'Sweet Child O\' Mine',
        'artist': 'Guns N\' Roses',
        'imageUrl': 'https://via.placeholder.com/150',
      },
      {
        'title': 'Stairway to Heaven',
        'artist': 'Led Zeppelin',
        'imageUrl': 'https://via.placeholder.com/150',
      },
    ];
    
    final pin = index < dummyData.length ? dummyData[index] : dummyData[0];
    
    return GestureDetector(
      onTap: () {
        // Navigate to pin details
        Navigator.pushNamed(
          context,
          '/pin_details',
          arguments: {'pin': pin},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(pin['imageUrl']!),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pin['title']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                pin['artist']!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 