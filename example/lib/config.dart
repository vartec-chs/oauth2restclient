import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get dropboxClientId => dotenv.env['DROPBOX_CLIENT_ID']!;
  static String get mobileClientId => dotenv.env['MOBILE_CLIENT_ID']!;
  static String get onedriveClientId => dotenv.env['ONEDRIVE_CLIENT_ID']!;
  static String get desktopClientId => dotenv.env['DESKTOP_CLIENT_ID']!;
  static String get desktopClientSecret => dotenv.env['DESKTOP_CLIENT_SECRET']!;
}
