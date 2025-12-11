import 'oauth2_provider.dart';

class Yandex extends OAuth2ProviderF {
  Yandex({
    required super.clientId,
    super.clientSecret,
    required super.redirectUri,
    required super.scopes,
  }) : super(
         name: "yandex",
         authEndpoint: "https://oauth.yandex.ru/authorize",
         tokenEndpoint: "https://oauth.yandex.ru/token",
       );
}
