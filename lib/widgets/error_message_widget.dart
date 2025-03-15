import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_theme.dart';
import '../utils/network_error_handler.dart';
import 'custom_button.dart';

class ErrorMessageWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isNetworkError;
  final bool showRetryButton;
  final bool animate;

  /// Creates an error message widget with optional retry button
  ///
  /// [message] is the error message to display
  /// [onRetry] is the callback when retry button is pressed
  /// [isNetworkError] determines if this is a network-related error
  /// [showRetryButton] determines if the retry button should be shown
  /// [animate] determines if the widget should animate when shown
  const ErrorMessageWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.isNetworkError = false,
    this.showRetryButton = true,
    this.animate = true,
  });

  /// Factory constructor to create from an exception
  factory ErrorMessageWidget.fromError(
    dynamic error, {
    Key? key,
    VoidCallback? onRetry,
    bool showRetryButton = true,
    bool animate = true,
  }) {
    final isNetworkError = NetworkErrorHandler.isNetworkError(error);
    final friendlyMessage = NetworkErrorHandler.getUserFriendlyMessage(error);

    return ErrorMessageWidget(
      key: key,
      message: friendlyMessage,
      onRetry: onRetry,
      isNetworkError: isNetworkError,
      showRetryButton: showRetryButton,
      animate: animate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget errorWidget = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isNetworkError ? Icons.wifi_off : Icons.error_outline,
                color: AppTheme.errorColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTheme.smallTextStyle.copyWith(
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
            ],
          ),
          if (showRetryButton && onRetry != null) ...[
            const SizedBox(height: 16),
            CustomButton(
              text: 'Try Again',
              onPressed: onRetry!,
              icon: Icons.refresh,
              backgroundColor: AppTheme.errorColor,
              width: double.infinity,
            ),
          ],
        ],
      ),
    );

    return animate ? errorWidget.animate().shake(delay: 100.ms) : errorWidget;
  }
}
