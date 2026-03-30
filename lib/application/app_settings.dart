class AppSettings {
  AppSettings({
    required this.proxyPort,
    required this.vkCallLink,
    required this.useUdp,
    required this.useTurnMode,
    required this.threads,
    required this.wgConfigText,
    required this.wgConfigFileName,
  });

  final int proxyPort;
  final String vkCallLink;
  final bool useUdp;
  final bool useTurnMode;
  final int threads;
  final String wgConfigText;
  final String wgConfigFileName;

  factory AppSettings.defaults() {
    return AppSettings(
      proxyPort: 56000,
      vkCallLink: '',
      useUdp: true,
      useTurnMode: true,
      threads: 8,
      wgConfigText: '',
      wgConfigFileName: '',
    );
  }
}
