import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Labels and icons for appointment types.
class AppointmentUtils {
  static const types = [
    'neurologist',
    'primary care',
    'therapy',
    'other',
  ];

  static String typeLabel(String? type) {
    switch (type) {
      case 'neurologist':
        return 'Neurologist';
      case 'primary care':
        return 'Primary care';
      case 'therapy':
        return 'Therapy';
      case 'other':
        return 'Other visit';
      default:
        return type ?? 'Visit';
    }
  }

  static IconData typeIcon(String? type) {
    switch (type) {
      case 'neurologist':
        return Icons.psychology_outlined;
      case 'primary care':
        return Icons.local_hospital_outlined;
      case 'therapy':
        return Icons.self_improvement_outlined;
      default:
        return Icons.event_note_outlined;
    }
  }

  static String formatDateTime(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month]} ${dt.day} · $hour:$minute $period';
  }

  static bool isUpcoming(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return false;
    return dt.isAfter(DateTime.now());
  }

  static String daysUntilLabel(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1) return 'In $diff days';
    return 'Past';
  }
}
