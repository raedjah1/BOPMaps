import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../services/map_cache_manager.dart';
import 'map_cache_extension.dart';
import '../../../utils/time_formatter.dart';
import '../../../utils/map_size_calculator.dart';

/// Widget for displaying and managing offline map regions
class OfflineRegionsView extends StatefulWidget {
  const OfflineRegionsView({Key? key}) : super(key: key);

  @override
  State<OfflineRegionsView> createState() => _OfflineRegionsViewState();
}

class _OfflineRegionsViewState extends State<OfflineRegionsView> {
  final MapCacheManager _cacheManager = MapCacheManager();
  List<OfflineRegion> _regions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  /// Load offline regions from the cache manager
  Future<void> _loadRegions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _cacheManager.initialize();
      final regions = await _cacheManager.getOfflineRegions();
      
      setState(() {
        _regions = regions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load offline regions: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Show the dialog to remove a region
  void _removeRegion(OfflineRegion region) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Offline Region'),
        content: Text('Are you sure you want to remove "${region.name}"?'
            '\n\nThis will delete all cached map data for this region.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Show loading indicator
              setState(() => _isLoading = true);
              
              try {
                final success = await _cacheManager.removeOfflineRegion(region.id);
                if (success) {
                  _loadRegions(); // Refresh the list
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed "${region.name}"')),
                    );
                  }
                } else {
                  setState(() {
                    _isLoading = false;
                    _error = 'Failed to remove region';
                  });
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                  _error = 'Error removing region: ${e.toString()}';
                });
              }
            },
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  /// Show the add region dialog
  void _showAddRegionDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddOfflineRegionScreen(),
        fullscreenDialog: true,
      ),
    ).then((_) => _loadRegions()); // Refresh when returning from add screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Regions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRegionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Build the body of the screen
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRegions,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_regions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No offline regions',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a region to use maps without an internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddRegionDialog,
              icon: const Icon(Icons.add),
              label: const Text('ADD REGION'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRegions,
      child: ListView.builder(
        itemCount: _regions.length,
        itemBuilder: (context, index) {
          final region = _regions[index];
          return _buildRegionItem(region);
        },
      ),
    );
  }

  /// Build a list item for a region
  Widget _buildRegionItem(OfflineRegion region) {
    final theme = Theme.of(context);
    
    // Calculate size info
    final tilesCount = region.totalTiles ?? 0;
    final sizeText = region.totalTiles != null
        ? '${(tilesCount * MapSizeCalculator.averageTileSizeKB / 1024).toStringAsFixed(1)} MB'
        : 'Size unknown';
        
    // Determine status color and text
    Color statusColor;
    String statusText;
    
    switch (region.status) {
      case OfflineRegionStatus.pending:
        statusColor = Colors.grey;
        statusText = 'Pending';
        break;
      case OfflineRegionStatus.downloading:
        statusColor = Colors.blue;
        statusText = 'Downloading';
        break;
      case OfflineRegionStatus.downloaded:
        statusColor = Colors.green;
        statusText = 'Downloaded';
        break;
      case OfflineRegionStatus.cancelled:
        statusColor = Colors.orange;
        statusText = 'Cancelled';
        break;
      case OfflineRegionStatus.error:
        statusColor = Colors.red;
        statusText = 'Error';
        break;
    }
    
    // Get formatted download date
    final downloadDateText = region.downloadedAt != null
        ? 'Downloaded ${TimeFormatter.formatRelative(region.downloadedAt!)}'
        : 'Not downloaded';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with name and status
          ListTile(
            title: Text(
              region.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('${region.areaKm2.toStringAsFixed(1)} km² • Zoom ${region.minZoom}-${region.maxZoom}'),
            trailing: Chip(
              label: Text(statusText),
              backgroundColor: statusColor.withOpacity(0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
          ),
          
          // Map preview (placeholder for now)
          Container(
            height: 120,
            color: Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.map,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
          ),
          
          // Info section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            downloadDateText,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$tilesCount tiles • $sizeText',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    
                    // Action buttons
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeRegion(region),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
                
                // Show error if any
                if (region.error != null && region.status == OfflineRegionStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Error: ${region.error}',
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ),
                  
                // Progress indicator for downloading regions
                if (region.status == OfflineRegionStatus.downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: StreamBuilder<MapDownloadProgress>(
                      stream: _cacheManager.downloadProgressStream,
                      builder: (context, snapshot) {
                        double progress = 0.0;
                        if (snapshot.hasData && snapshot.data!.regionId == region.id) {
                          progress = snapshot.data!.progress;
                        } else {
                          progress = _cacheManager.getDownloadProgress(region.id);
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 4),
                            Text(
                              'Downloading: ${(progress * 100).toStringAsFixed(1)}%',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen for adding a new offline region
class AddOfflineRegionScreen extends StatefulWidget {
  const AddOfflineRegionScreen({Key? key}) : super(key: key);

  @override
  State<AddOfflineRegionScreen> createState() => _AddOfflineRegionScreenState();
}

class _AddOfflineRegionScreenState extends State<AddOfflineRegionScreen> {
  final MapCacheManager _cacheManager = MapCacheManager();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  double _north = 40.75;
  double _south = 40.70;
  double _east = -73.95;
  double _west = -74.00;
  
  RangeValues _zoomRange = const RangeValues(12, 16);
  bool _isLoading = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Calculate the total number of tiles
  int _calculateTotalTiles() {
    return MapSizeCalculator.calculateTotalTiles(
      _north,
      _south,
      _east,
      _west,
      _zoomRange.start.round(),
      _zoomRange.end.round(),
    );
  }

  /// Calculate the estimated size in MB
  double _calculateEstimatedSizeMB() {
    return MapSizeCalculator.estimateSizeMB(
      _north,
      _south,
      _east,
      _west,
      _zoomRange.start.round(),
      _zoomRange.end.round(),
    );
  }

  /// Save the region
  Future<void> _saveRegion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Create region
      final region = OfflineRegion(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        north: _north,
        south: _south,
        east: _east,
        west: _west,
        minZoom: _zoomRange.start.round(),
        maxZoom: _zoomRange.end.round(),
        createdAt: DateTime.now(),
        status: OfflineRegionStatus.pending,
      );
      
      // Save region metadata
      final success = await _cacheManager.saveRegionMetadata(region);
      
      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Region added successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add region')),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Offline Region'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Region name input
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Region Name',
                        hintText: 'e.g., Downtown Manhattan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name for this region';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Map preview (placeholder)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('Map Preview'),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Coordinates display
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Region Coordinates',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('North: ${_north.toStringAsFixed(6)}°'),
                            Text('South: ${_south.toStringAsFixed(6)}°'),
                            Text('East: ${_east.toStringAsFixed(6)}°'),
                            Text('West: ${_west.toStringAsFixed(6)}°'),
                            const SizedBox(height: 8),
                            Text('Area: ${MapSizeCalculator.calculateAreaKm2(_north, _south, _east, _west).toStringAsFixed(2)} km²'),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Zoom level range slider
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Zoom Levels',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Min: ${_zoomRange.start.round()} - Max: ${_zoomRange.end.round()}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            RangeSlider(
                              values: _zoomRange,
                              min: 1,
                              max: 19,
                              divisions: 18,
                              labels: RangeLabels(
                                _zoomRange.start.round().toString(),
                                _zoomRange.end.round().toString(),
                              ),
                              onChanged: (values) {
                                setState(() {
                                  _zoomRange = values;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Size estimate
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Download Size Estimate',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Total Tiles: ${_calculateTotalTiles()}'),
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Estimated Size: ${_calculateEstimatedSizeMB().toStringAsFixed(1)} MB'),
                                ),
                                // Show the size indicator with color changing based on size
                                _buildSizeIndicator(_calculateEstimatedSizeMB()),
                              ],
                            ),
                            Text('Estimated Download Time: ${MapSizeCalculator.estimateDownloadTime(_calculateEstimatedSizeMB() * 1024, 5.0)}'),
                            
                            // Size progress indicator
                            const SizedBox(height: 8),
                            _buildDownloadSizeProgressBar(),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Warnings
                    if (_calculateEstimatedSizeMB() > 100)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Large area selected (${_calculateEstimatedSizeMB().toStringAsFixed(0)} MB). Consider reducing the area or zoom levels to save storage space.',
                                style: TextStyle(color: Colors.amber[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Hard limit warning  
                    if (_calculateEstimatedSizeMB() > 200)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[800]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Download size limit exceeded!',
                                    style: TextStyle(
                                      color: Colors.red[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'The selected area exceeds the maximum download size of 200 MB. Please reduce the area or zoom levels to continue.',
                              style: TextStyle(color: Colors.red[900]),
                            ),
                            const SizedBox(height: 8),
                            _buildSuggestionChips(),
                          ],
                        ),
                      ),
                      
                    const SizedBox(height: 24),
                    
                    // Save button
                    ElevatedButton(
                      onPressed: _calculateEstimatedSizeMB() > 200 ? null : _saveRegion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _calculateEstimatedSizeMB() > 200 
                          ? const Text('REDUCE SIZE TO CONTINUE')
                          : const Text('SAVE REGION'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Build a size indicator with color changing based on size
  Widget _buildSizeIndicator(double sizeMB) {
    // Define the thresholds and colors for different size ranges
    Color indicatorColor;
    String label;
    IconData icon;
    
    if (sizeMB <= 50) {
      indicatorColor = Colors.green;
      label = 'Small';
      icon = Icons.check_circle;
    } else if (sizeMB <= 100) {
      indicatorColor = Colors.green[700]!;
      label = 'Medium';
      icon = Icons.check_circle_outline;
    } else if (sizeMB <= 150) {
      indicatorColor = Colors.orange;
      label = 'Large';
      icon = Icons.warning;
    } else if (sizeMB <= 200) {
      indicatorColor = Colors.deepOrange;
      label = 'Very large';
      icon = Icons.warning_amber;
    } else {
      indicatorColor = Colors.red;
      label = 'Excessive';
      icon = Icons.error;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: indicatorColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: indicatorColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: indicatorColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a download size progress bar relative to maximum allowed size
  Widget _buildDownloadSizeProgressBar() {
    final sizeMB = _calculateEstimatedSizeMB();
    final maxSizeMB = 200.0; // Maximum allowed size
    final progress = (sizeMB / maxSizeMB).clamp(0.0, 1.0);
    
    // Determine color based on progress
    Color progressColor;
    if (progress < 0.5) {
      progressColor = Colors.green;
    } else if (progress < 0.75) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Download size limit: 200 MB',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  /// Build suggestion chips based on current selection to help user reduce size
  Widget _buildSuggestionChips() {
    // Calculate various size reduction options
    final originalSize = _calculateEstimatedSizeMB();
    final zoomDiff = _zoomRange.end - _zoomRange.start;
    
    // Create suggestions list
    List<Widget> suggestions = [];
    
    // 1. Reduce max zoom level by 1 option
    if (_zoomRange.end > _zoomRange.start + 1) {
      final reducedZoomEnd = _zoomRange.end - 1;
      final reducedMaxZoomSize = MapSizeCalculator.estimateSizeMB(
        _north, _south, _east, _west, 
        _zoomRange.start.round(), reducedZoomEnd.round()
      );
      final savings = originalSize - reducedMaxZoomSize;
      
      suggestions.add(_buildSuggestionChip(
        'Reduce max zoom to ${reducedZoomEnd.round()}',
        'Save ${savings.toStringAsFixed(0)} MB',
        () {
          setState(() {
            _zoomRange = RangeValues(_zoomRange.start, reducedZoomEnd);
          });
        },
      ));
    }
    
    // 2. Reduce zoom range option
    if (zoomDiff > 2) {
      final reducedZoomRange = RangeValues(_zoomRange.start + 1, _zoomRange.end - 1);
      final reducedRangeSize = MapSizeCalculator.estimateSizeMB(
        _north, _south, _east, _west, 
        reducedZoomRange.start.round(), reducedZoomRange.end.round()
      );
      final savings = originalSize - reducedRangeSize;
      
      suggestions.add(_buildSuggestionChip(
        'Narrow zoom range',
        'Save ${savings.toStringAsFixed(0)} MB',
        () {
          setState(() {
            _zoomRange = reducedZoomRange;
          });
        },
      ));
    }
    
    // 3. Split area into multiple smaller regions
    suggestions.add(_buildSuggestionChip(
      'Split into smaller regions',
      'Divide area into 4 parts',
      () {
        _showSplitAreaDialog();
      },
    ));
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions,
    );
  }
  
  /// Build a single suggestion chip
  Widget _buildSuggestionChip(String label, String subtitle, VoidCallback onPressed) {
    return ActionChip(
      avatar: const Icon(Icons.lightbulb_outline, size: 18),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(subtitle, style: const TextStyle(fontSize: 10)),
        ],
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
      onPressed: onPressed,
    );
  }
  
  /// Show dialog for splitting area into smaller regions
  void _showSplitAreaDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Split Area'),
        content: const Text(
          'Would you like to split this large area into 4 smaller regions that can be downloaded separately?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _splitAreaIntoFourRegions();
            },
            child: const Text('SPLIT AREA'),
          ),
        ],
      ),
    );
  }
  
  /// Split current area into four smaller regions
  void _splitAreaIntoFourRegions() {
    // Calculate midpoints
    final midLat = (_north + _south) / 2;
    final midLng = (_east + _west) / 2;
    
    // Show a confirmation with the resulting sizes
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Split Area Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will create 4 regions:'),
            const SizedBox(height: 8),
            Text('• Northwest: ~ ${MapSizeCalculator.estimateSizeMB(_north, midLat, midLng, _west, _zoomRange.start.round(), _zoomRange.end.round()).toStringAsFixed(0)} MB'),
            Text('• Northeast: ~ ${MapSizeCalculator.estimateSizeMB(_north, midLat, _east, midLng, _zoomRange.start.round(), _zoomRange.end.round()).toStringAsFixed(0)} MB'),
            Text('• Southwest: ~ ${MapSizeCalculator.estimateSizeMB(midLat, _south, midLng, _west, _zoomRange.start.round(), _zoomRange.end.round()).toStringAsFixed(0)} MB'),
            Text('• Southeast: ~ ${MapSizeCalculator.estimateSizeMB(midLat, _south, _east, midLng, _zoomRange.start.round(), _zoomRange.end.round()).toStringAsFixed(0)} MB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Autogenerate names from original name
              final baseName = _nameController.text.trim();
              
              // Create each region with a unique ID
              _createSplitRegion('$baseName (NW)', _north, midLat, midLng, _west);
              _createSplitRegion('$baseName (NE)', _north, midLat, _east, midLng);
              _createSplitRegion('$baseName (SW)', midLat, _south, midLng, _west);
              _createSplitRegion('$baseName (SE)', midLat, _south, _east, midLng);
              
              // Close the current screen after splitting
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Area split into 4 regions')),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('CONFIRM SPLIT'),
          ),
        ],
      ),
    );
  }
  
  /// Create a single split region with the given bounds
  Future<void> _createSplitRegion(String name, double north, double south, double east, double west) async {
    try {
      final region = OfflineRegion(
        id: const Uuid().v4(),
        name: name,
        north: north,
        south: south,
        east: east,
        west: west,
        minZoom: _zoomRange.start.round(),
        maxZoom: _zoomRange.end.round(),
        createdAt: DateTime.now(),
        status: OfflineRegionStatus.pending,
      );
      
      await _cacheManager.saveRegionMetadata(region);
    } catch (e) {
      debugPrint('Error creating split region: $e');
    }
  }
} 