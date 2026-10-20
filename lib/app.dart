import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/file_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/update_provider.dart';
import 'providers/upload_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/setup_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/neu_theme.dart';
import 'utils/constants.dart';

class TeleDriveApp extends StatelessWidget {
  const TeleDriveApp({super.key});

  // Built once: the theme does not change, only which one is active.
  static final ThemeData _lightTheme = buildNeuTheme(Brightness.light);
  static final ThemeData _darkTheme = buildNeuTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => FileProvider()),
        ChangeNotifierProvider(create: (_) => UploadProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()..init()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: settings.themeMode,
          builder: (context, child) {
            final c = context.neu;
            final iconBrightness = c.isDark ? Brightness.light : Brightness.dark;
            // Keep the status and navigation bars the same material as the
            // page, so the soft look runs all the way to the screen edges.
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: iconBrightness,
                statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: c.base,
                systemNavigationBarIconBrightness: iconBrightness,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _AppGate(),
        ),
      ),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return switch (settings.loadState) {
          SettingsLoadState.loading => const SplashScreen(),
          SettingsLoadState.needsSetup => const SetupScreen(),
          SettingsLoadState.ready => const HomeScreen(),
        };
      },
    );
  }
}
