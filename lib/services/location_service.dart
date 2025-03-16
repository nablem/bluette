import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';

enum LocationStatus {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  permissionGranted,
  error,
}

class LocationService {
  // Request location permission and get current position
  static Future<LocationStatus> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled
        print('Location services are disabled.');
        return LocationStatus.serviceDisabled;
      }

      // Check location permission
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Request permission using native dialog
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permission denied
          print('Location permissions are denied');
          return LocationStatus.permissionDenied;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately
        print(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
        return LocationStatus.permissionDeniedForever;
      }

      // When we reach here, permissions are granted
      return LocationStatus.permissionGranted;
    } catch (e) {
      print('Error requesting location permission: $e');
      return LocationStatus.error;
    }
  }

  // Check current location status without requesting permission
  static Future<LocationStatus> checkLocationStatus() async {
    try {
      // Test if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return LocationStatus.serviceDisabled;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return LocationStatus.permissionDenied;
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return LocationStatus.permissionDeniedForever;
      }

      // When we reach here, permissions are granted
      return LocationStatus.permissionGranted;
    } catch (e) {
      print('Error checking location status: $e');
      return LocationStatus.error;
    }
  }

  // Get current position if permission is granted
  static Future<Position?> getCurrentPosition() async {
    try {
      final status = await requestLocationPermission();

      if (status == LocationStatus.permissionGranted) {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } else {
        print('Cannot get position, location status: $status');
        return null;
      }
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // Update user location in Supabase
  static Future<bool> updateUserLocation() async {
    try {
      final position = await getCurrentPosition();
      if (position != null) {
        await SupabaseService.updateLocation(
          position.latitude,
          position.longitude,
        );
        print('Location updated: ${position.latitude}, ${position.longitude}');
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating user location: $e');
      return false;
    }
  }

  // Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // Open app settings when permission is denied forever
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  // Open location settings when location service is disabled
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
