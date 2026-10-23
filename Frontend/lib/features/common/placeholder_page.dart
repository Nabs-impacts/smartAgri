import 'package:flutter/material.dart';

import '../../design_system/tokens.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(title, style: AppTextStyles.headline)),
    );
  }
}
