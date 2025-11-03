import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:another_telephony/telephony.dart';
import '../widgets/app_shell.dart';
import '../providers/app_provider.dart';
import './signin_screen.dart';
import '../widgets/sms_config_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Telephony _telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in
      debugPrint('User logged in: ${user.uid}');

      // Initialize app provider first
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.init();

      if (!mounted) return;

      // Check if SMS permissions are granted
      final bool? hasPermissions = await _telephony.requestSmsPermissions;

      if (hasPermissions != true) {
        // Request SMS permissions
        debugPrint('Requesting SMS permissions...');
        final bool? granted = await _telephony.requestSmsPermissions;

        if (granted != true) {
          // Show warning and continue without SMS
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS permissions denied. You can enable them later in settings.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      if (!mounted) return;

      // Check if SMS config exists
      if (appProvider.smsConfig == null ||
          appProvider.smsConfig!.senderId.isEmpty) {
        // Show SMS config dialog
        debugPrint('No SMS config found, showing config dialog...');
        _showSmsConfigDialog();
      } else {
        // SMS config exists, proceed to app
        debugPrint('SMS config found, proceeding to app...');
        _navigateToApp();
      }
    } else {
      // No user logged in, go to sign in screen
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    }
  }

  void _showSmsConfigDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => SmsConfigDialog(
            onSaved: () {
              Navigator.of(context).pop();
              _navigateToApp();
            },
          ),
    );
  }

  void _navigateToApp() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
