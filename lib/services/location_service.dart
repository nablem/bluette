import 'package:flutter/material.dart';
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
      // Request permission
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
    final status = await requestLocationPermission();
    return status == LocationStatus.permissionGranted;
  }

  // Show location permission dialog with no dismiss option
  static Future<LocationStatus> showLocationPermissionDialog(
    BuildContext context,
  ) async {
    final status = await requestLocationPermission();

    if (context.mounted && status != LocationStatus.permissionGranted) {
      String title = '';
      String message = '';

      switch (status) {
        case LocationStatus.serviceDisabled:
          title = 'Location Services Disabled';
          message =
              'Please enable location services in your device settings to use the Explore feature.';
          break;
        case LocationStatus.permissionDenied:
          title = 'Location Permission Required';
          message =
              'This app needs access to your location to show you nearby profiles. Please grant location permission to continue.';
          break;
        case LocationStatus.permissionDeniedForever:
          title = 'Location Permission Permanently Denied';
          message =
              'Please enable location permissions in your device settings to use the Explore feature.';
          break;
        case LocationStatus.error:
          title = 'Location Error';
          message = 'An error occurred while accessing your location.';
          break;
        case LocationStatus.permissionGranted:
          // Permission granted, no need to show dialog
          break;
      }

      if (title.isNotEmpty) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      // If permission was denied, try requesting again
                      if (status == LocationStatus.permissionDenied) {
                        await requestLocationPermission();
                      } else if (status == LocationStatus.serviceDisabled ||
                          status == LocationStatus.permissionDeniedForever) {
                        // Open app settings if permission was denied forever or location services are disabled
                        await Geolocator.openAppSettings();
                        // For location services disabled, we could also use Geolocator.openLocationSettings()
                      }
                    },
                    child: const Text('Settings'),
                  ),
                ],
              ),
        );
      }
    }

    return status;
  }

  // Helper method to show dialog
  static void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
