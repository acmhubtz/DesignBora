import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/notifications/push_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService.instance.init();
  runApp(const DesignBoraApp());
}

class DesignBoraApp extends StatelessWidget {
  const DesignBoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'DesignBora',
        debugShowCheckedModeBanner: false,
        navigatorKey: PushService.navigatorKey,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        // Status bar: rangi ya app + ikoni nyeupe; maudhui yanaanza CHINI yake
        builder: (context, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: AppColors.primary,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            child: ColoredBox(
              color: AppColors.primary,
              child: SafeArea(
                bottom: false,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}
