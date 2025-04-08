import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/themes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _darkModeEnabled = false;
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader(context, 'Account'),
          
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Account Information'),
            subtitle: Text(authProvider.currentUser?.email ?? 'Not logged in'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to account info screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account info screen coming soon')),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to privacy settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy settings coming soon')),
              );
            },
          ),
          
          const Divider(),
          
          // App settings section
          _buildSectionHeader(context, 'App Settings'),
          
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Enable push notifications'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          
          SwitchListTile(
            secondary: const Icon(Icons.location_on),
            title: const Text('Location Services'),
            subtitle: const Text('Allow app to access your location'),
            value: _locationEnabled,
            onChanged: (value) {
              setState(() {
                _locationEnabled = value;
              });
            },
          ),
          
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });
              
              // Show snackbar indicating this would change the theme
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme changing coming soon')),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English (US)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to language settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Language settings coming soon')),
              );
            },
          ),
          
          const Divider(),
          
          // Music settings section
          _buildSectionHeader(context, 'Music Settings'),
          
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Music Services'),
            subtitle: const Text('Connect to Spotify, Apple Music, etc.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to music services settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Music services settings coming soon')),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Audio Quality'),
            subtitle: const Text('Standard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to audio settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audio settings coming soon')),
              );
            },
          ),
          
          const Divider(),
          
          // About section
          _buildSectionHeader(context, 'About'),
          
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About BOPMaps'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to about screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('About screen coming soon')),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to help screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help screen coming soon')),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to terms screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms screen coming soon')),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to privacy policy screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy screen coming soon')),
              );
            },
          ),
          
          const Divider(),
          
          // Sign out button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                _showSignOutDialog(context, authProvider);
              },
              child: const Text('Sign Out'),
            ),
          ),
          
          // App version at bottom
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'BOPMaps v1.0.0',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
  
  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // Sign out
              authProvider.logout();
              
              // Close the dialog
              Navigator.pop(context);
              
              // Navigate to login screen
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
} 