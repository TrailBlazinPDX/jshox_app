import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'webview_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Safari-style edge-to-edge system UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const JshoxApp());
}

class JshoxApp extends StatelessWidget {
  const JshoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JSHOX',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // 🌞 Light
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),

      // 🌙 Dark
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),

      home: const WebViewPage(
        title: 'JSHOX',
        homeUrl: 'https://jshox.com',
        storageKey: 'last_url',
      ),
    );
  }
}