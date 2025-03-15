import 'dart:io';

class NetworkErrorHandler {
  /// Converts technical error messages to user-friendly messages
  /// Returns a user-friendly error message based on the exception
  static String getUserFriendlyMessage(dynamic error) {
    // Handle SocketException which indicates no internet connection
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Handle timeout errors
    if (error.toString().contains('timeout') ||
        error.toString().contains('timed out')) {
      return 'Connection timed out. Please try again later.';
    }

    // Handle Supabase API key exposure in error messages
    if (error.toString().contains('supabase') &&
        (error.toString().contains('key') ||
            error.toString().contains('url'))) {
      return 'Unable to connect to the server. Please try again later.';
    }

    // Handle general server errors
    if (error.toString().contains('500') ||
        error.toString().contains('server error')) {
      return 'Server error. Our team has been notified and is working on it.';
    }

    // Handle authentication errors
    if (error.toString().contains('auth') ||
        error.toString().contains('authentication') ||
        error.toString().contains('unauthorized')) {
      return 'Authentication error. Please log in again.';
    }

    // Default error message for unhandled cases
    return 'An error occurred. Please try again later.';
  }

  /// Checks if the error is related to network connectivity
  static bool isNetworkError(dynamic error) {
    return error is SocketException ||
        error.toString().contains('timeout') ||
        error.toString().contains('timed out');
  }
}
