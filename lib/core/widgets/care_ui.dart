import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme.dart';

class CareHeartHero extends StatelessWidget {
  final double size;

  const CareHeartHero({
    super.key,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [

          // Outer rings only
          _ring(size * 0.90, 0.15),
          _ring(size * 0.75, 0.22),
          _ring(size * 0.60, 0.30),

          // Logo (NO ClipOval)
          Image.asset(
            'assets/images/brain_heart_logo.png',
            width: size * 0.95,
            height: size * 0.95,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _ring(double diameter, double opacity) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.teal.withOpacity(opacity),
          width: 2,
        ),
      ),
    );
  }
}
class CareLoadingDots extends StatefulWidget {
  const CareLoadingDots({super.key});

  @override
  State<CareLoadingDots> createState() => _CareLoadingDotsState();
}

class _CareLoadingDotsState extends State<CareLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(8, (i) {
            final phase = (_controller.value * 2 * math.pi) + (i * math.pi / 4);
            final scale = 0.45 + 0.55 * ((math.sin(phase) + 1) / 2);
            final opacity = 0.35 + 0.65 * ((math.sin(phase) + 1) / 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: CareTheme.accentPink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class CareProgressBar extends StatelessWidget {
  final double progress;
  const CareProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 4,
        backgroundColor: CareTheme.surface,
        color: CareTheme.accentPink,
      ),
    );
  }
}

class CareOnboardingShell extends StatelessWidget {
  final double progress;
  final Widget child;
  final Widget? bottom;
  final bool showBack;

  const CareOnboardingShell({
    super.key,
    required this.progress,
    required this.child,
    this.bottom,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: CareTheme.textSecondary, size: 20),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(child: CareProgressBar(progress: progress)),
                ],
              ),
            ),
            Expanded(child: child),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: bottom!,
              ),
          ],
        ),
      ),
    );
  }
}

class CareHighlightText extends StatelessWidget {
  final String text;
  final List<String> highlights;
  final TextAlign align;

  const CareHighlightText({
    super.key,
    required this.text,
    this.highlights = const [],
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final base = CareTheme.displaySerif.copyWith(fontSize: 26);
  final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    int index = 0;
    while (index < text.length) {
      String? match;
      int? matchStart;
      for (final word in highlights) {
        final start = lower.indexOf(word.toLowerCase(), index);
        if (start >= 0 && (matchStart == null || start < matchStart)) {
          matchStart = start;
          match = text.substring(start, start + word.length);
        }
      }
      if (matchStart == null || match == null) {
        spans.add(TextSpan(text: text.substring(index), style: base.copyWith(color: CareTheme.textPrimary)));
        break;
      }
      if (matchStart > index) {
        spans.add(TextSpan(
          text: text.substring(index, matchStart),
          style: base.copyWith(color: CareTheme.textPrimary),
        ));
      }
      spans.add(TextSpan(
        text: match,
        style: base.copyWith(color: CareTheme.accentPink),
      ));
      index = matchStart + match.length;
    }

    return RichText(textAlign: align, text: TextSpan(children: spans));
  }
}

class CareSelectionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CareSelectionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? CareTheme.surfaceLight : CareTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: selected ? CareTheme.accentPink : CareTheme.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: CareTheme.bodySans.copyWith(
                    fontSize: 15,
                    color: CareTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
