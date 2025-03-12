import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isDisabled;
  final double width;
  final IconData? icon;
  final Color? backgroundColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDisabled = false,
    this.width = double.infinity,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    ButtonStyle buttonStyle;

    if (isOutlined) {
      buttonStyle = AppTheme.secondaryButtonStyle;
    } else if (backgroundColor != null) {
      buttonStyle = ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 2,
      );
    } else {
      buttonStyle = AppTheme.primaryButtonStyle;
    }

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: (isLoading || isDisabled) ? null : onPressed,
        style: buttonStyle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child:
              isLoading
                  ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: AppTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              isOutlined ? AppTheme.primaryColor : Colors.white,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Widget icon;
  final bool isLoading;

  const SocialButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          elevation: 0,
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 3,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: AppTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
