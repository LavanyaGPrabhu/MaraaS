import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Stream<List<MaraaSLocation>> locationsStream() {
    return _db.collection('locations').snapshots().map((snap) {
      return snap.docs.map((d) => MaraaSLocation.fromDoc(d)).toList();
    });
  }

  Future<void> seedLocationsIfEmpty(List<MaraaSLocation> seed) async {
    final snap = await _db.collection('locations').limit(1).get();
    if (snap.docs.isEmpty) {
      final batch = _db.batch();
      for (final loc in seed) {
        final ref = _db.collection('locations').doc();
        batch.set(ref, loc.toMap());
      }
      await batch.commit();
    }
  }

  Future<void> createCheckin({required String userId, required String locationId, int expiresMinutes = 30}) async {
    final now = DateTime.now();
    await _db.collection('checkins').add({
      'userId': userId,
      'locationId': locationId,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(Duration(minutes: expiresMinutes))),
    });
  }

  /// Count check-ins in the last [window] for a single location.
  Future<int> countRecent(String locationId, Duration window) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(window));
    final q = await _db.collection('checkins')
      .where('locationId', isEqualTo: locationId)
      .where('timestamp', isGreaterThan: cutoff)
      .get();
    return q.docs.length;
  }

  Future<List<QueryDocumentSnapshot>> checkinsForUserAtLocation(String userId, String locationId) async {
    final snapshot = await _db.collection('checkins')
        .where('userId', isEqualTo: userId)
        .where('locationId', isEqualTo: locationId)
        .get();
    return snapshot.docs;
  }

  Future<void> deleteCheckin({required String userId, required String locationId}) async {
    final existing = await _db.collection('checkins')
        .where('userId', isEqualTo: userId)
        .where('locationId', isEqualTo: locationId)
        .get();

    for (var doc in existing.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> createOrUpdateCheckin({required String userId, required String locationId, int expiresMinutes = 30}) async {
    final existing = await _db.collection('checkins')
        .where('userId', isEqualTo: userId)
        .where('locationId', isEqualTo: locationId)
        .get();

    if (existing.docs.isEmpty) {
      // Create new check-in
      final now = DateTime.now();
      await _db.collection('checkins').add({
        'userId': userId,
        'locationId': locationId,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(Duration(minutes: expiresMinutes))),
      });
    } else {
      // Update timestamp (refresh check-in)
      for (var doc in existing.docs) {
        await doc.reference.update({
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(minutes: expiresMinutes))),
        });
      }
    }
  }
}

