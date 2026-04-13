import 'dart:convert';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  // GitHub repository for vk-turn-proxy (original)
  static const String _vkTurnProxyRepo = 'cacggghp/vk-turn-proxy';
  
  // Your fork for the app updates
  final String _appRepo;
  final http.Client _client;

  UpdateService({String? appRepo, http.Client? client})
      : _appRepo = appRepo ?? 'nagih22rus-boop/my-vkpn',
        _client = client ?? http.Client();

  /// Check if there's a new version of vk-turn-proxy binary
  Future<UpdateInfo?> checkVkTurnProxyUpdate(String currentVersion) async {
    try {
      final response = await _client.get(
        Uri.parse('https://api.github.com/repos/$_vkTurnProxyRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      final latestVersion = data['tag_name'] as String? ?? '';
      
      // Remove 'v' prefix if present
      final cleanLatestVersion = latestVersion.startsWith('v') 
          ? latestVersion.substring(1) 
          : latestVersion;

      // Compare versions (simple string comparison for now)
      if (cleanLatestVersion != currentVersion) {
        // Find Android ARM64 binary
        String? downloadUrl;
        String releaseNotes = data['body'] as String? ?? '';
        
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name == 'client-android-arm64') {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }

        if (downloadUrl != null) {
          return UpdateInfo(
            version: cleanLatestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
          );
        }
      }
    } catch (e) {
      // Silently fail - update check should not break the app
    }
    return null;
  }

  /// Check if there's a new version of the app
  Future<UpdateInfo?> checkAppUpdate(String currentVersion) async {
    try {
      final response = await _client.get(
        Uri.parse('https://api.github.com/repos/$_appRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      final latestVersion = data['tag_name'] as String? ?? '';
      
      // Remove 'v' prefix if present
      final cleanLatestVersion = latestVersion.startsWith('v') 
          ? latestVersion.substring(1) 
          : latestVersion;

      // Compare versions
      if (_compareVersions(cleanLatestVersion, currentVersion) > 0) {
        // Find Android APK
        String? downloadUrl;
        String releaseNotes = data['body'] as String? ?? '';
        
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }

        if (downloadUrl != null) {
          return UpdateInfo(
            version: cleanLatestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
          );
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Compare two version strings (e.g., "1.2.3" vs "1.2.4")
  /// Returns: positive if v1 > v2, negative if v1 < v2, 0 if equal
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
    
    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      
      if (p1 != p2) {
        return p1 - p2;
      }
    }
    return 0;
  }

  void dispose() {
    _client.close();
  }
}