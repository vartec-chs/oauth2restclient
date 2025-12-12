import 'oauth2_provider.dart';

class Dropbox extends OAuth2ProviderF {
  Dropbox({
    required super.clientId,
    super.clientSecret,
    required super.redirectUri,
    super.scopes,
  }) : super(
         name: "dropbox",
         authEndpoint: "https://www.dropbox.com/oauth2/authorize",
         tokenEndpoint: "https://api.dropboxapi.com/oauth2/token",
          getUserInfoEndpoint:
              "https://api.dropboxapi.com/2/users/get_current_account",
       );
}
