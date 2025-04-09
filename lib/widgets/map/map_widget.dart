class MapWidget extends StatefulWidget {
  final MapPinData? initialSelectedPin;
  final bool enableCaching;
  final bool showControls;
  final double tiltFactor;
  final ValueChanged<BuildingData?>? onBuildingSelected;
  final ValueChanged<MapPinData?>? onPinSelected;
  final ValueChanged<LatLng>? onMapTapped;
  final ValueChanged<LatLng>? onMapLongPress;
  final bool useRealOSMData;
  final bool showWaterBodies;
  final bool showLandscapeFeatures;
  final Color waterColor;
  final Color landscapeColor;

  const MapWidget({
    Key? key,
    this.initialSelectedPin,
    this.enableCaching = true,
    this.showControls = true,
    this.tiltFactor = 0.5,
    this.onBuildingSelected,
    this.onPinSelected,
    this.onMapTapped,
    this.onMapLongPress,
    this.useRealOSMData = true,
    this.showWaterBodies = true,
    this.showLandscapeFeatures = true,
    this.waterColor = const Color(0xFF2A93D5),
    this.landscapeColor = const Color(0xFF62A87C),
  }) : super(key: key);

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  bool get _showWaterBodies => widget.showWaterBodies && widget.useRealOSMData;
  bool get _showLandscapeFeatures => widget.showLandscapeFeatures && widget.useRealOSMData;

  @override
  Widget build(BuildContext context) {
    return kIsWeb ? const LeafletMapWidget() : FlutterMapWidget(
      initialSelectedPin: widget.initialSelectedPin,
      enableCaching: widget.enableCaching,
      showControls: widget.showControls,
      tiltFactor: widget.tiltFactor,
      onBuildingSelected: widget.onBuildingSelected,
      onPinSelected: widget.onPinSelected,
      onMapTapped: widget.onMapTapped,
      onMapLongPress: widget.onMapLongPress,
      useRealOSMData: widget.useRealOSMData,
      showWaterBodies: widget.showWaterBodies,
      showLandscapeFeatures: widget.showLandscapeFeatures,
      waterColor: widget.waterColor,
      landscapeColor: widget.landscapeColor,
    );
  }
} 