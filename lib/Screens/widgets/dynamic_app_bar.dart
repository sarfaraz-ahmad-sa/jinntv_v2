import 'package:flutter/material.dart';

class DynamicAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final String? logoPath;

  const DynamicAppBar({
    super.key,
    required this.title,
    this.logoPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.appBarTheme.backgroundColor,
      elevation: 0,
      centerTitle: true,
            title: Image.asset('assets/images/jinn-tv-logo.png', height: 42),

    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
