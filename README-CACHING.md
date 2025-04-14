# BOP Maps Caching Strategy

This document outlines the caching strategy used in the BOP Maps application to optimize performance and enable offline usage.

## Architecture Overview

The caching system is composed of several components:

1. **MapCacheManager** - The core service that manages the cache
2. **MapCacheManagerExtension** - Extension methods to add functionality for OSM layers
3. **OfflineRegion** - Class representing an offline map region
4. **MapSizeCalculator** - Utility for calculating map data sizes

## Cache Types

The application implements a multi-level caching strategy:

### Memory Cache

- Fast in-memory caching of recently accessed data
- Includes tiles, buildings, roads, parks, and other map elements
- Uses a key-value store where keys are generated based on data type, coordinates, and zoom level
- Optimized for quick access during map navigation
- Auto-eviction of oldest items when the cache reaches its size limit

### Disk Cache

- Persistent storage of map data on the device
- Organized by region IDs and tile coordinates
- Allows fully offline usage of previously downloaded areas
- Stores the raw data files with metadata in SharedPreferences
- Intelligently manages disk space based on user preferences

## Offline Regions

Users can download specific regions for offline use:

1. Regions are defined by bounding boxes (north, south, east, west coordinates)
2. Users can specify zoom level range (min to max)
3. The system calculates estimated download size before proceeding
4. Download status and progress are tracked and displayed to the user
5. Regions have metadata including ID, name, creation date, download date, and status

## Caching Logic

### Data Fetching Flow

1. When map data is requested, the system first checks the memory cache
2. If not found in memory, it checks the disk cache
3. If not found in the disk cache, it checks for a partial match in existing cached regions
4. If no suitable cache is found, the data is fetched from the OpenStreetMap API
5. Fetched data is stored in both memory and disk caches for future use

### Smart Region Matching

The system can determine if a requested region partially overlaps with cached regions:

- Uses a spatial indexing approach to find regions with significant overlap
- Calculates the percentage of overlap between the requested and cached regions
- Returns partial data if above a certain threshold while fetching the complete data

### Optimization Techniques

1. **Throttling** - Limits API request frequency to avoid rate limiting
2. **Preloading** - Preloads adjacent tiles and data in the background while users view the map
3. **Zoom Level Optimization** - Adapts detail level based on current zoom level
4. **Tile Simplification** - Reduces geometry complexity at lower zoom levels
5. **Cache Pruning** - Automatically removes expired or least recently used data

## Performance Considerations

- The caching system significantly reduces network requests
- Improves map rendering speed, especially for revisited areas
- Enables seamless transitions between online and offline modes
- Balances memory usage to avoid excessive RAM consumption
- Intelligently manages disk space based on device constraints

## Implementation Details

### Key Classes and Methods

#### MapCacheManager
- `initialize()` - Sets up cache directories
- `getOfflineRegions()` - Lists all downloaded regions
- `downloadRegion()` - Downloads a region for offline use
- `removeOfflineRegion()` - Deletes a cached region

#### MapCacheManagerExtension
- `generateCacheKey()` - Creates unique keys for cached data
- `getFromMemoryCache()` - Retrieves data from memory cache
- `storeInMemoryCache()` - Stores data in memory cache
- `findBestMatchingRegion()` - Finds similar regions in cache

#### MapSizeCalculator
- `calculateTileCount()` - Estimates number of tiles for a region
- `estimateSizeKB()` - Calculates download size
- `estimateDownloadTime()` - Estimates time to download based on connection speed

## Usage in OSM Layers

The OSM layer classes (buildings, roads, parks, POIs) use the caching system to efficiently render map elements:

1. Each layer checks the cache before making network requests
2. Layers adapt their rendering detail based on zoom level
3. Data is shared across layers to minimize redundant requests
4. Background fetching happens during idle periods

## Future Improvements

1. Implement predictive caching based on user movement patterns
2. Add data compression for more efficient storage
3. Implement differential updates for regions
4. Add user-configurable cache management options

---

By using this comprehensive caching strategy, BOP Maps delivers a smooth, responsive experience even with limited connectivity while preserving the rich 2.5D visual effects that make the application distinctive. 