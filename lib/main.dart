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
  bool _smsServiceStarted = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Builder(
        builder: (context) {
          final appProvider = Provider.of<AppProvider>(context, listen: false);

          // Initialize and start SMS service once after provider is ready
          if (_smsService == null) {
            _smsService = SmsParserService(appProvider: appProvider);
          }

          // Start SMS service after app initialization (when user is logged in)
          if (!_smsServiceStarted && appProvider.isInitialized) {
            _smsServiceStarted = true;
            Future.delayed(const Duration(seconds: 1), () {
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
