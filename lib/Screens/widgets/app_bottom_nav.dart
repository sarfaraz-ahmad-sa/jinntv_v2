import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Netflix-style bottom navigation bar
// Custom widget — no BottomNavigationBar overhead
// ─────────────────────────────────────────────

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color backgroundColor;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor = const Color(0xFF0A1018),
  });

  static const _items = [
    _NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home_rounded,          label: 'Home'),
    _NavItem(icon: Icons.search_rounded,      activeIcon: Icons.search_rounded,        label: 'Search'),
    _NavItem(icon: Icons.explore_outlined,    activeIcon: Icons.explore_rounded,       label: 'Explore'),
    _NavItem(icon: Icons.bookmarks_outlined, activeIcon: Icons.bookmarks_rounded,     label: 'My Space'),
    _NavItem(icon: Icons.menu_rounded,        activeIcon: Icons.menu_rounded,          label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        color: const Color(0xFF0A1018),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_items.length, (i) {
                return Expanded(
                  child: _NavTile(
                    item: _items[i],
                    isSelected: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single tab item ──────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Active indicator dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: isSelected ? 20 : 0,
            height: 2,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // Icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              key: ValueKey(isSelected),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          // Label
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
