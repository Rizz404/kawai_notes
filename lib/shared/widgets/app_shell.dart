import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';

/// Komponen wrapper untuk bagian body dari navigasi shell utama aplikasi.
class AppShellBody extends StatelessWidget {
  /// Konstruktor dasar dari komponen AppShellBody.
  const AppShellBody({required this.child, super.key});

  /// Widget children yang akan dirender di bagian body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Komponen widget bottom navigation bar utama aplikasi.
class AppBottomNav extends StatelessWidget {
  /// Konstruktor dasar dari komponen AppBottomNav.
  const AppBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  /// Indeks tab yang sedang aktif atau dipilih saat ini.
  final int currentIndex;

  /// Fungsi callback yang dipanggil ketika sebuah tab ditekan.
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: context.colors.surface,
      indicatorColor: context.colorScheme.primaryContainer,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
