import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

export 'database/database.dart';

// Now loading from environment variables
String _kSupabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'YOUR_FALLBACK_URL';
String _kSupabaseAnonKey =
    dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_FALLBACK_KEY';

class SupaFlow {
  SupaFlow._();

  static SupaFlow? _instance;
  static SupaFlow get instance => _instance ??= SupaFlow._();

  final _supabase = Supabase.instance.client;
  static SupabaseClient get client => instance._supabase;

  static Future initialize() => Supabase.initialize(
        url: _kSupabaseUrl,
        headers: {
          'X-Client-Info': 'flutterflow',
        },
        anonKey: _kSupabaseAnonKey,
        debug: false,
        authOptions:
            const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
}
