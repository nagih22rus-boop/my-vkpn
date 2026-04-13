import 'package:flutter/widgets.dart';
import 'package:flutter_quick_actions/flutter_quick_actions.dart';
import 'package:vkpn/app/vkpn_app.dart';
import 'package:vkpn/features/settings/data/settings_repository_impl.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Quick Actions for notification bar
  _initializeQuickActions();
  
  final repo = SettingsRepositoryImpl();
  final loaded = await repo.load();
  final initial = loaded.normalizeLocaleForStoredCustomArb();
  if (!identical(loaded, initial)) {
    await repo.save(initial);
  }
  runApp(VkpnApp(settingsRepository: repo, initialSettings: initial));
}

void _initializeQuickActions() {
  const quickActions = QuickActions();
  quickActions.initialize((type) {
    // Handle quick action from notification bar
    // Type can be: 'toggle_vpn', 'open_app'
    if (type == 'toggle_vpn') {
      // This will be handled by the app's state
      // The app will listen for this and toggle VPN
    }
  });
  
  // Set up quick action shortcuts
  quickActions.setShortcutItems([
    const ShortcutItem(
      type: 'toggle_vpn',
      localizedTitle: 'Toggle VPN',
      icon: 'vpn_icon',
    ),
    const ShortcutItem(
      type: 'open_app',
      localizedTitle: 'Open App',
      icon: 'app_icon',
    ),
  ]);
}
