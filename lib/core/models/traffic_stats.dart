class TrafficStats {
  final int uploadSpeedBytesPerSec;
  final int downloadSpeedBytesPerSec;
  final int totalUploadedBytes;
  final int totalDownloadedBytes;
  final Duration sessionDuration;
  final int? pingMs;

  const TrafficStats({
    this.uploadSpeedBytesPerSec = 0,
    this.downloadSpeedBytesPerSec = 0,
    this.totalUploadedBytes = 0,
    this.totalDownloadedBytes = 0,
    this.sessionDuration = Duration.zero,
    this.pingMs,
  });

  factory TrafficStats.empty() => const TrafficStats();

  TrafficStats copyWith({
    int? uploadSpeedBytesPerSec,
    int? downloadSpeedBytesPerSec,
    int? totalUploadedBytes,
    int? totalDownloadedBytes,
    Duration? sessionDuration,
    int? pingMs,
  }) {
    return TrafficStats(
      uploadSpeedBytesPerSec: uploadSpeedBytesPerSec ?? this.uploadSpeedBytesPerSec,
      downloadSpeedBytesPerSec: downloadSpeedBytesPerSec ?? this.downloadSpeedBytesPerSec,
      totalUploadedBytes: totalUploadedBytes ?? this.totalUploadedBytes,
      totalDownloadedBytes: totalDownloadedBytes ?? this.totalDownloadedBytes,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      pingMs: pingMs ?? this.pingMs,
    );
  }
}
