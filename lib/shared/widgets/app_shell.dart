import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/core/router/app_route.dart';
import 'package:kawai_notes/core/router/app_router_provider.dart';

class AppShellBody extends ConsumerWidget {
  const AppShellBody({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final delegate = ref.read(routerDelegateProvider);
        final handled = await delegate.popRoute();
        if (!handled) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: AppBottomNav(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) {
            navigationShell.onSwitchBranch(index);
          },
        ),
      ),
    );
  }
}

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
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.note_alt_outlined),
          selectedIcon: const Icon(Icons.note_alt),
          label: context.l10n.sharedMyNotes,
        ),
        NavigationDestination(
          icon: const Icon(Icons.check_circle_outline),
          selectedIcon: const Icon(Icons.check_circle),
          label: context.l10n.sharedTasks,
        ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz_outlined),
          selectedIcon: const Icon(Icons.more_horiz),
          label: context.l10n.sharedSettings,
        ),
      ],
    );
  }
}
