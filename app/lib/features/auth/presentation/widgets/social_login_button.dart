import 'package:flutter/material.dart';

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  factory SocialLoginButton.google({required VoidCallback onPressed}) {
    return SocialLoginButton(
      label: '使用 Google 登入',
      icon: const Icon(Icons.g_mobiledata, size: 24),
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
    );
  }

  factory SocialLoginButton.apple({required VoidCallback onPressed}) {
    return SocialLoginButton(
      label: '使用 Apple 登入',
      icon: const Icon(Icons.apple, size: 24),
      onPressed: onPressed,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
