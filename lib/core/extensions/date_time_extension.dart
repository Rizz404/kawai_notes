import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';

/// Extension untuk mempermudah format object DateTime ke string.
extension DateTimeExtension on DateTime {
  /// Mengembalikan string waktu relatif seperti '1 day ago' dengan localization.
  String get timeAgo {
    try {
      final l10n = LocalizationExtension.current;
      final now = DateTime.now();
      final difference = now.difference(this);

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return l10n.timeAgoYear(years);
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return l10n.timeAgoMonth(months);
      } else if (difference.inDays > 0) {
        return l10n.timeAgoDay(difference.inDays);
      } else if (difference.inHours > 0) {
        return l10n.timeAgoHour(difference.inHours);
      } else if (difference.inMinutes > 0) {
        return l10n.timeAgoMinute(difference.inMinutes);
      } else {
        return l10n.timeAgoJustNow;
      }
    } catch (_) {
      return _defaultTimeAgo;
    }
  }

  String get _defaultTimeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1
          ? '1 day ago'
          : '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1
          ? '1 hour ago'
          : '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1
          ? '1 minute ago'
          : '${difference.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }

  /// Melakukan format tanggal menjadi string yang lebih mudah dibaca seperti 'Jan 1, 2025'.
  String get formattedDate {
    try {
      final l10n = LocalizationExtension.current;
      final months = [
        l10n.monthJan,
        l10n.monthFeb,
        l10n.monthMar,
        l10n.monthApr,
        l10n.monthMay,
        l10n.monthJun,
        l10n.monthJul,
        l10n.monthAug,
        l10n.monthSep,
        l10n.monthOct,
        l10n.monthNov,
        l10n.monthDec,
      ];
      return '${months[month - 1]} $day, $year';
    } catch (_) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[month - 1]} $day, $year';
    }
  }

  /// Melakukan format waktu dengan zero-pad menjadi string seperti '09:05'.
  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Mengembalikan gabungan format dari nilai tanggal dan waktu.
  String get formattedDateTime {
    return '$formattedDate $formattedTime';
  }

  /// Mengecek apakah object DateTime ini menuju ke hari ini.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Mengecek apakah object DateTime ini menuju ke kemarin.
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Mendapatkan nama hari sesuai dengan nilai locale saat ini.
  String get dayName {
    try {
      final l10n = LocalizationExtension.current;
      final days = [
        l10n.dayMon,
        l10n.dayTue,
        l10n.dayWed,
        l10n.dayThu,
        l10n.dayFri,
        l10n.daySat,
        l10n.daySun,
      ];
      return days[weekday - 1];
    } catch (_) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[weekday - 1];
    }
  }

  /// Mengembalikan nilai full representasi format ISO-8601.
  String get iso8601String => toIso8601String();

  /// Mengembalikan bagian format tanggal saja dari representasi string ISO-8601.
  String get iso8601Date => toIso8601String().split('T').first;
}
