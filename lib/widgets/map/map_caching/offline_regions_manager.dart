import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_cache_manager.dart';

class OfflineRegionsManager extends StatefulWidget {
  final LatLng? initialLocation;
  final double initialZoom;
  
  const OfflineRegionsManager({
    Key? key,
    this.initialLocation,
    this.initialZoom = 13.0,
  }) : super(key: key);

  @override
  _OfflineRegionsManagerState createState() => _OfflineRegionsManagerState();
}

class _OfflineRegionsManagerState extends State<OfflineRegionsManager> {
  final MapCacheManager _cacheManager = MapCacheManager();
  List<RegionInfo> _regions = [];
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _currentDownloadName;
  
  // For new region
  bool _showAddRegion = false;
  final TextEditingController _nameController = TextEditingController();
  double _selectedRadius = 5.0; // km
  final List<int> _selectedZoomLevels = [13, 14, 15, 16];
  final List<int> _availableZoomLevels = List.generate(7, (i) => i + 11); // 11-17
  LatLng _selectedLocation = const LatLng(51.5, -0.09); // Default London
  int _estimatedTileCount = 0;
  int _estimatedSizeBytes = 0;
  
  @override
  void initState() {
    super.initState();
    _loadRegions();
    
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    }
    
    _estimateRegionStats();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadRegions() async {
    setState(() {
      _isLoading = true;
    });
    
    final regions = await _cacheManager.getOfflineRegions();
    
    setState(() {
      _regions = regions;
      _isLoading = false;
    });
  }
  
  Future<void> _estimateRegionStats() async {
    final stats = await _cacheManager.estimateRegionStats(
      _selectedLocation,
      _selectedRadius,
      _selectedZoomLevels,
    );
    
    setState(() {
      _estimatedTileCount = stats['tileCount'] ?? 0;
      _estimatedSizeBytes = stats['sizeBytes'] ?? 0;
    });
  }
  
  Future<void> _downloadRegion() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for this region')),
      );
      return;
    }
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _currentDownloadName = _nameController.text;
    });
    
    final region = RegionInfo(
      id: const Uuid().v4(),
      name: _nameController.text,
      center: _selectedLocation,
      radiusKm: _selectedRadius,
      zoomLevels: List.from(_selectedZoomLevels),
      createdAt: DateTime.now(),
      tileCount: _estimatedTileCount,
      sizeBytes: _estimatedSizeBytes,
    );
    
    try {
      final result = await _cacheManager.downloadRegionTiles(
        region,
        (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
      
      if (result['success']) {
        await _loadRegions();
        setState(() {
          _showAddRegion = false;
          _nameController.clear();
        });
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded ${result['tileCount']} tiles (${_formatSize(result['totalSize'])})'
            ),
          ),
        );
      } else {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: ${result['error']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isDownloading = false;
        _currentDownloadName = null;
      });
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
      final success = await _cacheManager.deleteOfflineRegion(region.id);
      
      if (success) {
        await _loadRegions();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${region.name}"')),
        );
      } else {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete region')),
        );
      }
    }
  }
  
  String _formatSize(int bytes) {
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
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showAddRegion
              ? _buildAddRegionUI(theme)
              : _buildRegionsList(theme),
      floatingActionButton: !_showAddRegion && !_isDownloading
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _showAddRegion = true;
                  _nameController.text = 'Region ${_regions.length + 1}';
                  _estimateRegionStats();
                });
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
  
  Widget _buildRegionsList(ThemeData theme) {
    if (_regions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 80,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No offline regions',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Download map areas to use offline',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _regions.length,
      itemBuilder: (context, index) {
        final region = _regions[index];
        final date = region.createdAt;
        final formattedDate = '${date.day}/${date.month}/${date.year}';
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(region.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${region.radiusKm.toStringAsFixed(1)} km radius • $formattedDate'),
                Text('${region.tileCount} tiles • ${region.formattedSize}'),
              ],
            ),
            leading: const CircleAvatar(
              child: Icon(Icons.map),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteRegion(region),
            ),
            onTap: () {
              // Future: show region details and option to update
            },
          ),
        );
      },
    );
  }
  
  Widget _buildAddRegionUI(ThemeData theme) {
    return _isDownloading
        ? _buildDownloadProgress(theme)
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Offline Region',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                
                // Region name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Region Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Map for selecting location 
                _buildMiniMap(),
                const SizedBox(height: 24),
                
                // Radius slider
                Text(
                  'Radius: ${_selectedRadius.toStringAsFixed(1)} km',
                  style: theme.textTheme.titleMedium,
                ),
                Slider(
                  value: _selectedRadius,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '${_selectedRadius.toStringAsFixed(1)} km',
                  onChanged: (value) {
                    setState(() {
                      _selectedRadius = value;
                    });
                    _estimateRegionStats();
                  },
                ),
                const SizedBox(height: 24),
                
                // Zoom levels
                Text(
                  'Zoom Levels',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableZoomLevels.map((zoom) {
                    final isSelected = _selectedZoomLevels.contains(zoom);
                    return FilterChip(
                      label: Text('$zoom'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedZoomLevels.add(zoom);
                          } else {
                            _selectedZoomLevels.remove(zoom);
                          }
                          _selectedZoomLevels.sort();
                        });
                        _estimateRegionStats();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                
                // Estimated size
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Download',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Tiles: $_estimatedTileCount'),
                        Text('Size: ${_formatSize(_estimatedSizeBytes)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showAddRegion = false;
                        });
                      },
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _downloadRegion,
                      child: const Text('DOWNLOAD'),
                    ),
                  ],
                ),
              ],
            ),
          );
  }
  
  Widget _buildMiniMap() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                center: _selectedLocation,
                zoom: 10,
                maxZoom: 18,
                minZoom: 5,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    _selectedLocation = latLng;
                  });
                  _estimateRegionStats();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _selectedLocation,
                      radius: 5,
                      color: Colors.blue,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                    CircleMarker(
                      point: _selectedLocation,
                      radius: _selectedRadius * 1000, // Convert km to meters
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Tap to set location',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDownloadProgress(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Downloading $_currentDownloadName',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              value: _downloadProgress,
            ),
            const SizedBox(height: 16),
            Text(
              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'This might take a while depending on your connection speed and the selected area size.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isDownloading = false;
                  _showAddRegion = false;
                });
              },
              child: const Text('CANCEL'),
            ),
          ],
        ),
      ),
    );
  }
} 