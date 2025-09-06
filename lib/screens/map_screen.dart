import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _fs = FirestoreService();
  final _auth = AuthService();

  GoogleMapController? _map;
  StreamSubscription<List<MaraaSLocation>>? _locSub;

  List<MaraaSLocation> _locations = [];
  final Set<String> _userCheckedInLocations = {};
  Set<Marker> _markers = {};

  // Center on the campus
  static const LatLng _campusCenter = LatLng(13.352685344586105, 74.7927248560112); // Example: Manipal area
  static const CameraPosition _initialCamera = CameraPosition(target: _campusCenter, zoom: 14);

  @override
  void initState() {
    super.initState();
    _locSub = _fs.locationsStream().listen((locs) {
      setState(() => _locations = locs);
      _refreshMarkers();
    });
    _loadUserCheckins();
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  double? _countToHue(int count, int capacity) {
    if (capacity <= 0) return null; // avoid division by zero
    final percent = (count / capacity) * 100;

    if (count == 0) return null; // no marker for empty
    if (percent <= 20) return BitmapDescriptor.hueGreen;
    if (percent <= 60) return BitmapDescriptor.hueYellow;
    if (percent <= 90) return BitmapDescriptor.hueOrange;
    return BitmapDescriptor.hueRed;
  }
  Future<void> _loadUserCheckins() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final active = await _fs.activeCheckinsForUser(user.uid);
    setState(() {
      _userCheckedInLocations
        ..clear()
        ..addAll(active);
    });
  }

  void _refreshMarkers() {
    final newMarkers = _locations.map((loc) {
      final c = loc.currentCount;
      final hue = _countToHue(c, loc.capacity);

      return Marker(
        markerId: MarkerId(loc.id!),
        position: LatLng(loc.lat, loc.lng),
        icon: (hue != null)
            ? BitmapDescriptor.defaultMarkerWithHue(hue)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), // grey/default for 0
        infoWindow: InfoWindow(title: loc.name, snippet: '$c people here'),
      );
    }).toSet();

    setState(() => _markers = newMarkers);
  }

  Future<void> _toggleCheckin(MaraaSLocation loc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch all active checkins for this user
    final existingCheckins = await _fs.checkinsForUser(user.uid);

    if (existingCheckins.isNotEmpty) {
      final currentLocId = existingCheckins.first['locationId'] as String;

      if (currentLocId == loc.id) {
        // ✅ Same location → Check out
        await _fs.deleteCheckin(userId: user.uid, locationId: loc.id!);
        _userCheckedInLocations.remove(loc.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Checked out from ${loc.name}')),
          );
        }
      } else {
        // ✅ Different location → Check out old, then check in new
        await _fs.deleteCheckin(userId: user.uid, locationId: currentLocId);
        await _fs.createOrUpdateCheckin(userId: user.uid, locationId: loc.id!);

        _userCheckedInLocations
          ..clear()
          ..add(loc.id!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Moved to ${loc.name}')),
          );
        }
      }
    } else {
      // ✅ No checkins yet → Check in new one
      await _fs.createOrUpdateCheckin(userId: user.uid, locationId: loc.id!);
      _userCheckedInLocations
        ..clear()
        ..add(loc.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checked in at ${loc.name}')),
        );
      }
    }

    _refreshMarkers();
  }


  Future<void> _seedLocations() async {
    final locations = <MaraaSLocation>[
      MaraaSLocation(name: 'MIT Central Library', lat: 13.351644615065558, lng: 74.79318464966113, capacity: 10),
      MaraaSLocation(name: 'Cafeteria', lat: 13.352100993465228, lng: 74.79327307984387, capacity: 8),
      MaraaSLocation(name: 'MIT Library Auditorium', lat: 13.35167498897573, lng: 74.79340185142415, capacity: 6),
      MaraaSLocation(name: 'MIT Food Court 1', lat: 13.347629387600533, lng: 74.79398186579219, capacity: 8),
      MaraaSLocation(name: 'MIT Food Court 2', lat: 13.345607252334947, lng: 74.79608645075419, capacity: 8),
      MaraaSLocation(name: 'Apoorva Mess', lat: 13.346031868206662, lng: 74.79488146272743, capacity: 4),
    ];
    await _fs.seedLocationsIfEmpty(locations);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Locations seeded!')));
    }
  }

  void _openCheckinSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _locations.length,
            itemBuilder: (context, i) {
              final loc = _locations[i];
              final isCheckedIn = _userCheckedInLocations.contains(loc.id);
              final c = loc.currentCount;

              // Dot color logic
              Color dot;
              if (c == 0) {
                dot = Colors.grey;
              } else if (c / loc.capacity <= 0.2) {
                dot = Colors.green;
              } else if (c / loc.capacity <= 0.6) {
                dot = Colors.yellow;
              } else if (c / loc.capacity <= 0.9) {
                dot = Colors.orange;
              } else {
                dot = Colors.red;
              }

              return ListTile(
                title: Text(loc.name),
                subtitle: Text('$c people here'),
                leading: CircleAvatar(backgroundColor: dot),
                trailing: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _toggleCheckin(loc);
                  },
                  child: Text(isCheckedIn ? 'Check Out' : 'Check In'),
                ),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MaraaS — Campus Heatmap'),
        actions: [
          IconButton(
            tooltip: 'Seed Locations (once)',
            onPressed: _seedLocations,
            icon: const Icon(Icons.cloud_download_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async => await _auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: _initialCamera,
        markers: _markers,
        onMapCreated: (GoogleMapController c) => _map = c,
        myLocationButtonEnabled: false,
        myLocationEnabled: false, // set true after adding geolocator permission & logic
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCheckinSheet,
        label: const Text('Check In'),
        icon: const Icon(Icons.place),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Logged in as ${user.email}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
