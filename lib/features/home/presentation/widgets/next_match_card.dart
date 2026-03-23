import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class NextMatchCard extends StatefulWidget {
  const NextMatchCard({super.key});

  @override
  State<NextMatchCard> createState() => _NextMatchCardState();
}

class _NextMatchCardState extends State<NextMatchCard> {
  late Timer _timer;
  Duration _remaining = const Duration(hours: 2, minutes: 34, seconds: 17);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds > 0) {
        setState(() => _remaining -= const Duration(seconds: 1));
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _pad(_remaining.inHours);
    final m = _pad(_remaining.inMinutes.remainder(60));
    final s = _pad(_remaining.inSeconds.remainder(60));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Próximo partido',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.bgCardLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: const Center(
                        child: Text('🏟️', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Montequinto FC',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'VS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CountdownRow(h: h, m: m, s: s),
                ],
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.bgCardLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: const Center(
                        child: Text('⚽', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Los Palacios',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  final String h, m, s;
  const _CountdownRow({required this.h, required this.m, required this.s});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CountdownUnit(value: h, label: 'h'),
        const Text(' : ',
            style: TextStyle(
                color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        _CountdownUnit(value: m, label: 'm'),
        const Text(' : ',
            style: TextStyle(
                color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        _CountdownUnit(value: s, label: 's'),
      ],
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final String value;
  final String label;
  const _CountdownUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.3), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: Text(
            value,
            key: ValueKey(value),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
