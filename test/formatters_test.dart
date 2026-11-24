import 'package:flutter_test/flutter_test.dart';
import 'package:linkpc/core/utils/formatters.dart';

void main() {
  group('Formatters.formatSpeed', () {
    test('formats zero and negative speeds in Кбит/с', () {
      expect(Formatters.formatSpeed(0), equals('0.0 Кбит/с'));
      expect(Formatters.formatSpeed(-50), equals('0.0 Кбит/с'));
    });

    test('formats small speeds under 1 Mbps in Кбит/с', () {
      // 100 bytes/sec * 8 = 800 bit/s = 0.8 Кбит/с
      expect(Formatters.formatSpeed(100), equals('0.8 Кбит/с'));
      // 125 bytes/sec * 8 = 1000 bit/s = 1.0 Кбит/с
      expect(Formatters.formatSpeed(125), equals('1.0 Кбит/с'));
      // 12500 bytes/sec * 8 = 100000 bit/s = 100.0 Кбит/с
      expect(Formatters.formatSpeed(12500), equals('100.0 Кбит/с'));
    });

    test('formats speeds between 1 Mbps and 1 Gbps in Мбит/с', () {
      // 125000 bytes/sec * 8 = 1,000,000 bit/s = 1.0 Мбит/с
      expect(Formatters.formatSpeed(125000), equals('1.0 Мбит/с'));
      // 12,500,000 bytes/sec * 8 = 100,000,000 bit/s = 100.0 Мбит/с
      expect(Formatters.formatSpeed(12500000), equals('100.0 Мбит/с'));
    });

    test('formats speeds 1 Gbps and above in Гбит/с', () {
      // 125,000,000 bytes/sec * 8 = 1,000,000,000 bit/s = 1.0 Гбит/с
      expect(Formatters.formatSpeed(125000000), equals('1.0 Гбит/с'));
      // 312,500,000 bytes/sec * 8 = 2,500,000,000 bit/s = 2.5 Гбит/с
      expect(Formatters.formatSpeed(312500000), equals('2.5 Гбит/с'));
    });
  });

  group('Formatters.formatDuration', () {
    test('formats duration correctly', () {
      expect(Formatters.formatDuration(Duration.zero), equals('00:00:00'));
      expect(
        Formatters.formatDuration(const Duration(hours: 2, minutes: 15, seconds: 9)),
        equals('02:15:09'),
      );
    });
  });
}
