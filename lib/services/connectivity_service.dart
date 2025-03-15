import 'dart:io';
import 'dart:async';

class ConnectivityService {
  /// Checks if the device has an active internet connection
  /// Returns true if connected, false otherwise
  static Future<bool> isConnected() async {
    try {
      // Try to connect to a reliable host
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Waits for internet connection to be available
  /// Returns true when connected, false if timeout reached
  static Future<bool> waitForConnection({int timeoutSeconds = 30}) async {
    final completer = Completer<bool>();

    // Set a timeout
    Timer(Duration(seconds: timeoutSeconds), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    // Check connection periodically
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (await isConnected()) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    return completer.future;
  }
}
