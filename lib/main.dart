import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/decision_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive full screen mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Make system bars transparent
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Lock to portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const CantDecideApp());
}

class CantDecideApp extends StatelessWidget {
  const CantDecideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CantDecide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          primary: Colors.black,
        ),
      ),
      home: const DecisionScreen(),
    );
  }
}
