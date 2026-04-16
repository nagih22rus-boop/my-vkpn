import 'package:flutter/material.dart';
import 'package:vkpn/core/platform/unified_platform_bridge.dart';

/// Widget that checks for pending APK update and shows a mandatory dialog.
/// Shown every time the app is opened until update is installed.
class PendingUpdateChecker extends StatefulWidget {
  const PendingUpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  State<PendingUpdateChecker> createState() => _PendingUpdateCheckerState();
}

class _PendingUpdateCheckerState extends State<PendingUpdateChecker> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPendingUpdate();
    });
  }

  Future<void> _checkForPendingUpdate() async {
    if (_checked) return;
    _checked = true;

    try {
      final bridge = UnifiedPlatformBridge();
      final hasUpdate = await bridge.hasPendingUpdate();
      if (!hasUpdate || !mounted) return;

      final version = await bridge.getPendingVersion();
      if (!mounted) return;

      _showUpdateDialog(version ?? 'unknown');
    } catch (e) {
      // Silently fail - don't block app for update check errors
    }
  }

  Future<void> _showUpdateDialog(String version) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Доступно обновление'),
        content: Text(
          'Доступна новая версия VkPN ($version). '
          'Установите обновление для корректной работы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF132B57),
            ),
            child: const Text('Установить'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final bridge = UnifiedPlatformBridge();
        await bridge.installPendingUpdate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка установки: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
