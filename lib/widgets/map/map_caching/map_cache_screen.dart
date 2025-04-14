import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_cache_manager.dart';

class MapCacheScreen extends StatefulWidget {
  const MapCacheScreen({Key? key}) : super(key: key);

  @override
  _MapCacheScreenState createState() => _MapCacheScreenState();
}

class _MapCacheScreenState extends State<MapCacheScreen> with SingleTickerProviderStateMixin {
  final MapCacheManager _cacheManager = MapCacheManager();
  Map<String, dynamic> _cacheStats = {};
  List<Map<String, dynamic>> _downloadedRegions = [];
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _currentDownloadName;
  
  late TabController _tabController;
  
  // Settings values
  int _maxMemoryCache = 100;
  int _maxDiskCache = 500;
  int _cacheExpiryDays = 30;
  
  // Region download values
  final TextEditingController _regionNameController = TextEditingController();
  late MapController _mapController;
  LatLng _centerPoint = const LatLng(51.5, -0.09); // London as default
  double _radius = 5.0; // 5km radius
  final List<int> _selectedZoomLevels = [13, 14, 15, 16];
  final List<int> _availableZoomLevels = [10, 11, 12, 13, 14, 15, 16, 17, 18];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _mapController = MapController();
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _regionNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _cacheManager.ensureInitialized();
      
      // Load cache statistics
      final stats = await _cacheManager.getCacheStatistics();
      
      // Load downloaded regions
      final regions = await _cacheManager.getDownloadedRegions();
      
