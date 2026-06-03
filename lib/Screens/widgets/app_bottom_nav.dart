import 'dart:ui';
import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  final Color backgroundColor;
  final Color selectedItemColor;
  final Color unselectedItemColor;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.backgroundColor,
    this.selectedItemColor = Colors.white,
    this.unselectedItemColor = Colors.white54,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.78),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  currentIndex: currentIndex,
                  selectedItemColor: selectedItemColor,
                  unselectedItemColor: unselectedItemColor,
                  selectedFontSize: 12,
                  unselectedFontSize: 12,
                  showUnselectedLabels: true,
                  onTap: onTap,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search_outlined),
                      activeIcon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.info_outline),
                      activeIcon: Icon(Icons.info),
                      label: 'About',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.playlist_play_outlined),
                      activeIcon: Icon(Icons.playlist_play),
                      label: 'My List',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.more_horiz),
                      activeIcon: Icon(Icons.more_horiz),
                      label: 'More',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}