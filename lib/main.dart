
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './providers/app_provider.dart';
import './widgets/app_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: MaterialApp(
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
        home: const AppShell(),
      ),
    );
  }
}