      // Update state
      setState(() {
        _cacheStats = stats;
        _downloadedRegions = regions;
        _maxMemoryCache = stats['memoryCacheSize'] ?? 100;
        _maxDiskCache = (stats['diskCacheSizeMB'] ?? 500).round();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cache data: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cache data: $e')),
        );
      }
    }
  }
  
  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _cacheManager.clearCache();
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing cache: $e')),
        );
      }
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteRegion(String regionId, String regionName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Region'),
        content: Text('Are you sure you want to delete the offline region "$regionName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _cacheManager.deleteRegion(regionId);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Region "$regionName" deleted')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting region: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting region: $e')),
        );
      }
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _cacheManager.updateSettings(
        maxMemoryCacheSize: _maxMemoryCache,
        maxDiskCacheSizeMB: _maxDiskCache,
        tileCacheExpiryDays: _cacheExpiryDays,
      );
      
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _downloadRegion() async {
    if (_regionNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the region')),
      );
      return;
    }
    
    if (_selectedZoomLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one zoom level')),
      );
      return;
    }
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _currentDownloadName = _regionNameController.text;
    });
    
    try {
      // Calculate bounds from center point and radius
      final bounds = _calculateBoundsFromRadius(_centerPoint, _radius);
      
      // Start download
      final success = await _cacheManager.downloadRegion(
        _regionNameController.text,
        bounds,
        _selectedZoomLevels,
        (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
      
      if (success) {
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Region "${_regionNameController.text}" downloaded successfully')),
          );
        }
        
        // Reset form
        _regionNameController.clear();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error downloading region')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error downloading region: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading region: $e')),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _currentDownloadName = null;
      });
    }
  }
  
  LatLngBounds _calculateBoundsFromRadius(LatLng center, double radiusKm) {
    // Earth's radius in kilometers
    const double earthRadius = 6371.0;
    
    // Convert radius from km to degrees (approximate)
    final double radiusDegrees = radiusKm / earthRadius * (180 / pi);
    
    // Calculate the bounds
    final southWest = LatLng(
      center.latitude - radiusDegrees,
      center.longitude - radiusDegrees / cos(center.latitude * pi / 180),
    );
    
    final northEast = LatLng(
      center.latitude + radiusDegrees,
      center.longitude + radiusDegrees / cos(center.latitude * pi / 180),
    );
    
    return LatLngBounds(southWest, northEast);
  }
  
  double _estimateTileCount(List<int> zoomLevels, double radiusKm) {
    double totalTiles = 0;
    
    for (final zoom in zoomLevels) {
      // Approximate number of tiles at this zoom level within the radius
      final tilesPerSide = pow(2, zoom) / 360 * (radiusKm * 2) / 111;
      totalTiles += tilesPerSide * tilesPerSide;
    }
    
    return totalTiles;
  }
  
  double _estimateDownloadSize(List<int> zoomLevels, double radiusKm) {
    // Average tile size in KB
    const avgTileSizeKB = 20.0;
    
    // Estimate total number of tiles
    final tileCount = _estimateTileCount(zoomLevels, radiusKm);
    
    // Calculate total size in MB
    return tileCount * avgTileSizeKB / 1024;
  }
  
  int pow(int x, int y) {
    int result = 1;
    for (int i = 0; i < y; i++) {
      result *= x;
    }
    return result;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'DOWNLOADED REGIONS'),
            Tab(text: 'DOWNLOAD NEW'),
            Tab(text: 'SETTINGS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDownloadedRegionsTab(),
                _buildDownloadNewTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }
  
  Widget _buildDownloadedRegionsTab() {
    if (_downloadedRegions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No offline regions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Download map areas to use when offline',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('DOWNLOAD A REGION'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        _buildCacheStatsCard(),
        Expanded(
          child: ListView.builder(
            itemCount: _downloadedRegions.length,
            itemBuilder: (context, index) {
              final region = _downloadedRegions[index];
              final regionName = region['name'] as String;
              final regionId = region['id'] as String;
              final timestamp = region['download_timestamp'] as int;
              final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
              final formattedDate = DateFormat('MMM d, yyyy').format(date);
              final sizeBytes = region['size_bytes'] as int;
              final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
              
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(regionName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Downloaded: $formattedDate\nSize: $sizeMB MB'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRegion(regionId, regionName),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildCacheStatsCard() {
    final totalCache = _cacheStats['diskCacheSizeMB'] ?? 0.0;
    final totalCacheMB = totalCache.toStringAsFixed(1);
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cache Statistics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _clearCache,
                  child: const Text('CLEAR ALL'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Total cache size: $totalCacheMB MB'),
            Text('Downloaded regions: ${_downloadedRegions.length}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: totalCache / _maxDiskCache,
              backgroundColor: Colors.grey[200],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDownloadNewTab() {
    if (_isDownloading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Downloading $_currentDownloadName',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(value: _downloadProgress),
            ),
          ],
        ),
      );
    }
    
    final downloadSize = _estimateDownloadSize(_selectedZoomLevels, _radius);
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _regionNameController,
              decoration: const InputDecoration(
                labelText: 'Region Name',
                hintText: 'Enter a name for this region',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Map Area', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        center: _centerPoint,
                        zoom: 10,
                        maxZoom: 18,
                        minZoom: 3,
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture) {
                            setState(() {
                              _centerPoint = position.center!;
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _centerPoint,
                              radius: 8,
                              color: Colors.blue.withOpacity(0.7),
                              borderColor: Colors.white,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        // Draw the radius circle
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _centerPoint,
                              radius: _radius * 1000, // Convert km to meters
                              color: Colors.blue.withOpacity(0.2),
                              borderColor: Colors.blue,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          _mapController.move(_centerPoint, _mapController.zoom + 1);
                        },
                        child: const Icon(Icons.add),
                      ),
                    ),
                    Positioned(
                      top: 60,
                      right: 8,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          _mapController.move(_centerPoint, _mapController.zoom - 1);
                        },
                        child: const Icon(Icons.remove),
                      ),
                    ),
                    // GPS/Current location button
                    Positioned(
                      top: 112,
                      right: 8,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          // Request location permission and get current location
                          // This would be implemented with location package
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Location permission required. Please enable in settings.'),
                            ),
                          );
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Radius: ${_radius.toStringAsFixed(1)} km'),
            Slider(
              value: _radius,
              min: 1.0,
              max: 30.0,
              divisions: 29,
              label: '${_radius.toStringAsFixed(1)} km',
              onChanged: (value) {
                setState(() {
                  _radius = value;
                });
              },
            ),
            const SizedBox(height: 24),
            Text('Zoom Levels', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Select zoom levels to download (higher zoom = more detail)'),
            Wrap(
              spacing: 8,
              children: _availableZoomLevels.map((zoom) {
                return FilterChip(
                  label: Text('$zoom'),
                  selected: _selectedZoomLevels.contains(zoom),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedZoomLevels.add(zoom);
                      } else {
                        _selectedZoomLevels.remove(zoom);
                      }
                      _selectedZoomLevels.sort();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated download size: ${downloadSize.toStringAsFixed(1)} MB',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selected zoom levels: ${_selectedZoomLevels.join(', ')}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _downloadRegion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('DOWNLOAD REGION'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cache Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Maximum memory cache size'),
              subtitle: const Text('Number of tiles to keep in memory'),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  controller: TextEditingController(text: _maxMemoryCache.toString()),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      _maxMemoryCache = int.parse(value);
                    }
                  },
                ),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Maximum disk cache size'),
              subtitle: const Text('Maximum size of the cache in MB'),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    suffixText: 'MB',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  controller: TextEditingController(text: _maxDiskCache.toString()),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      _maxDiskCache = int.parse(value);
                    }
                  },
                ),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Cache expiry'),
              subtitle: const Text('Days before cached tiles expire'),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    suffixText: 'days',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  controller: TextEditingController(text: _cacheExpiryDays.toString()),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      _cacheExpiryDays = int.parse(value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Current Cache Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _statRow('Total cache size', '${(_cacheStats['diskCacheSizeMB'] ?? 0.0).toStringAsFixed(1)} MB'),
                    _statRow('Cache hit ratio', '${((_cacheStats['hitRatio'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
                    _statRow('Cache hits', '${_cacheStats['cacheHits'] ?? 0}'),
                    _statRow('Cache misses', '${_cacheStats['cacheMisses'] ?? 0}'),
                    _statRow('Downloaded regions', '${_downloadedRegions.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('SAVE SETTINGS'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _clearCache,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('CLEAR CACHE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
} 