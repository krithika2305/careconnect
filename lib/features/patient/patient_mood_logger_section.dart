import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../shared/mood_utils.dart';

class PatientMoodLoggerSection extends ConsumerStatefulWidget {
  final String patientId;
  const PatientMoodLoggerSection({super.key, required this.patientId});

  @override
  ConsumerState<PatientMoodLoggerSection> createState() => _PatientMoodLoggerSectionState();
}

class _PatientMoodLoggerSectionState extends ConsumerState<PatientMoodLoggerSection> {
  String? _selectedMood;
  int _energy = 3;
  bool _saving = false;

  Future<void> _submit(String slot) async {
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap how you feel first.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(supabaseClientProvider).from('mood_logs').insert({
        'patient_id': widget.patientId,
        'mood': _selectedMood,
        'energy_level': _energy,
      });
      ref.invalidate(todayMoodStatusProvider(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(slot == 'morning' ? 'Morning check-in saved.' : 'Evening check-in saved.'),
            backgroundColor: CareTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedMood = null;
          _energy = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e'), backgroundColor: CareTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _slotSummary(String label, Map<String, dynamic>? log) {
    if (log == null) {
      return Text('$label — not logged yet', style: TextStyle(color: CareTheme.textMuted, fontSize: 13));
    }
    final mood = log['mood']?.toString() ?? 'neutral';
    final energy = log['energy_level'] ?? 3;
    return Row(
      children: [
        Text(MoodUtils.emoji(mood), style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: ${MoodUtils.label(mood)} · Energy $energy/5',
            style: TextStyle(color: CareTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Icon(Icons.check_circle, color: CareTheme.success, size: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(todayMoodStatusProvider(widget.patientId));
    return statusAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: CareTheme.accentPink))),
      error: (e, _) => Text('Mood logger unavailable: $e', style: TextStyle(color: CareTheme.error)),
      data: (status) {
        final morningDone = status['morning_done'] == true;
        final eveningDone = status['evening_done'] == true;
        final currentSlot = status['current_slot']?.toString() ?? 'morning';
        final morningLog = status['morning_log'] as Map<String, dynamic>?;
        final eveningLog = status['evening_log'] as Map<String, dynamic>?;

        final canLogMorning = !morningDone && currentSlot == 'morning';
        final canLogEvening = !eveningDone && currentSlot == 'evening';
        final showForm = canLogMorning || canLogEvening;
        final activeSlot = canLogMorning ? 'morning' : 'evening';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),   // reduced padding
          decoration: BoxDecoration(
            color: CareTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CareTheme.accentPink.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(Icons.sentiment_satisfied_alt_rounded, color: CareTheme.accentPink, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text('How are you feeling?', style: TextStyle(color: CareTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 2),
              Text('Tap emoji twice a day', style: TextStyle(color: CareTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              _slotSummary('Morning', morningLog),
              const SizedBox(height: 4),
              _slotSummary('Evening', eveningLog),
              if (morningDone && eveningDone) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: CareTheme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text('All set for today', textAlign: TextAlign.center, style: TextStyle(color: CareTheme.success, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
              if (showForm) ...[
                const SizedBox(height: 10),
                Text(activeSlot == 'morning' ? 'Morning check-in' : 'Evening check-in', style: TextStyle(color: CareTheme.accentPink, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: MoodUtils.moods.map((mood) {
                    final selected = _selectedMood == mood;
                    return GestureDetector(
                      onTap: _saving ? null : () => setState(() => _selectedMood = mood),
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: selected ? CareTheme.accentPink.withValues(alpha: 0.15) : CareTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? CareTheme.accentPink : CareTheme.surfaceLight, width: selected ? 2 : 1),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(MoodUtils.emoji(mood), style: const TextStyle(fontSize: 28)),
                          Text(MoodUtils.label(mood), style: TextStyle(fontSize: 9, color: CareTheme.textMuted)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Text('Energy level', style: TextStyle(color: CareTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: List.generate(5, (i) {
                    final level = i + 1;
                    final selected = _energy == level;
                    return GestureDetector(
                      onTap: _saving ? null : () => setState(() => _energy = level),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: selected ? CareTheme.warning.withValues(alpha: 0.25) : CareTheme.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? CareTheme.warning : CareTheme.surfaceLight, width: selected ? 2 : 1),
                        ),
                        child: Center(child: Text('$level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: selected ? CareTheme.textPrimary : CareTheme.textMuted))),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 2),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Low', style: TextStyle(color: CareTheme.textMuted, fontSize: 11)),
                  Text('High', style: TextStyle(color: CareTheme.textMuted, fontSize: 11)),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _submit(activeSlot),
                    style: ElevatedButton.styleFrom(backgroundColor: MedicalTheme.primaryTeal, foregroundColor: Colors.white),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Save ${activeSlot == 'morning' ? 'morning' : 'evening'} check-in', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (!showForm && !(morningDone && eveningDone)) ...[
                const SizedBox(height: 6),
                Text(
                  currentSlot == 'evening' && !morningDone
                      ? 'Morning missed – log evening mood'
                      : 'Come back later',
                  style: TextStyle(color: CareTheme.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}