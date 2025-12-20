import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  // 🔹 Accept route data passed from BusScheduleScreen
  final Map<String, dynamic>? routeData;

  const MapScreen({super.key, this.routeData});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // 🔹 Dynamic Route Data
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _stops = [];

  // Map state
  LatLng _center = const LatLng(8.5241, 76.9366); // Default (Trivandrum/Kazakuttam area)
  double _zoom = 13.0;

  // Device location
  Position? _devicePosition;
  LatLng? _deviceLatLng;

  // Stream subscription
  StreamSubscription<Position>? _positionStreamSub;
  
  // Tapped Point
  LatLng? _tappedPoint;

  @override
  void initState() {
    super.initState();
    _loadRouteData(); // 🔹 Load data from Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocationTracking());
  }

  // 🔹 Parse Firestore Data into Map Points
  void _loadRouteData() {
    if (widget.routeData != null && widget.routeData!['stops'] != null) {
      List<dynamic> rawStops = widget.routeData!['stops'];
      
      List<LatLng> points = [];
      List<Map<String, dynamic>> cleanStops = [];

      for (var stop in rawStops) {
        // Ensure lat/lng exist and parse them safely
        if (stop['lat'] != null && stop['lng'] != null) {
          try {
            double lat = double.parse(stop['lat'].toString());
            double lng = double.parse(stop['lng'].toString());
            LatLng point = LatLng(lat, lng);
            
            points.add(point);
            cleanStops.add({
              "name": stop['stopName'] ?? "Stop",
              "time": stop['time'] ?? "--:--",
              "latlng": point,
            });
          } catch (e) {
            debugPrint("Error parsing stop data: $e");
          }
        }
      }

      if (mounted) {
        setState(() {
          _routePoints = points;
          _stops = cleanStops;
          // Center map on the first stop if available
          if (_routePoints.isNotEmpty) {
            _center = _routePoints.first; 
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  // === LOCATION HANDLING ===
  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location services disabled.'),
          action: SnackBarAction(
            label: 'Enable',
            onPressed: () => Geolocator.openLocationSettings(),
          ),
        ),
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    _startPositionStream();
  }

  void _startPositionStream() {
    _positionStreamSub?.cancel();
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position pos) {
        if (mounted) {
          setState(() {
            _devicePosition = pos;
            _deviceLatLng = LatLng(pos.latitude, pos.longitude);
          });
        }
      },
      onError: (e) => debugPrint(e.toString()),
    );
  }

  // 🔹 Build Markers (Stops + User Location)
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // 1. Bus Stops (Red Pins)
    for (int i = 0; i < _stops.length; i++) {
      markers.add(Marker(
        point: _stops[i]['latlng'],
        width: 40,
        height: 40,
        builder: (_) => const Icon(Icons.location_on, color: Colors.red, size: 30),
      ));
    }

    // 2. User Location (Blue Dot)
    if (_deviceLatLng != null) {
      markers.add(Marker(
        point: _deviceLatLng!,
        width: 48,
        height: 48,
        builder: (_) => const Icon(Icons.my_location, size: 30, color: Colors.blue),
      ));
    }

    return markers;
  }

  void _onMapTap(TapPosition tp, LatLng latlng) {
    setState(() => _tappedPoint = latlng);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // 🔹 THEME COLORS
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Background: Black (Dark Mode) or #8E9991 (Light Mode)
    final Color bgColor = isDarkMode ? Colors.black : const Color(0xFF8E9991);
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    
    // Bottom Sheet (Timeline) Colors
    final Color sheetColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final Color sheetText = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.routeData?['busNumber'] ?? 'Bus Tracker (OSM)',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          // 🔹 1. TOP HALF: MAP
          Expanded(
            flex: 1, // 50% height
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(center: _center, zoom: _zoom, onTap: _onMapTap),
                      children: [
                        TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c']),
                        
                        // Draw Route Line
                        if (_routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(points: _routePoints, strokeWidth: 4.0, color: Colors.blueAccent),
                            ],
                          ),
                        
                        MarkerLayer(markers: _buildMarkers()),
                      ],
                    ),
                    
                    // Zoom Controls inside Map
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            heroTag: "zoomIn",
                            onPressed: () {
                              _zoom++;
                              _mapController.move(_mapController.center, _zoom);
                            },
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.add, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: "zoomOut",
                            onPressed: () {
                              _zoom--;
                              _mapController.move(_mapController.center, _zoom);
                            },
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.remove, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔹 2. BOTTOM HALF: TIMELINE (Stops)
          Expanded(
            flex: 1, // 50% height
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: sheetColor, // White or Dark Grey
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Title Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.routeData?['routeTitle'] ?? "Route Details",
                              style: TextStyle(color: sheetText, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (_stops.isNotEmpty)
                              Text("${_stops.length} Stops", style: TextStyle(color: sheetText.withOpacity(0.6))),
                          ],
                        ),
                        Icon(Icons.share, color: sheetText.withOpacity(0.6)),
                      ],
                    ),
                  ),
                  Divider(color: Colors.grey.withOpacity(0.3), height: 1),

                  // Stops List (Timeline)
                  Expanded(
                    child: _stops.isEmpty
                        ? Center(child: Text("No route stops available.", style: TextStyle(color: sheetText)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            itemCount: _stops.length,
                            itemBuilder: (context, index) {
                              final stop = _stops[index];
                              final isLast = index == _stops.length - 1;

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Time
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        stop['time'] ?? "--:--",
                                        style: TextStyle(color: sheetText, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),

                                    // Line & Dot
                                    Column(
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent, // Active color
                                            shape: BoxShape.circle,
                                            border: Border.all(color: sheetColor, width: 2),
                                          ),
                                        ),
                                        if (!isLast)
                                          Expanded(
                                            child: Container(
                                              width: 2,
                                              color: Colors.grey.withOpacity(0.3),
                                            ),
                                          ),
                                      ],
                                    ),

                                    const SizedBox(width: 15),

                                    // Stop Details
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 30),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              stop['name'] ?? "Stop Name",
                                              style: TextStyle(color: sheetText, fontSize: 16, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Stop #${index + 1}",
                                              style: TextStyle(color: sheetText.withOpacity(0.5), fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}