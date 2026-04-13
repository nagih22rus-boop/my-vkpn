import 'package:flutter/material.dart';
import 'package:vkpn/core/l10n/l10n_helpers.dart';
import 'package:vkpn/core/update/update_service.dart';

class UpdateSection extends StatefulWidget {
  const UpdateSection({
    super.key,
    required this.currentVkTurnVersion,
    required this.currentAppVersion,
  });

  final String currentVkTurnVersion;
  final String currentAppVersion;

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  bool _isChecking = false;
  String? _vkTurnUpdateStatus;
  String? _appUpdateStatus;
  UpdateInfo? _vkTurnUpdate;
  UpdateInfo? _appUpdate;

  Future<void> _checkUpdates() async {
    setState(() {
      _isChecking = true;
      _vkTurnUpdateStatus = null;
      _appUpdateStatus = null;
    });

    final updateService = UpdateService();
    
    // Check vk-turn-proxy update
    final vkTurnUpdate = await updateService.checkVkTurnProxyUpdate(widget.currentVkTurnVersion);
    
    // Check app update
    final appUpdate = await updateService.checkAppUpdate(widget.currentAppVersion);
    
    setState(() {
      _vkTurnUpdate = vkTurnUpdate;
      _appUpdate = appUpdate;
      
      if (vkTurnUpdate != null) {
        _vkTurnUpdateStatus = 'New version available: ${vkTurnUpdate.version}';
      } else {
        _vkTurnUpdateStatus = 'Up to date (${widget.currentVkTurnVersion})';
      }
      
      if (appUpdate != null) {
        _appUpdateStatus = 'New version available: ${appUpdate.version}';
      } else {
        _appUpdateStatus = 'Up to date (${widget.currentAppVersion})';
      }
      
      _isChecking = false;
    });
    
    updateService.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: false,
      title: Text(
        tr(context, 'updates', (l) => l.updates ?? 'Updates'),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: <Widget>[
        // VK-TURN Proxy version info
        _buildVersionRow(
          'VK-TURN Proxy',
          widget.currentVkTurnVersion,
          _vkTurnUpdateStatus,
          _vkTurnUpdate != null,
        ),
        const SizedBox(height: 8),
        
        // App version info
        _buildVersionRow(
          'App Version',
          widget.currentAppVersion,
          _appUpdateStatus,
          _appUpdate != null,
        ),
        const SizedBox(height: 12),
        
        // Check for updates button
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: const Color(0xFF132B57),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isChecking ? null : _checkUpdates,
          child: _isChecking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr(context, 'checkForUpdates', (l) => l.checkForUpdates ?? 'Check for Updates')),
        ),
        
        // Update available message
        if (_vkTurnUpdate != null || _appUpdate != null) ...[
          const SizedBox(height: 12),
          Text(
            _vkTurnUpdate != null
                ? 'VK-TURN update available!'
                : 'App update available!',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New APK will be downloaded from GitHub releases',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildVersionRow(String title, String currentVersion, String? status, bool hasUpdate) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Current: $currentVersion',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (status != null)
          Icon(
            hasUpdate ? Icons.arrow_circle_up : Icons.check_circle,
            color: hasUpdate ? Colors.orange : Colors.green,
            size: 20,
          ),
      ],
    );
  }
}