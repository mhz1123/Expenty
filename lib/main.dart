import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import './providers/app_provider.dart';
import './screens/splash_screen.dart';
import './services/sms_parser.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  SmsParserService? _smsService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Builder(
        builder: (context) {
          // Initialize SMS service after provider is available
          if (_smsService == null) {
            final appProvider = Provider.of<AppProvider>(
              context,
              listen: false,
            );
            _smsService = SmsParserService(appProvider: appProvider);

            // Start SMS service after a delay to ensure everything is initialized
            Future.delayed(const Duration(seconds: 2), () {
              _smsService?.start();
            });
          }

          return MaterialApp(
            title: 'Expenty',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              fontFamily: 'monospace',
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
