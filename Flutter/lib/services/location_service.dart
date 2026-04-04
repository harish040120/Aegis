import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<bool> checkAndRequestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false; // Linux/web not supported
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Position?> getCurrentPosition() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return _fallbackPosition();
    }
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return _fallbackPosition();
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return _fallbackPosition();
    }
  }
  
  static Position _fallbackPosition() {
    return Position(
      latitude: 13.0827,
      longitude: 80.2707,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
    );
  }

  static Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.subLocality ?? ''}, ${p.locality ?? ''}'.trim();
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Check if coordinates fall within a known zone bounding box.
  /// In production these would come from the backend geofencing service.
  static String detectZoneFromCoords(double lat, double lng) {
    // Chennai zone rough bounding boxes
    // Zone 4 — Central (T. Nagar, Nungambakkam)
    if (lat >= 13.02 && lat <= 13.09 && lng >= 80.22 && lng <= 80.28) {
      return 'Zone 4 — Central';
    }
    // Zone 1 — North (Kolathur, Perambur)
    if (lat >= 13.10 && lat <= 13.20 && lng >= 80.20 && lng <= 80.27) {
      return 'Zone 1 — North';
    }
    // Zone 2 — South (Adyar, Besant Nagar)
    if (lat >= 12.98 && lat <= 13.02 && lng >= 80.24 && lng <= 80.27) {
      return 'Zone 2 — South';
    }
    // Zone 3 — East (Mylapore, Royapettah)
    if (lat >= 13.03 && lat <= 13.07 && lng >= 80.26 && lng <= 80.30) {
      return 'Zone 3 — East';
    }
    return 'Zone 5 — West';
  }

  /// Detects mock location provider (anti-spoofing layer 1).
  static Future<bool> isMockLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      return pos.isMocked;
    } catch (_) {
      return false;
    }
  }
}
