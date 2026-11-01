import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/domain.dart';
import '../../core/state.dart';

/// Each branch owns a navigator and stays mounted when another tab is selected.
class AppTabShell extends ConsumerWidget {
  const AppTabShell({super.key, required this.navigation});
  final StatefulNavigationShell navigation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tech =
        ref.watch(accountProvider).asData?.value?.role ==
            AccountRole.technician ||
        (!production && ref.watch(flowProvider).role == AccountRole.technician);
    final branches = tech ? [5, 6, 7, 8, 9] : [0, 1, 2, 3, 4];
    final selected = branches.indexOf(navigation.currentIndex);
    return Scaffold(
      body: navigation,
      bottomNavigationBar: selected < 0
          ? null
          : SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
                ),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: NavigationBar(
                      height: 68,
                      backgroundColor: Colors.white,
                      indicatorColor: const Color(0xFFFFECDC),
                      selectedIndex: selected,
                      onDestinationSelected: (index) {
                        if (index != selected) {
                          navigation.goBranch(branches[index]);
                        }
                      },
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: tech ? 'Jobs' : 'Bookings',
                        ),
                        NavigationDestination(
                          icon: Icon(
                            tech ? Icons.badge_outlined : Icons.search,
                          ),
                          label: tech ? 'ID Card' : 'Explore',
                        ),
                        NavigationDestination(
                          icon: Icon(
                            tech
                                ? Icons.account_balance_wallet_outlined
                                : Icons.chat_bubble_outline,
                          ),
                          label: tech ? 'Earnings' : 'Chat',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
