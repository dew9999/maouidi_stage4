// lib/main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:maouidi/auth/base_auth_user_provider.dart';
import 'auth/supabase_auth/auth_util.dart';
import 'backend/supabase/supabase.dart';
import 'flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';
import 'services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Centralized Supabase initialization
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await FFLocalizations.initialize();
  await FlutterFlowTheme.initialize();

  if (!kIsWeb) {
    await NotificationService().initialize();
    OneSignal.Notifications.requestPermission(true);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;

  late Stream<BaseAuthUser?> userStream;

  @override
  void initState() {
    super.initState();
    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = maouidiSupabaseUserStream()
      ..listen((user) async {
        _appStateNotifier.update(user);
        if (user != null) {
          final role = await _fetchUserRole(user.uid!);
          _appStateNotifier.updateUserRole(role);
        } else {
          _appStateNotifier.updateUserRole(null);
        }
      });

    // MODIFICATION: Load the saved locale when the app starts
    _locale = FFLocalizations.getStoredLocale();

    Future.delayed(
      const Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  Future<String> _fetchUserRole(String userId) async {
    try {
      final partnerResponse = await Supabase.instance.client
          .from('medical_partners')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return partnerResponse != null ? 'Medical Partner' : 'Patient';
    } catch (e) {
      return 'Patient';
    }
  }

  void setLocale(String language) {
    setState(() => _locale = createLocale(language));
    FFLocalizations.storeLocale(
        language); // MODIFICATION: Save locale preference
  }

  void setThemeMode(ThemeMode mode) => setState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'maouidi',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: _locale,
      // MODIFICATION: Added localeResolutionCallback for better device language detection
      localeResolutionCallback: (locale, supportedLocales) {
        // If the user has already picked a language, use that
        if (_locale != null) {
          return _locale;
        }
        // Otherwise, check if the device language is supported
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        // If the device language is not supported, fall back to English
        return supportedLocales.first;
      },
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
      theme: ThemeData(brightness: Brightness.light, useMaterial3: false),
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: false),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}
