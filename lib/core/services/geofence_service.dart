import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class StudyZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final bool isEnabled;
  final String enterMessage;
  final String exitMessage;

  StudyZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isEnabled = true,
    this.enterMessage = "Time to study! Let's get focused. 📚",
    this.exitMessage = "Great job focusing! Take a nice break. ☕",
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isEnabled': isEnabled,
      'enterMessage': enterMessage,
      'exitMessage': exitMessage,
    };
  }

  factory StudyZone.fromMap(Map<String, dynamic> map, String docId) {
    return StudyZone(
      id: docId,
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radius: (map['radius'] as num?)?.toDouble() ?? 100.0,
      isEnabled: map['isEnabled'] ?? true,
      enterMessage: map['enterMessage'] ?? "Time to study! Let's get focused. 📚",
      exitMessage: map['exitMessage'] ?? "Great job focusing! Take a nice break. ☕",
    );
  }
}

class GeofenceService extends ChangeNotifier {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;

  GeofenceService._internal() {
    _initService();
  }

  List<StudyZone> _zones = [];
  List<StudyZone> get zones => _zones;

  final Map<String, bool> _isInsideMap = {};
  Map<String, bool> get isInsideMap => _isInsideMap;

  // Location state
  double? _currentLatitude;
  double? _currentLongitude;
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;

  bool _isSimulated = false;
  bool get isSimulated => _isSimulated;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<QuerySnapshot>? _zonesSubscription;

  Future<void> _initService() async {
    _listenToZones();
    await startLocationTracking();
  }

  void _listenToZones() {
    _zonesSubscription?.cancel();
    _zonesSubscription = FirebaseFirestore.instance
        .collection("zones")
        .snapshots()
        .listen((snapshot) {
      _zones = snapshot.docs
          .map((doc) => StudyZone.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      notifyListeners();
    });
  }

  Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<void> startLocationTracking() async {
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) return;

    _positionStreamSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (!_isSimulated) {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
        _checkLocation(position.latitude, position.longitude);
      }
    });
  }

  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
  }

  void simulateLocation(double lat, double lng) {
    _isSimulated = true;
    _currentLatitude = lat;
    _currentLongitude = lng;
    _checkLocation(lat, lng);
  }

  void clearSimulation() {
    _isSimulated = false;
    startLocationTracking();
  }

  void _checkLocation(double lat, double lng) {
    for (final zone in _zones) {
      final distance = Geolocator.distanceBetween(lat, lng, zone.latitude, zone.longitude);
      final isInside = distance <= zone.radius;
      final wasInside = _isInsideMap[zone.id] ?? false;

      if (isInside && !wasInside) {
        _isInsideMap[zone.id] = true;
        if (zone.isEnabled) {
          NotificationService().showNotification(
            id: zone.id.hashCode,
            title: "Study Zone Entered: ${zone.name} 📚",
            body: zone.enterMessage,
          );
        }
      } else if (!isInside && wasInside) {
        _isInsideMap[zone.id] = false;
        if (zone.isEnabled) {
          NotificationService().showNotification(
            id: zone.id.hashCode,
            title: "Left Study Zone: ${zone.name} ☕",
            body: zone.exitMessage,
          );
        }
      }
    }
    notifyListeners();
  }

  double? getDistanceToZone(StudyZone zone) {
    if (_currentLatitude == null || _currentLongitude == null) return null;
    return Geolocator.distanceBetween(
      _currentLatitude!,
      _currentLongitude!,
      zone.latitude,
      zone.longitude,
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _zonesSubscription?.cancel();
    super.dispose();
  }
}
