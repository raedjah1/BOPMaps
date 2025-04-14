import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:latlong2/latlong.dart';
import 'map_cache_manager.dart';
import 'offline_region_manager.dart';

class OfflineStatusWidget extends StatefulWidget {
  final LatLng currentLocation;
  final double currentZoom;
  final Function(RegionInfo) onRegionSelected;

  const OfflineStatusWidget({
    Key? key,
    required this.currentLocation,
    required this.currentZoom,
    required this.onRegionSelected,
  }) : super(key: key);

  @override
  State<OfflineStatusWidget> createState() => _OfflineStatusWidgetState();
}

class _OfflineStatusWidgetState extends State<OfflineStatusWidget> {
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final MapCacheManager _cacheManager = MapCacheManager();
  int _cachedTilesCount = 0;
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadCacheStats();
    
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _connectionStatus = result;
      });
    });
  }
  
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _connectionStatus = result;
    });
  }
  
  Future<void> _loadCacheStats() async {
    final stats = await _cacheManager.getCacheStats();
    setState(() {
      _cachedTilesCount = stats.tileCount;
    });
  }
  
  bool get _isOffline => _connectionStatus == ConnectivityResult.none;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _isOffline ? Icons.signal_wifi_off : Icons.signal_wifi_4_bar,
                color: _isOffline ? Colors.red : Colors.green,
              ),
              title: Text(
                _isOffline ? 'Offline Mode' : 'Online Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isOffline ? Colors.red : Colors.green,
                ),
              ),
              subtitle: Text(
                _isOffline 
                    ? 'Using cached map data only'
                    : 'Connected to network',
              ),
              trailing: IconButton(
                icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
              ),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cached map tiles:'),
                        Text(
                          '$_cachedTilesCount tiles',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: () => _openOfflineManager(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: const Text('MANAGE OFFLINE MAPS'),
                    ),
                    const SizedBox(height: 8.0),
                    OutlinedButton(
                      onPressed: () {
                        _loadCacheStats();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cache statistics refreshed')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: const Text('REFRESH STATS'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openOfflineManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return OfflineRegionManager(
              initialCenter: widget.currentLocation,
              initialZoom: widget.currentZoom,
              onClose: () => Navigator.of(context).pop(),
              onRegionSelected: widget.onRegionSelected,
            );
          },
        );
      },
    ).then((_) {
      // Refresh cache stats when returning from the manager
      _loadCacheStats();
    });
  }
} 