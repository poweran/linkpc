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
    if (bytesPerSecond <= 0) return '0.0 Кбит/с';
    final bitsPerSecond = bytesPerSecond * 8.0;
    if (bitsPerSecond < 1000 * 1000) {
      final kbps = bitsPerSecond / 1000.0;
      return '${kbps.toStringAsFixed(1)} Кбит/с';
    }
    if (bitsPerSecond < 1000 * 1000 * 1000) {
      final mbps = bitsPerSecond / (1000.0 * 1000.0);
      return '${mbps.toStringAsFixed(1)} Мбит/с';
    }
    final gbps = bitsPerSecond / (1000.0 * 1000.0 * 1000.0);
    return '${gbps.toStringAsFixed(1)} Гбит/с';
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
