import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:oauth2restclient/oauth2restclient.dart';

import 'config.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final account = OAuth2Account(
    appPrefix: "oauth2restclientexample",
    tokenStorage: OAuth2TokenStorageJson(
      file: File(Directory.systemTemp.path + "/oauth2_tokens_example.json"),
    ),
  );
  final service = "google";

  @override
  void initState() {
    super.initState();

    final file = File(
      Directory.systemTemp.path + "/oauth2_tokens_example.json",
    );
    debugPrint("Using token file: ${file.path}");

    final dropbox = Dropbox(
      clientId: Config.dropboxClientId,
      redirectUri: "http://localhost:8713/callback",
      scopes: [
        "account_info.read",
        "files.content.read",
        "files.content.write",
        "files.metadata.write",
        "files.metadata.read",
      ],
    );

    account.addProvider(dropbox);

    final google = Google(
      redirectUri: "http://localhost:8569/callback",
      scopes: [
        'https://www.googleapis.com/auth/drive',
        "https://www.googleapis.com/auth/photoslibrary",
        "openid",
        "email",
      ],
      clientId: Config.googleClientId,
      clientSecret: Config.googleClientSecret,
    );

    account.addProvider(google);
  }

  int _counter = 0;

  Future<String> getEmail(OAuth2RestClient client, String service) async {
    if (service == "dropbox") {
      var response = await client.postJson(
        "https://api.dropboxapi.com/2/users/get_current_account",
      );
      return response.toString();
    }

    if (service == "microsoft") {
      var response = await client.getJson(
        "https://graph.microsoft.com/v1.0/me",
      );
      return response["mail"] as String;
    }

    // Google
    var response = await client.getJson(
      "https://www.googleapis.com/oauth2/v3/userinfo",
    );
    return response.toString();
  }

  void _incrementCounter() async {
    var token = await account.newLogin(service);
    if (token?.timeToLogin ?? false) {
      token = await account.forceRelogin(token!);
    }

    if (token == null) throw Exception("login first");
    var client = await account.createClient(token);

    var email = await getEmail(client, service);
    debugPrint(email);

    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
