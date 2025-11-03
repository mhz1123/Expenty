import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import 'package:another_telephony/telephony.dart';
import '../services/auth_service.dart';
import '../providers/app_provider.dart';
import '../widgets/sms_config_dialog.dart';
import '../widgets/app_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _showSignInPrompt = false;
  bool _isSigningIn = false;
  final Telephony _telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _startLogAnimation();
  }

  void _startLogAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _showSignInPrompt = true;
    });
  }

  Future<void> _signIn() async {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    final user = await AuthService().signInWithGoogle();

    if (!mounted) return;

    if (user != null) {
      debugPrint('User signed in: ${user.uid}');

      // Initialize app provider
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.init();

      if (!mounted) return;

      // Request SMS permissions for new user
      debugPrint('Requesting SMS permissions...');
      final bool? granted = await _telephony.requestSmsPermissions;

      if (granted != true) {
        debugPrint('SMS permissions denied');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SMS permissions denied. You can enable them later in settings.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        debugPrint('SMS permissions granted');
      }

      if (!mounted) return;

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // Check if SMS config exists
      if (appProvider.smsConfig == null ||
          appProvider.smsConfig!.senderId.isEmpty) {
        // Show SMS config dialog for new user
        debugPrint('New user - showing SMS config dialog');
        _showSmsConfigDialog();
      } else {
        // Existing user with config - go to app
        debugPrint('Existing user - proceeding to app');
        _navigateToApp();
      }
    } else {
      if (!mounted) return;

      setState(() {
        _isSigningIn = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: GestureDetector(
        onTap: _showSignInPrompt && !_isSigningIn ? _signIn : null,
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_showSignInPrompt)
                  AnimatedTextKit(
                    animatedTexts: [
                      TyperAnimatedText(
                        'Initializing...',
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 18.0,
                          fontFamily: 'monospace',
                        ),
                        speed: const Duration(milliseconds: 50),
                      ),
                      TyperAnimatedText(
                        'Connecting to Firebase...',
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 18.0,
                          fontFamily: 'monospace',
                        ),
                        speed: const Duration(milliseconds: 50),
                      ),
                      TyperAnimatedText(
                        'Awaiting user input...',
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 18.0,
                          fontFamily: 'monospace',
                        ),
                        speed: const Duration(milliseconds: 50),
                      ),
                    ],
                    isRepeatingAnimation: false,
                    onFinished: () {
                      if (mounted) {
                        setState(() {
                          _showSignInPrompt = true;
                        });
                      }
                    },
                  ),
                if (_showSignInPrompt && !_isSigningIn)
                  Column(
                    children: [
                      const Text(
                        'Sign in',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 20),
                      DefaultTextStyle(
                        style: const TextStyle(
                          fontSize: 20.0,
                          fontFamily: 'monospace',
                          color: Colors.black,
                        ),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            FlickerAnimatedText(
                              'Click Anywhere to Signin',
                              textStyle: const TextStyle(color: Colors.black),
                            ),
                          ],
                          isRepeatingAnimation: true,
                        ),
                      ),
                    ],
                  ),
                if (_isSigningIn)
                  Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.black),
                      const SizedBox(height: 16.0),
                      AnimatedTextKit(
                        animatedTexts: [
                          TyperAnimatedText(
                            'Signing in...',
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 18.0,
                              fontFamily: 'monospace',
                            ),
                            speed: const Duration(milliseconds: 50),
                          ),
                          TyperAnimatedText(
                            'Fetching user data...',
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 18.0,
                              fontFamily: 'monospace',
                            ),
                            speed: const Duration(milliseconds: 50),
                          ),
                          TyperAnimatedText(
                            'Requesting permissions...',
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 18.0,
                              fontFamily: 'monospace',
                            ),
                            speed: const Duration(milliseconds: 50),
                          ),
                        ],
                        isRepeatingAnimation: false,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
