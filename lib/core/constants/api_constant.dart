// * Uncomment kalo dibutuhin
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstant {
  ApiConstant._();

  // static const String baseUrl = 'https://your-api.com';

  // static const int defaultReceiveTimeout = 180000;
  // static const int defaultConnectTimeout = 30000;
  // static const int longOperationTimeout = 300000;

  // static const String somePrefix = '/some-prefix';

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
