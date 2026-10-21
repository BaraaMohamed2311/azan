import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'athkar_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'qibla_screen.dart';
import 'quran_library_screen.dart';

/// Ported from app/(tabs)/_layout.tsx — bottom navigation shell.
/// Order matches the original (RTL renders first item at the right).
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  static void switchTo(BuildContext context, int index) {
    context.findAncestorStateOfType<RootShellState>()?.goTo(index);
  }

  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> {
  // The original app opens on the الرئيسية (home) tab.
  int _index = 4;

  void goTo(int index) => setState(() => _index = index);

  static const _screens = <Widget>[
    MoreScreen(),
    AthkarScreen(),
    QiblaScreen(),
    QuranLibraryScreen(),
    HomeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: colors.card,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
              fontFamily: 'Inter',
              fontFamilyFallback: const ['NotoSansArabic'],
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          height: 62,
          destinations: [
            _dest(context, Icons.grid_view_outlined, 'المزيد', 0),
            _dest(context, Icons.eco_outlined, 'الأذكار', 1),
            _dest(context, Icons.explore_outlined, 'القبلة', 2),
            _dest(context, Icons.menu_book_outlined, 'القرآن', 3),
            _dest(context, Icons.access_time_outlined, 'الرئيسية', 4),
          ],
        ),
      ),
    );
  }

  NavigationDestination _dest(
      BuildContext context, IconData icon, String label, int tabIndex) {
    final colors = AppColors.of(context);
    final active = _index == tabIndex;
    return NavigationDestination(
      icon: Icon(icon,
          size: 22,
          color: active ? colors.primary : colors.mutedForeground),
      selectedIcon:
          Icon(icon, size: 22, color: active ? colors.primary : colors.mutedForeground),
      label: label,
    );
  }
}
