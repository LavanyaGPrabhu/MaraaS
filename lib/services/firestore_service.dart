import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  /// Stream all locations in real-time
  Stream<List<MaraaSLocation>> locationsStream() {
    return _db.collection('locations').snapshots().map((snap) {
      return snap.docs.map((d) => MaraaSLocation.fromDoc(d)).toList();
    });
  }

  /// Seed locations if the collection is empty
  Future<void> seedLocationsIfEmpty(List<MaraaSLocation> seed) async {
    final snap = await _db.collection('locations').limit(1).get();
    if (snap.docs.isEmpty) {
      final batch = _db.batch();
      for (final loc in seed) {
        final ref = _db.collection('locations').doc();
        batch.set(ref, {
          ...loc.toMap(),
          'currentCount': 0, // initialize with count field
        });
      }
      await batch.commit();
    }
  }
  /// Get all check-ins for a user (across all locations)
  Future<List<QueryDocumentSnapshot>> checkinsForUser(String userId) async {
    final snapshot = await _db
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs;
  }
  
  /// Create a check-in (only one active per user across all locations).
  Future<void> createOrUpdateCheckin({
    required String userId,
    required String locationId,
    int expiresMinutes = 30,
  }) async {
    // First, remove any existing check-in by this user (from any location)
    final existing = await _db
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in existing.docs) {
      final oldLocId = doc['locationId'] as String;
      await doc.reference.delete();

      // decrement count in that location
      await _db.collection('locations').doc(oldLocId).update({
        'currentCount': FieldValue.increment(-1),
      });
    }

    // Now, add new check-in for this location
    final now = DateTime.now();
    await _db.collection('checkins').add({
      'userId': userId,
      'locationId': locationId,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(Duration(minutes: expiresMinutes))),
    });

    // increment live count for this location
    await _db.collection('locations').doc(locationId).update({
      'currentCount': FieldValue.increment(1),
    });
  }

  /// Delete (check-out) from a location
  Future<void> deleteCheckin({
    required String userId,
    required String locationId,
  }) async {
    final existing = await _db
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .where('locationId', isEqualTo: locationId)
        .get();

    for (var doc in existing.docs) {
      await doc.reference.delete();
    }

    await _db.collection('locations').doc(locationId).update({
      'currentCount': FieldValue.increment(-1),
    });
  }

  /// Count check-ins in the last [window] for a single location.
  /// Still useful if you want rolling-window stats instead of currentCount.
  Future<int> countRecent(String locationId, Duration window) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(window));
    final q = await _db
        .collection('checkins')
        .where('locationId', isEqualTo: locationId)
        .where('timestamp', isGreaterThan: cutoff)
        .get();
    return q.docs.length;
  }

  /// All active check-ins for a user
  Future<List<String>> activeCheckinsForUser(String userId) async {
    final now = Timestamp.fromDate(DateTime.now());
    final snap = await _db
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: now)
        .get();

    return snap.docs.map((d) => d['locationId'] as String).toList();
  }

  /// Get check-ins of a specific user at a location
  Future<List<QueryDocumentSnapshot>> checkinsForUserAtLocation(
      String userId, String locationId) async {
    final snapshot = await _db
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .where('locationId', isEqualTo: locationId)
        .get();
    return snapshot.docs;
  }
}
