import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const AppCard({super.key, required this.child, this.padding,
      this.color, this.borderColor, this.radius = 12});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color ?? AppColors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.border, width: 0.8),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  const SectionTitle(this.text, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) => Text(text,
    style: GoogleFonts.nunito(
      fontSize: fontSize, fontWeight: FontWeight.w700, color: AppColors.dark));
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;
  const StatusBadge({super.key, required this.label, required this.bg, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: GoogleFonts.nunito(
      fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
  );
}

class InfoBanner extends StatelessWidget {
  final String title, message;
  final Color bg, borderColor, titleColor, messageColor;
  final IconData icon;

  const InfoBanner({super.key,
    required this.title, required this.message, required this.bg,
    required this.borderColor, required this.titleColor,
    required this.messageColor, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: borderColor, width: 0.8),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: titleColor, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700, color: titleColor)),
        const SizedBox(height: 3),
        Text(message, style: GoogleFonts.nunito(fontSize: 11, color: messageColor)),
      ])),
    ]),
  );
}

class StatRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const StatRow({super.key, required this.label, required this.value, this.valueColor, required int fontSize});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.muted)),
      Text(value, style: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: valueColor ?? AppColors.dark)),
    ]),
  );
}

class AegisNavHeader extends StatelessWidget {
  final String title, subtitle;
  const AegisNavHeader({super.key, required this.title, this.subtitle = ''});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, color: AppColors.navy,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16, right: 16, bottom: 14,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.shield, color: AppColors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text('Aegis', style: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white)),
      ]),
      const SizedBox(height: 10),
      Text(title, style: GoogleFonts.nunito(
        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white)),
      if (subtitle.isNotEmpty)
        Text(subtitle, style: GoogleFonts.nunito(
          fontSize: 12, color: const Color(0xFF85B7EB))),
    ]),
  );
}

enum PipelineStepState { done, active, pending }

class PipelineStep extends StatelessWidget {
  final String label;
  final PipelineStepState state;
  final bool isLast;
  const PipelineStep({super.key, required this.label, required this.state, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    Color dotBg; Widget dotIcon;
    switch (state) {
      case PipelineStepState.done:
        dotBg = AppColors.greenLight;
        dotIcon = const Icon(Icons.check, size: 12, color: AppColors.green);
        break;
      case PipelineStepState.active:
        dotBg = AppColors.blueLight;
        dotIcon = const SizedBox(width: 12, height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.blue)));
        break;
      case PipelineStepState.pending:
        dotBg = const Color(0xFFF1EFE8);
        dotIcon = const Icon(Icons.circle, size: 8, color: Color(0xFFB4B2A9));
        break;
    }
    return Expanded(child: Row(children: [
      Column(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: dotBg, shape: BoxShape.circle),
          child: Center(child: dotIcon),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.nunito(fontSize: 9,
          color: state == PipelineStepState.done ? AppColors.green
              : state == PipelineStepState.active ? AppColors.blue : AppColors.muted,
          fontWeight: FontWeight.w600)),
      ]),
      if (!isLast)
        Expanded(child: Container(
          height: 1.5, margin: const EdgeInsets.only(bottom: 18),
          color: state == PipelineStepState.done ? AppColors.greenMid : const Color(0xFFE8EAF0),
        )),
    ]));
  }
}

class LoadingOverlay extends StatelessWidget {
  final String message;
  const LoadingOverlay({super.key, this.message = 'Please wait...'});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black54,
    child: Center(child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.blue)),
        const SizedBox(height: 16),
        Text(message, style: GoogleFonts.nunito(fontSize: 14, color: AppColors.dark)),
      ]),
    )),
  );
}

class ErrorSnack {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.nunito(color: AppColors.white)),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

class SuccessSnack {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.nunito(color: AppColors.white)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
