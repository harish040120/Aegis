import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final double amount;
  final String trigger;
  const PaymentSuccessScreen(
      {super.key, required this.amount, required this.trigger});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AegisColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AegisColors.primary, width: 3),
                ),
                child: const Icon(Icons.check,
                    color: AegisColors.primary, size: 64),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payout Successful',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${widget.amount.toStringAsFixed(0)} · ${widget.trigger}',
              style: const TextStyle(
                  fontSize: 14, color: AegisColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
