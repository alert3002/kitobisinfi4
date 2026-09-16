import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/progress_service.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } catch (_) {}
  try {
    await ProgressService.instance.init();
  } catch (_) {}
  runApp(const KitobhoApp());
  unawaited(_initAfterLaunch());
}

Future<void> _initAfterLaunch() async {
  try {
    await AdsService.instance.init();
  } catch (e, st) {
    debugPrint('Ads init after launch: $e\n$st');
  }
  try {
    await PushService.instance.init();
  } catch (e, st) {
    debugPrint('Push init after launch: $e\n$st');
  }
}

class KitobhoApp extends StatelessWidget {
  const KitobhoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: kitobhoNavigatorKey,
      title: kAppTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
