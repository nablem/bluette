import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';

class LocationService {
  // Request location permission and get current position
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      print('Location services are disabled.');
      return null;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied
        print('Location permissions are denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately
      print(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
      return null;
    }

    // When we reach here, permissions are granted and we can get the position
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // Update user location in Supabase
  static Future<void> updateUserLocation() async {
    try {
      final position = await getCurrentPosition();
      if (position != null) {
        await SupabaseService.updateLocation(
          position.latitude,
          position.longitude,
        );
        print('Location updated: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('Error updating user location: $e');
    }
  }
}
