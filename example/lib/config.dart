import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get dropboxClientId => dotenv.env['DROPBOX_CLIENT_ID']!;
  static String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID']!;
  static String get googleClientSecret => dotenv.env['GOOGLE_CLIENT_SECRET']!;
}
