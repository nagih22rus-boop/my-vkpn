import 'wg_config.dart';

class WgConfigParser {
  WgConfig parse(String input) {
    final sections = _splitSections(input);
    final interfaceData = sections['Interface'];
    final peerData = sections['Peer'];
    if (interfaceData == null) {
      throw const FormatException('Missing [Interface] section');
    }
    if (peerData == null) {
      throw const FormatException('Missing [Peer] section');
    }

    final privateKey = interfaceData['PrivateKey']?.trim();
    final addressRaw = interfaceData['Address']?.trim();
    if (privateKey == null || privateKey.isEmpty) {
      throw const FormatException('Interface.PrivateKey is required');
    }
    if (addressRaw == null || addressRaw.isEmpty) {
      throw const FormatException('Interface.Address is required');
    }

    final dnsRaw = interfaceData['DNS'] ?? '';
    final mtuRaw = interfaceData['MTU'];
    final iface = WgInterface(
      privateKey: privateKey,
      addresses: _splitCsv(addressRaw),
      dns: _splitCsv(dnsRaw),
      mtu: mtuRaw == null || mtuRaw.trim().isEmpty ? null : int.tryParse(mtuRaw),
    );

    final publicKey = peerData['PublicKey']?.trim();
    final allowedIpsRaw = peerData['AllowedIPs']?.trim();
    final endpointRaw = peerData['Endpoint']?.trim();
    if (publicKey == null || publicKey.isEmpty) {
      throw const FormatException('Peer.PublicKey is required');
    }
    if (allowedIpsRaw == null || allowedIpsRaw.isEmpty) {
      throw const FormatException('Peer.AllowedIPs is required');
    }
    if (endpointRaw == null || endpointRaw.isEmpty) {
      throw const FormatException('Peer.Endpoint is required');
    }
    final endpoint = _parseEndpoint(endpointRaw);
    final keepaliveRaw = peerData['PersistentKeepalive'];
    final peer = WgPeer(
      publicKey: publicKey,
      allowedIps: _splitCsv(allowedIpsRaw),
      endpointHost: endpoint.$1,
      endpointPort: endpoint.$2,
      persistentKeepalive: keepaliveRaw == null || keepaliveRaw.trim().isEmpty
          ? null
          : int.tryParse(keepaliveRaw),
    );

    return WgConfig(interface: iface, peer: peer);
  }

  String rewriteEndpoint(String input, {required String host, required int port}) {
    final lines = input.split('\n');
    final rewritten = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Endpoint') && trimmed.contains('=')) {
        final rawValue = trimmed.split('=').last.trim();
        _parseEndpoint(rawValue);
        rewritten.add('Endpoint = $host:$port');
      } else {
        rewritten.add(line);
      }
    }
    return rewritten.join('\n');
  }

  Map<String, Map<String, String>> _splitSections(String input) {
    final sections = <String, Map<String, String>>{};
    String? currentSection;
    for (final rawLine in input.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
        continue;
      }
      if (line.startsWith('[') && line.endsWith(']')) {
        currentSection = line.substring(1, line.length - 1).trim();
        sections[currentSection] = <String, String>{};
        continue;
      }
      if (currentSection == null || !line.contains('=')) {
        continue;
      }
      final idx = line.indexOf('=');
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      sections[currentSection]![key] = value;
    }
    return sections;
  }

  List<String> _splitCsv(String input) {
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  (String, int) _parseEndpoint(String endpoint) {
    final idx = endpoint.lastIndexOf(':');
    if (idx <= 0 || idx == endpoint.length - 1) {
      throw FormatException('Invalid endpoint: $endpoint');
    }
    final host = endpoint.substring(0, idx).trim();
    final port = int.tryParse(endpoint.substring(idx + 1).trim());
    if (host.isEmpty || port == null) {
      throw FormatException('Invalid endpoint: $endpoint');
    }
    return (host, port);
  }
}
