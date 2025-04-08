import 'package:flutter/material.dart';
import '../../config/themes.dart';

class ActivityItem {
  final String id;
  final String username;
  final String userPhotoUrl;
  final String action;
  final String? targetName;
  final String? locationName;
  final DateTime timestamp;
  final String? imageUrl;
  
  ActivityItem({
    required this.id,
    required this.username,
    required this.userPhotoUrl,
    required this.action,
    this.targetName,
    this.locationName,
    required this.timestamp,
    this.imageUrl,
  });
}

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({Key? key}) : super(key: key);

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  // Mock data
  final List<ActivityItem> _activities = [
    ActivityItem(
      id: '1',
      username: 'John Doe',
      userPhotoUrl: 'https://via.placeholder.com/150',
      action: 'dropped a pin',
      targetName: 'Bohemian Rhapsody',
      locationName: 'Downtown',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      imageUrl: 'https://via.placeholder.com/300',
    ),
    ActivityItem(
      id: '2',
      username: 'Jane Smith',
      userPhotoUrl: 'https://via.placeholder.com/150',
      action: 'collected your pin',
      targetName: 'Billie Jean',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    ActivityItem(
      id: '3',
      username: 'Mike Johnson',
      userPhotoUrl: 'https://via.placeholder.com/150',
      action: 'started following you',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    ActivityItem(
      id: '4',
      username: 'Emma Williams',
      userPhotoUrl: 'https://via.placeholder.com/150',
      action: 'dropped a pin',
      targetName: 'Sweet Child O\' Mine',
      locationName: 'Central Park',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      imageUrl: 'https://via.placeholder.com/300',
    ),
    ActivityItem(
      id: '5',
      username: 'You',
      userPhotoUrl: 'https://via.placeholder.com/150',
      action: 'collected a pin',
      targetName: 'Stairway to Heaven',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
    ActivityItem(
      id: '6',
      username: 'Alex Brown',
      userPhotoUrl: 'https://via.placeholder.com/150',
      action: 'commented on your pin',
      targetName: 'Bohemian Rhapsody',
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
    ),
    ActivityItem(
      id: '7',
      username: 'You',
      userPhotoUrl: 'https://via.placeholder.com/150',
      action: 'started following',
      targetName: 'Sarah Davis',
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
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
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'You'),
            Tab(text: 'Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All activity
          _buildActivityList(filter: null),
          
          // Your activity
          _buildActivityList(filter: 'You'),
          
          // Friends activity
          _buildActivityList(filter: 'friends'),
        ],
      ),
    );
  }
  
  Widget _buildActivityList({String? filter}) {
    final filteredActivities = _activities
        .where((activity) {
          if (filter == null) return true;
          if (filter == 'You') return activity.username == 'You';
          if (filter == 'friends') return activity.username != 'You';
          return true;
        })
        .toList();
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (filteredActivities.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        // Simulate refreshing data
        setState(() {
          _isLoading = true;
        });
        
        await Future.delayed(const Duration(seconds: 1));
        
        setState(() {
          _isLoading = false;
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filteredActivities.length,
        itemBuilder: (context, index) {
          final activity = filteredActivities[index];
          return _buildActivityListItem(activity);
        },
      ),
    );
  }
  
  Widget _buildActivityListItem(ActivityItem activity) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and time
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(activity.userPhotoUrl),
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style,
                          children: [
                            TextSpan(
                              text: activity.username,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: ' ${activity.action}',
                            ),
                            if (activity.targetName != null)
                              TextSpan(
                                text: ' ${activity.targetName}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            if (activity.locationName != null)
                              TextSpan(
                                text: ' at ${activity.locationName}',
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTimestamp(activity.timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Image preview if available
            if (activity.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  activity.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            
            // Action buttons
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: Icons.thumb_up_outlined,
                  label: 'Like',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Like feature coming soon')),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comment feature coming soon')),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share feature coming soon')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for updates from friends',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
} 