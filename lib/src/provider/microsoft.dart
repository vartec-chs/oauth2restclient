import 'oauth2_provider.dart';

class Microsoft extends OAuth2ProviderF {
  Microsoft({
    required super.clientId,
    super.clientSecret,
    required super.redirectUri,
    required super.scopes,
  }) : super(
         name: "microsoft",
         authEndpoint:
             "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
         tokenEndpoint:
             "https://login.microsoftonline.com/common/oauth2/v2.0/token",
          getUserInfoEndpoint:
              "https://graph.microsoft.com/v1.0/me",
       );
}
