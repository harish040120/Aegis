import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _logout(BuildContext context) {
    Provider.of<AegisProvider>(context, listen: false).logout();
    Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<AegisProvider>(context);
    final worker = prov.worker;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: worker == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Image.asset('assets/main_logo.png', height: 26),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: Column(
                            children: [
                              CircleAvatar(radius: 36, backgroundColor: AppColors.navy, child: Text(worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 28, color: Colors.white))),
                              const SizedBox(height: 12),
                              Text(worker.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(worker.phone, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: Column(
                            children: [
                              _row("Plan", worker.planTier.toUpperCase()),
                              const Divider(),
                              _row("Zone", worker.zone),
                              const Divider(),
                              _row("Phone", worker.phone),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _logout(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Logout"))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]));
}
