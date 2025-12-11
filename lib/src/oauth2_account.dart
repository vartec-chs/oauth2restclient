import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:oauth2restclient/src/rest_client/oauth2_rest_client.dart';

import 'provider/oauth2_provider.dart';
import 'rest_client/http_oauth2_rest_client.dart';
import 'token/oauth2_token.dart';
import 'token/oauth2_token_storage.dart';

class OAuth2Account {
  final String appPrefix;

  final Map<String, OAuth2Provider> _providers = {};

  void addProvider(OAuth2Provider provider) {
    _providers[provider.name] = provider;
  }

  OAuth2Provider? getProvider(String nameOrIss) {
    for (var name in _providers.keys) {
      if (nameOrIss.contains(name)) {
        return _providers[name];
      }
    }
    return null;
  }

  late final OAuth2TokenStorage _tokenStorage;

  OAuth2Account({OAuth2TokenStorage? tokenStorage, required this.appPrefix}) {
    if (Platform.isAndroid || Platform.isIOS) {
      _tokenStorage = tokenStorage ?? OAuth2TokenStorageSecure();
    } else {
      _tokenStorage = tokenStorage ?? OAuth2TokenStorageShared();
    }
  }

  static const tokenPrefix = "OAUTH2ACCOUNT107"; // ✅ OAuth 키를 구별하기 위한 접두사 추가

  String keyFor(String service, String userName) =>
      "$appPrefix-$tokenPrefix-$service-$userName";

  Future<void> saveAccount(
    String service,
    String userName,
    OAuth2Token token,
  ) async {
    var key = keyFor(service, userName);
    var value = token.toJsonString();
    _tokenStorage.save(key, value);
  }

  Future<List<(String, String)>> allAccounts({String service = ""}) async {
    var prefix = keyFor(service, "");
    final all = await _tokenStorage.loadAll(keyPrefix: prefix);

    return all.keys
        .map((key) {
          final parts = key.split("-");
          return (parts[2], parts[3]); // (serviceName, account)
        })
        .where(
          (tuple) => service.isEmpty || tuple.$1.contains(service),
        ) // ✅ 필터링 추가
        .toList();
  }

  Future<OAuth2Token?> loadAccount(String service, String userName) async {
    var key = keyFor(service, userName);
    var jsonString = await _tokenStorage.load(key);
    if (jsonString == null) return null;
    return OAuth2TokenF.fromJsonString(jsonString);
  }

  Future<void> deleteAccount(String service, String userName) async {
    var key = keyFor(service, userName);
    await _tokenStorage.delete(key);
  }

  Future<OAuth2Token?> any({String service = ""}) async {
    var all = await allAccounts(service: service);
    if (all.isEmpty) return null;
    var first = all.first;
    return loadAccount(first.$1, first.$2);
  }

  Future<OAuth2Token?> newLogin(String service) async {
    var provider = getProvider(service);
    if (provider == null) throw Exception("can't find provider '$service'");

    var token = await provider.login();
    if (token != null) {
      token.provider = service;
      await saveAccount(service, token.userName, token);
    }
    return token;
  }

  Future<OAuth2Token?> tryAutoLogin(String service, String userName) async {
    var token = await loadAccount(service, userName);
    if (token?.timeToLogin ?? false) {
      token = await forceRelogin(token!);
    }
    return token;
  }

  Future<OAuth2Token?> forceRelogin(OAuth2Token expiredToken) async {
    var provider = getProvider(expiredToken.provider);
    if (provider == null) {
      throw Exception("can't find provider for '{$expiredToken.provider}'");
    }

    var token = await provider.login();
    if (token != null) {
      token.provider = provider.name;
      await saveAccount(provider.name, token.userName, token);
      return token;
    }
    return null;
  }

  Future<OAuth2RestClient> createClient(OAuth2Token token) async {
    var client = HttpOAuth2RestClient(
      accessToken: token.accessToken,
      refreshToken: () async {
        try {
          var newToken = await refreshToken(token);
          return newToken?.accessToken;
        } catch (e) {
          debugPrint(e.toString());
          return null;
        }
      },
    );
    return client;
  }

  final Map<String, Future<OAuth2Token?>> _pendingRefreshes = {};

  Future<OAuth2Token?> refreshToken(OAuth2Token expiredToken) async {
    //, String service, String userName
    final String refreshKey =
        "${expiredToken.provider}:${expiredToken.userName}";

    // 이미 진행 중인 갱신이 있는지 확인
    if (_pendingRefreshes.containsKey(refreshKey)) {
      return _pendingRefreshes[refreshKey];
    }

    // 새로운 갱신 작업 생성
    final refreshOperation = _doRefreshToken(expiredToken);

    // 진행 중인 작업으로 등록
    _pendingRefreshes[refreshKey] = refreshOperation;

    // 작업 완료 후 목록에서 제거
    refreshOperation.whenComplete(() {
      _pendingRefreshes.remove(refreshKey);
    });

    return refreshOperation;
  }

  Future<OAuth2Token?> _doRefreshToken(OAuth2Token token) async {
    var provider = getProvider(token.provider);
    if (provider == null) return null;

    //String service, String userName
    var savedToken = await loadAccount(provider.name, token.userName);
    if (savedToken == null) return null;

    var newToken = await provider.refreshToken(savedToken.refreshToken);
    if (newToken == null) return null;

    var mergedToken = savedToken.mergeToken(newToken);

    await saveAccount(provider.name, mergedToken.userName, mergedToken);
    return mergedToken;
  }
}
