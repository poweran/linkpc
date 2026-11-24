import 'dart:math';
import 'package:intl/intl.dart';

class Formatters {
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    if (i >= suffixes.length) i = suffixes.length - 1;
    final num = bytes / pow(1024, i);
    return '${num.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 512) return '0.0 KB/s';
    if (bytesPerSecond < 1024 * 1024) {
      final kb = bytesPerSecond / 1024.0;
      return '${kb.toStringAsFixed(1)} KB/s';
    }
    final mb = bytesPerSecond / (1024.0 * 1024.0);
    return '${mb.toStringAsFixed(1)} MB/s';
  }

  static String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  static String formatDate(DateTime? date) {
    if (date == null) return 'Бессрочно';
    final formatter = DateFormat('dd.MM.yyyy');
    return formatter.format(date);
  }
}
