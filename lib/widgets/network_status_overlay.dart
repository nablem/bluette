import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../services/connectivity_service.dart';

class NetworkStatusOverlay extends StatefulWidget {
  final Widget child;

  const NetworkStatusOverlay({super.key, required this.child});

  @override
  State<NetworkStatusOverlay> createState() => _NetworkStatusOverlayState();
}

class _NetworkStatusOverlayState extends State<NetworkStatusOverlay>
    with SingleTickerProviderStateMixin {
  bool _isConnected = true;
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Create slide-in animation from top
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Start periodic connectivity check
    _startConnectivityCheck();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectivityTimer?.cancel();
    super.dispose();
  }

  void _startConnectivityCheck() {
    // Check connectivity every 10 seconds
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );

    // Initial check
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final isConnected = await ConnectivityService.isConnected();

    if (isConnected != _isConnected) {
      setState(() {
        _isConnected = isConnected;
      });

      if (!isConnected) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Network status banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _offsetAnimation,
            child: Container(
              color: AppTheme.errorColor,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No internet connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _checkConnectivity,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
