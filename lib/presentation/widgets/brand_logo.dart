import 'package:flutter/material.dart';

/// Displays the SiteShinn brand mark with corners rounded cleanly inside the UI.
class BrandLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;

  const BrandLogo({
    super.key,
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.26;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Transform.scale(
          // Slight scale trims the dark outer bezel on siteshinn-logo.png.
          scale: 1.07,
          child: Image.asset(
            'assets/icon/siteshinn-logo.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
