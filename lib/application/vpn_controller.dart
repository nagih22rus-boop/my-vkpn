import '../domain/wg_config.dart';
import '../domain/wg_config_parser.dart';
import '../platform/unified_platform_bridge.dart';
import 'app_settings.dart';

class VpnController {
  VpnController({
    required this.parser,
    required this.bridge,
  });

  final WgConfigParser parser;
  final UnifiedPlatformBridge bridge;
  static const String localEndpointHost = '127.0.0.1';
  static const int localEndpointPort = 9000;

  RuntimeVpnConfig buildRuntimeConfig(String rawConfig, AppSettings settings) {
    final parsed = parser.parse(rawConfig);
    final rewritten = settings.useTurnMode
        ? parser.rewriteEndpoint(
            rawConfig,
            host: localEndpointHost,
            port: localEndpointPort,
          )
        : rawConfig;
    return RuntimeVpnConfig(
      rawConfig: rawConfig,
      rewrittenConfig: rewritten,
      targetHost: parsed.peer.endpointHost,
      targetPort: parsed.peer.endpointPort,
      proxyPort: settings.proxyPort,
      vkCallLink: settings.vkCallLink,
      localEndpointHost: localEndpointHost,
      localEndpointPort: localEndpointPort,
      useTurnMode: settings.useTurnMode,
    );
  }
}
