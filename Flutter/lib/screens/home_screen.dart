// REPLACES your current home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';

import 'chat_screen.dart';
import 'dashboard_tab.dart';
import 'alerts_tab.dart';
import 'coverage_tab.dart';
import 'payouts_tab.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _idx;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialTab;
  }

  final _tabs = const [
    DashboardTab(),
    AlertsTab(),
    CoverageTab(),
    PayoutsTab()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _tabs[_idx],

      /// 🔽 GUIDEWIRE NAV
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Coverage'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Payouts'),
        ],
      ),

      /// 🤖 CHAT
      floatingActionButton: Consumer<AegisProvider>(
        builder: (_, prov, __) {
          if (!prov.isLoggedIn) return const SizedBox();

          return FloatingActionButton.extended(
            backgroundColor: AppColors.blue,
            icon: const Icon(Icons.smart_toy),
            label: const Text('Ask Aegis'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          );
        },
      ),
    );
  }
}