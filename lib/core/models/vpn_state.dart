enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

extension VpnStatusExt on VpnStatus {
  String get label {
    switch (this) {
      case VpnStatus.disconnected:
        return 'ОТКЛЮЧЕНО';
      case VpnStatus.connecting:
        return 'ПОДКЛЮЧЕНИЕ...';
      case VpnStatus.connected:
        return 'ЗАЩИЩЕНО (АКТИВНО)';
      case VpnStatus.disconnecting:
        return 'ОТКЛЮЧЕНИЕ...';
      case VpnStatus.error:
        return 'ОШИБКА';
    }
  }

  bool get isConnected => this == VpnStatus.connected;
  bool get isConnecting => this == VpnStatus.connecting;
  bool get isBusy => this == VpnStatus.connecting || this == VpnStatus.disconnecting;
  bool get isError => this == VpnStatus.error;
  bool get isDisconnected => this == VpnStatus.disconnected;
}
