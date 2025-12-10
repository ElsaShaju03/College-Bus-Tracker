// lib/screens/mapscreen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // Example route / stops — keep if you need
  final List<LatLng> _routePoints = <LatLng>[
    const LatLng(10.8505, 76.2711),
    const LatLng(10.8520, 76.2730),
    const LatLng(10.8548, 76.2765),
  ];

  // Map state
  LatLng _center = const LatLng(10.8505, 76.2711);
  double _zoom = 14.0;

  // Device location
  Position? _devicePosition;
  LatLng? _deviceLatLng;

  // Tapped point
  LatLng? _tappedPoint;

  // Stream subscription
  StreamSubscription<Position>? _positionStreamSub;

  // UI flags
  bool _locating = false;
  bool _followDevice = true; // if true map pans to device each update

  @override
  void initState() {
    super.initState();
    // Start permission check and stream
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocationTracking());
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  // === LOCATION: permission/service handling + start stream ===
  Future<void> _initLocationTracking() async {
    // 1) Ensure location services enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // show prompt to enable
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location services are disabled. Please enable GPS.'),
          action: SnackBarAction(
            label: 'Open settings',
            onPressed: () => Geolocator.openLocationSettings(),
          ),
        ),
      );
      // still continue to request permission (user might enable)
    }

    // 2) Request/check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      // Permission denied (but not permanently)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location permission denied. Tap Locate to request again.'),
          action: SnackBarAction(
            label: 'Request',
            onPressed: () => _initLocationTracking(),
          ),
        ),
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      // Permanently denied
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location permission permanently denied. Open app settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => Geolocator.openAppSettings(),
          ),
        ),
      );
      return;
    }

    // 3) Start the position stream with high accuracy
    _startPositionStream();
  }

  void _startPositionStream() {
    // cancel existing if present
    _positionStreamSub?.cancel();

    // Configure settings:
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // highest
      distanceFilter: 0, // get updates even with small movement; set to >0 to reduce noise
      timeLimit: null,
    );

    // subscribe
    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position pos) {
        // update state
        _devicePosition = pos;
        _deviceLatLng = LatLng(pos.latitude, pos.longitude);

        // If first fix (or follow enabled), move map
        if (_followDevice) {
          // animate move - flutter_map doesn't natively animate but move is okay
          _mapController.move(_deviceLatLng!, 17);
          _center = _deviceLatLng!;
          _zoom = 17;
        }

        if (mounted) setState(() {});
      },
      onError: (e) {
        debugPrint('POSITION STREAM ERROR: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location stream error: $e')));
        }
      },
      cancelOnError: true,
    );

    // Also get an immediate current position to populate UI quickly
    _fetchCurrentOnce();
  }

  Future<void> _fetchCurrentOnce() async {
    setState(() => _locating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation, timeLimit: const Duration(seconds: 10));
      _devicePosition = pos;
      _deviceLatLng = LatLng(pos.latitude, pos.longitude);
      if (_followDevice && _deviceLatLng != null) {
        _mapController.move(_deviceLatLng!, 17);
        _center = _deviceLatLng!;
        _zoom = 17;
      }
      setState(() {});
    } catch (e) {
      debugPrint('fetchCurrentOnce error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching location: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // Manual one-time locate (tap Locate FAB)
  Future<void> _locateOnceAndCenter() async {
    setState(() => _locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        }
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location services disabled'),
              action: SnackBarAction(label: 'Enable', onPressed: () => Geolocator.openLocationSettings()),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation, timeLimit: const Duration(seconds: 10));
      _devicePosition = pos;
      _deviceLatLng = LatLng(pos.latitude, pos.longitude);
      if (_deviceLatLng != null) {
        _mapController.move(_deviceLatLng!, 17);
        _center = _deviceLatLng!;
        _zoom = 17;
      }
      setState(() {});
    } catch (e) {
      debugPrint('locateOnce error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // Fit bounds
  void _fitAll() {
    final List<LatLng> all = <LatLng>[];
    all.addAll(_routePoints);
    if (_deviceLatLng != null) all.add(_deviceLatLng!);
    if (_tappedPoint != null) all.add(_tappedPoint!);
    if (all.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(all);
    _mapController.fitBounds(bounds, options: const FitBoundsOptions(padding: EdgeInsets.all(48)));
  }

  void _onMapTap(TapPosition tp, LatLng latlng) {
    setState(() => _tappedPoint = latlng);
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final lat = latlng.latitude.toStringAsFixed(6);
        final lng = latlng.longitude.toStringAsFixed(6);
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tapped location', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Lat: $lat'),
            Text('Lng: $lng'),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '$lat,$lng'));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied coordinates')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _mapController.move(latlng, _mapController.zoom);
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Center here'),
              ),
            ]),
          ]),
        );
      },
    );
  }

  // Build markers
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // route points
    for (var p in _routePoints) {
      markers.add(Marker(point: p, width: 30, height: 30, builder: (_) => const Icon(Icons.location_on, color: Colors.green)));
    }

    // device pointer (blue pin) with anchor at bottom
    if (_deviceLatLng != null) {
      markers.add(Marker(
        point: _deviceLatLng!,
        width: 48,
        height: 48,
        builder: (_) => const Icon(Icons.location_on, size: 44, color: Colors.blue),
        anchorPos: AnchorPos.align(AnchorAlign.bottom),
      ));
    }

    // tapped
    if (_tappedPoint != null) {
      markers.add(Marker(point: _tappedPoint!, width: 40, height: 40, builder: (_) => const Icon(Icons.place, color: Colors.orange)));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final markers = _buildMarkers();

    return Scaffold(
      appBar: AppBar(title: const Text('Bus Tracker (OSM)'), backgroundColor: const Color(0xFF010429)),
      body: Stack(children: [
        Column(children: [
          Container(
            height: screenHeight * 0.5,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black26, width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(center: _center, zoom: _zoom, maxZoom: 19, onTap: _onMapTap),
                children: [
                  TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c']),
                  // accuracy circle if available
                  if (_deviceLatLng != null && _devicePosition != null)
                    CircleLayer(circles: [
                      CircleMarker(point: _deviceLatLng!, radius: _devicePosition!.accuracy, useRadiusInMeter: true, color: Colors.blue.withOpacity(0.15), borderColor: Colors.blue.withOpacity(0.4), borderStrokeWidth: 1),
                    ]),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
          // info panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(children: [
              if (_devicePosition != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.my_location, color: Colors.blue),
                    title: Text('${_devicePosition!.latitude.toStringAsFixed(6)}, ${_devicePosition!.longitude.toStringAsFixed(6)}'),
                    subtitle: Text('Accuracy: ${_devicePosition!.accuracy.toStringAsFixed(1)} m'),
                    trailing: IconButton(icon: const Icon(Icons.center_focus_strong), onPressed: () {
                      if (_deviceLatLng != null) _mapController.move(_deviceLatLng!, 17);
                    }),
                  ),
                )
              else
                Card(child: ListTile(leading: const Icon(Icons.info_outline), title: const Text('Device location not set'), subtitle: const Text('Tap Locate to get current coordinates'))),
              const SizedBox(height: 8),
              if (_tappedPoint != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.place, color: Colors.orange),
                    title: Text('${_tappedPoint!.latitude.toStringAsFixed(6)}, ${_tappedPoint!.longitude.toStringAsFixed(6)}'),
                    trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${_tappedPoint!.latitude},${_tappedPoint!.longitude}'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied tapped coordinates')));
                    }),
                  ),
                ),
            ]),
          ),
        ]),
        // zoom controls
        Positioned(right: 18, top: 26, child: Column(children: [
          FloatingActionButton.small(heroTag: 'zoomIn', onPressed: () {
            _zoom = (_zoom + 1).clamp(3.0, 19.0);
            _mapController.move(_mapController.center, _zoom);
            setState(() {});
          }, backgroundColor: const Color(0xFFFCC203), child: const Icon(Icons.add, color: Color(0xFF010429))),
          const SizedBox(height: 8),
          FloatingActionButton.small(heroTag: 'zoomOut', onPressed: () {
            _zoom = (_zoom - 1).clamp(3.0, 19.0);
            _mapController.move(_mapController.center, _zoom);
            setState(() {});
          }, backgroundColor: const Color(0xFFFCC203), child: const Icon(Icons.remove, color: Color(0xFF010429))),
        ])),
        // locate / fit / follow toggles
        Positioned(right: 18, bottom: 18, child: Column(mainAxisSize: MainAxisSize.min, children: [
          FloatingActionButton(heroTag: 'locate', onPressed: _locating ? null : _locateOnceAndCenter, backgroundColor: const Color(0xFFFCC203), child: _locating ? const CircularProgressIndicator(color: Color(0xFF010429)) : const Icon(Icons.my_location, color: Color(0xFF010429))),
          const SizedBox(height: 8),
          FloatingActionButton(heroTag: 'fitAll', onPressed: _fitAll, backgroundColor: const Color(0xFFFCC203), child: const Icon(Icons.fit_screen, color: Color(0xFF010429))),
          const SizedBox(height: 8),
          FloatingActionButton.small(heroTag: 'follow', onPressed: () {
            setState(() => _followDevice = !_followDevice);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_followDevice ? 'Follow ON' : 'Follow OFF')));
          }, backgroundColor: _followDevice ? Colors.green : Colors.grey, child: Icon(_followDevice ? Icons.follow_the_signs : Icons.follow_the_signs_outlined, color: Colors.white)),
        ])),
      ]),
      backgroundColor: const Color(0xFF010429),
    );
  }
}
