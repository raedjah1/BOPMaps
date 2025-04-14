import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'map_cache_manager.dart';

class OfflineRegionManager extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final VoidCallback? onClose;
  final Function(RegionInfo) onRegionSelected;

  const OfflineRegionManager({
    Key? key,
    required this.initialCenter,
    required this.initialZoom,
    this.onClose,
    required this.onRegionSelected,
  }) : super(key: key);

  @override
  State<OfflineRegionManager> createState() => _OfflineRegionManagerState();
}

class _OfflineRegionManagerState extends State<OfflineRegionManager> with SingleTickerProviderStateMixin {
  final MapCacheManager _cacheManager = MapCacheManager();
  final TextEditingController _nameController = TextEditingController();
  
  late TabController _tabController;
  late LatLng _center;
  late double _zoom;
  late double _radius = 2.0; // Default 2km radius
  late List<int> _selectedZoomLevels = [14, 15, 16];
  
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  Map<String, dynamic>? _estimatedSize;
  List<RegionInfo> _downloadedRegions = [];
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    _zoom = widget.initialZoom;
    _tabController = TabController(length: 2, vsync: this);
    
    _loadDownloadedRegions();
    _checkConnectivity();
    
    // Initial size estimate
    _updateEstimatedSize();
    
    Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      if (isOnline != _isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }
  
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> _loadDownloadedRegions() async {
    final regions = await _cacheManager.getDownloadedRegions();
    setState(() {
      _downloadedRegions = regions;
    });
  }
  
  Future<void> _updateEstimatedSize() async {
    final bounds = _calculateBounds();
    final estimate = await _cacheManager.estimateRegionTileCount(
      bounds,
      _selectedZoomLevels,
    );
    
    setState(() {
      _estimatedSize = estimate;
    });
  }
  
  LatLngBounds _calculateBounds() {
    // Calculate bounds based on center and radius
    final latDelta = _radius / 111.32;
    final lonDelta = _radius / (111.32 * cos(_center.latitude * 3.14159 / 180));
    
    return LatLngBounds(
      LatLng(_center.latitude - latDelta, _center.longitude - lonDelta),
      LatLng(_center.latitude + latDelta, _center.longitude + lonDelta),
    );
  }
  
  Future<void> _startDownload() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot download when offline')),
      );
      return;
    }
    
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for this region')),
      );
      return;
    }
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    
    try {
      final region = await _cacheManager.downloadRegion(
        name: _nameController.text,
        center: _center,
        radiusKm: _radius,
        zoomLevels: _selectedZoomLevels,
        progressCallback: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
      
      setState(() {
        _downloadedRegions.add(region);
        _isDownloading = false;
        _nameController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Region downloaded successfully')),
      );
      
      // Switch to the downloaded regions tab
      _tabController.animateTo(1);
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _deleteRegion(RegionInfo region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Region'),
        content: Text('Are you sure you want to delete "${region.name}"?'),
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
    
    if (confirmed == true) {
      await _cacheManager.deleteRegion(region.id);
      await _loadDownloadedRegions();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Download New'),
            Tab(text: 'Manage Downloaded'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDownloadTab(),
          _buildManageTab(),
        ],
      ),
    );
  }

  Widget _buildDownloadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isOnline)
            Container(
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Row(
                children: [
                  Icon(Icons.signal_wifi_off, color: Colors.red),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'You are currently offline. Connect to the internet to download map regions.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    center: _center,
                    zoom: _zoom,
                    minZoom: 4,
                    maxZoom: 18,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          _center = position.center!;
                          if (position.zoom != null) _zoom = position.zoom!;
                          _updateEstimatedSize();
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
                          point: _center,
                          radius: 5.0,
                          color: Colors.blue,
                          borderColor: Colors.white,
                          borderStrokeWidth: 2.0,
                        ),
                        CircleMarker(
                          point: _center,
                          radius: _getRadiusInPixels(),
                          color: Colors.blue.withOpacity(0.2),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2.0,
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Zoom: ${_zoom.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Region Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Download Radius: ${_radius.toStringAsFixed(1)} km',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _radius,
            min: 0.5,
            max: 50.0,
            divisions: 99,
            label: '${_radius.toStringAsFixed(1)} km',
            onChanged: (value) {
              setState(() {
                _radius = value;
                _updateEstimatedSize();
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'Zoom Levels to Download:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8.0,
            children: [
              for (int zoom = 14; zoom <= 18; zoom++)
                FilterChip(
                  label: Text('Zoom $zoom'),
                  selected: _selectedZoomLevels.contains(zoom),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedZoomLevels.add(zoom);
                      } else {
                        _selectedZoomLevels.remove(zoom);
                      }
                      _updateEstimatedSize();
                    });
                  },
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_estimatedSize != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Download Size: ${_estimatedSize!['formattedSize']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Number of Tiles: ${_estimatedSize!['tileCount']}'),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          if (_isDownloading)
            Column(
              children: [
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text('Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
              ],
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('DOWNLOAD THIS REGION'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isOnline ? _startDownload : null,
            ),
        ],
      ),
    );
  }

  double _getRadiusInPixels() {
    // This is an approximation - calculating exact pixels from km
    // requires complex map projection calculations
    return _radius * 1000 / _getMetersPerPixel();
  }
  
  double _getMetersPerPixel() {
    // Approximation based on OpenStreetMap zoom levels
    return 156543.03392 * cos(_center.latitude * 3.14159 / 180) / pow(2, _zoom);
  }
  
  // Helper function to calculate power
  double pow(double x, double y) {
    return x * (y - 1) + 1; // Very simplified for this context
  }

  Widget _buildManageTab() {
    return _downloadedRegions.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No regions downloaded yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Switch to the Download tab to save areas for offline use',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        : ListView.builder(
            itemCount: _downloadedRegions.length,
            itemBuilder: (context, index) {
              final region = _downloadedRegions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(region.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Downloaded: ${_formatDate(region.dateDownloaded)}'),
                      Text('Size: ${_formatBytes(region.sizeBytes)}'),
                      Text('Zoom Levels: ${region.zoomLevels.join(', ')}'),
                    ],
                  ),
                  isThreeLine: true,
                  leading: const CircleAvatar(
                    child: Icon(Icons.map),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteRegion(region),
                        tooltip: 'Delete',
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () {
                          widget.onRegionSelected(region);
                          if (widget.onClose != null) {
                            widget.onClose!();
                          }
                        },
                        tooltip: 'View on Map',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
} 