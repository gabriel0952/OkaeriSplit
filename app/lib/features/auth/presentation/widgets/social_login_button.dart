import 'package:flutter/material.dart';

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;

  factory SocialLoginButton.google({
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SocialLoginButton(
      label: '使用 Google 登入',
      icon: const Icon(Icons.g_mobiledata, size: 24),
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      isLoading: isLoading,
    );
  }

  factory SocialLoginButton.apple({
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SocialLoginButton(
      label: '使用 Apple 登入',
      icon: const Icon(Icons.apple, size: 24),
      onPressed: onPressed,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      isLoading: isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : icon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor?.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
