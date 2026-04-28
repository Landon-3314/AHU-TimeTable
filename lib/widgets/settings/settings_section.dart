import 'package:flutter/material.dart';

import '../common/app_ui.dart';

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppSectionTitle(title: title);
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
