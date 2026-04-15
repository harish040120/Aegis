// lib/widgets/shared_widgets.dart

import 'package:flutter/material.dart';
import '../utils/constants.dart';

// ─── Aegis Logo ───────────────────────────────────────────────────────────────
class AegisLogo extends StatelessWidget {
  final double size;
  const AegisLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AegisColors.primary, Color(0xFF00E5C4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(
        Icons.shield_rounded,
        color: AegisColors.bg,
        size: size * 0.6,
      ),
    );
  }
}

// ─── Loading Button ────────────────────────────────────────────────────────────
class AegisButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final Widget? icon;

  const AegisButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AegisColors.primary,
        foregroundColor: AegisColors.bg,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        disabledBackgroundColor: AegisColors.border,
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AegisColors.bg,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(label),
              ],
            ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AegisColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: AegisColors.textMuted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AegisColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AegisColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 18, color: AegisColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AegisColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AegisColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Risk Badge ───────────────────────────────────────────────────────────────
class RiskBadge extends StatelessWidget {
  final String level;
  final double? score;

  const RiskBadge({super.key, required this.level, this.score});

  @override
  Widget build(BuildContext context) {
    final color = riskColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(riskIcon(level), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            score != null ? '$level  ${score!.toStringAsFixed(1)}' : level,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status.toUpperCase()) {
      case 'PAID':     return AegisColors.success;
      case 'APPROVED': return AegisColors.primary;
      case 'HELD':     return AegisColors.warning;
      case 'DENIED':   return AegisColors.danger;
      default:         return AegisColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const ErrorBanner({super.key, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AegisColors.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AegisColors.danger.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AegisColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AegisColors.danger,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, color: AegisColors.danger, size: 16),
            ),
        ],
      ),
    );
  }
}

// ─── Payout Status Banner ─────────────────────────────────────────────────────
class PayoutStatusBanner extends StatelessWidget {
  final String status;
  final double? amount;
  final String? upiId;

  const PayoutStatusBanner({
    super.key,
    required this.status,
    this.amount,
    this.upiId,
  });

  String get _message {
    switch (status.toUpperCase()) {
      case 'APPROVED': return 'Claim processing…';
      case 'PAID':     return '₹${amount?.toStringAsFixed(0) ?? ''} sent to ${upiId ?? 'your UPI'} ✓';
      case 'HELD':     return 'Claim under review';
      case 'DENIED':   return 'Not eligible this time';
      default:         return '';
    }
  }

  Color get _color {
    switch (status.toUpperCase()) {
      case 'PAID':     return AegisColors.success;
      case 'APPROVED': return AegisColors.primary;
      case 'HELD':     return AegisColors.warning;
      case 'DENIED':   return AegisColors.danger;
      default:         return AegisColors.textSecondary;
    }
  }

  IconData get _icon {
    switch (status.toUpperCase()) {
      case 'PAID':     return Icons.check_circle_rounded;
      case 'APPROVED': return Icons.autorenew_rounded;
      case 'HELD':     return Icons.hourglass_top_rounded;
      case 'DENIED':   return Icons.cancel_outlined;
      default:         return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_message.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
