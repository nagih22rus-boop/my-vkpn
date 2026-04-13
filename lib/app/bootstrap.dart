import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vkpn/app/vkpn_app.dart';
import 'package:vkpn/features/settings/data/settings_repository_impl.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Listen for Quick Settings Tile toggle
  _setupVpnToggleListener();
  
  final repo = SettingsRepositoryImpl();
  final loaded = await repo.load();
  final initial = loaded.normalizeLocaleForStoredCustomArb();
  if (!identical(loaded, initial)) {
    await repo.save(initial);
  }
  runApp(VkpnApp(settingsRepository: repo, initialSettings: initial));
}

void _setupVpnToggleListener() {
  const channel = MethodChannel('space.iscreation.vkpn/tile');
  
  // Set up method call handler for tile toggle
  channel.setMethodCallHandler((call) async {
    if (call.method == 'onTileClicked') {
      // This will be called from Android when tile is clicked
      // The actual toggle logic needs to be handled by the app
      // For now we just notify - the app should listen to this
      return true;
    }
    return false;
  });
}
