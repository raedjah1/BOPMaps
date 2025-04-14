import 'package:flutter/material.dart';
import '../../../services/map_cache_manager.dart';
import 'map_cache_extension.dart';
import 'dart:math';

class CacheStatsView extends StatefulWidget {
  final Function()? onCacheCleared;
  
  const CacheStatsView({
    Key? key,
    this.onCacheCleared,
  }) : super(key: key);

  @override
  State<CacheStatsView> createState() => _CacheStatsViewState();
}

class _CacheStatsViewState extends State<CacheStatsView> {
  final MapCacheManager _cacheManager = MapCacheManager();
  CacheStats? _cacheStats;
  bool _isLoading = true;
  bool _isClearing = false;
  
  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }
  
  Future<void> _loadCacheStats() async {
    setState(() {
      _isLoading = true;
    });
    
    final stats = await _cacheManager.getCacheStats();
    
    if (mounted) {
      setState(() {
        _cacheStats = stats;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Cache'),
          content: const Text(
            'Are you sure you want to clear the map cache? '
            'This will delete all cached tiles and offline regions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear Cache'),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      setState(() {
        _isClearing = true;
      });
      
      await _cacheManager.clearCache();
      
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
        
        if (widget.onCacheCleared != null) {
          widget.onCacheCleared!();
        }
        
        _loadCacheStats();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Map Cache Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _isClearing ? null : _loadCacheStats,
                        tooltip: 'Refresh stats',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    'Total Cached Tiles',
                    '${_cacheStats?.tileCount ?? 0}',
                    Icons.grid_view,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    'Cache Size',
                    _cacheStats?.formattedSize ?? '0 B',
                    Icons.storage,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    'Offline Regions',
                    '${_cacheStats?.regionsCount ?? 0}',
                    Icons.map,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isClearing ? null : _clearCache,
                    icon: _isClearing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.delete),
                    label: Text(_isClearing ? 'Clearing...' : 'Clear Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().toString().substring(0, 19)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 