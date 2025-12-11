import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../token/oauth2_token.dart';
import 'pkce.dart';

HttpServer? _server;

abstract interface class OAuth2Provider {
  String get name;
  Future<OAuth2Token?> login();
  Future<String?> exchangeCode(String? code);
  Future<OAuth2Token?> refreshToken(String? refreshToken);
}

class OAuth2ProviderF implements OAuth2Provider {
  final String clientId;
  final String? clientSecret;
  final String redirectUri;
  final List<String>? scopes;
  final String authEndpoint;
  final String tokenEndpoint;

  String? codeVerifier;

  @override
  final String name;

  OAuth2ProviderF({
    required this.name,
    required this.clientId,
    this.clientSecret,
    required this.redirectUri,
    this.scopes,
    required this.authEndpoint,
    required this.tokenEndpoint,
  });

  String get _authUrl {
    codeVerifier ??= PKCE.generateCodeVerifier();
    var cc = PKCE.generateCodeChallenge(codeVerifier!);

    return "$authEndpoint"
        "?client_id=$clientId"
        "&redirect_uri=$redirectUri"
        "&response_type=code"
        "${scopes != null ? "&scope=${scopes!.join('%20')}" : ""}"
        "&access_type=offline"
        "&token_access_type=offline"
        "&prompt=consent"
        "&code_challenge_method=S256"
        "&code_challenge=$cc";
  }

  @override
  Future<OAuth2Token?> login() async {
    if (Platform.isAndroid || Platform.isIOS) return loginFromMobile();
    return loginFromDesktop();
  }

  Future<OAuth2Token?> loginFromDesktop() async {
    try {
      var uri = Uri.parse(_authUrl);
      await launchUrl(uri); // ✅ 자동으로 브라우저 실행

      final bindUri = Uri.parse(redirectUri);
      final host = bindUri.host; // 'localhost'
      final port = bindUri.port; // 8080 (또는 지정된 포트)
      final path = bindUri.path; // '/ca

      await _server?.close();
      _server = await HttpServer.bind(host, port);

      await for (final request in _server!) {
        // callback 경로 확인
        if (request.uri.path == path) {
          // 코드 파라미터 추출
          var code = request.uri.queryParameters['code'];
          final response = await exchangeCode(code);

          if (response == null) {
            request.response.headers.contentType = ContentType.html;
            request.response.write('''
              <!DOCTYPE html>
              <html>
              <head>
                <title>Error</title>
                <style>
                  body { font-family: Arial, sans-serif; text-align: center; padding-top: 50px; }
                  h1 { color: #e74c3c; }
                  p { font-size: 16px; }
                </style>
              </head>
              <body>
                <h1>Login Failed</h1>
                <p>Authentication failed. Please close this window and return to the app.</p>
              </body>
              </html>
            ''');
            await request.response.close();
          } else {
            // 성공 메시지를 브라우저에 표시
            request.response.headers.contentType = ContentType.html;
            request.response.write('''
              <!DOCTYPE html>
              <html>
              <head>
                <title>Login Success</title>
                <style>
                  body { font-family: Arial, sans-serif; text-align: center; padding-top: 50px; }
                  h1 { color: #4285f4; }
                  p { font-size: 16px; }
                </style>
              </head>
              <body>
                <h1>Login Success!</h1>
                <p>Authentication completed. Please close this window and return to the app.</p>
              </body>
              </html>
            ''');
            await request.response.close();

            return OAuth2TokenF.fromJsonString(response);
          }
        } else {
          // 잘못된 경로 처리
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      await _server?.close();
      _server = null;
    }

    return null;
  }

  Future<OAuth2Token?> loginFromMobile() async {
    var uri = Uri.parse(_authUrl);
    if (!await canLaunchUrl(uri)) return null;

    Completer<String?> completer = Completer();
    final appLinks = AppLinks(); // AppLinks is singleton
    final sub = appLinks.uriLinkStream.listen((uri) async {
      String? response;
      var code = uri.queryParameters["code"];
      try {
        response = await exchangeCode(code);
      } finally {
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      }
    });

    await launchUrl(uri); // ✅ 자동으로 브라우저 실행
    var response = await completer.future;
    sub.cancel();
    closeInAppWebView();

    if (response == null) return null;

    return OAuth2TokenF.fromJsonString(response);
  }

  @override
  Future<String?> exchangeCode(String? code) async {
    if (code == null) return null;

    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {
        "client_id": clientId,
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": redirectUri,
        if (clientSecret != null) "client_secret": clientSecret,
        if (codeVerifier != null) "code_verifier": codeVerifier,
      },
    );

    if (response.statusCode == 200) return response.body;
    return null;
  }

  @override
  Future<OAuth2Token?> refreshToken(String? refreshToken) async {
    if (refreshToken?.isEmpty ?? true) return null;

    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {
        "client_id": clientId,
        if (clientSecret != null) "client_secret": clientSecret,
        "grant_type": "refresh_token",
        "refresh_token": refreshToken,
      },
    );

    if (response.statusCode == 200) {
      return OAuth2TokenF.fromJsonString(response.body);
    }

    return null;
  }
}
