
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../services/auth_service.dart';
import '../widgets/app_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _showSignInButton = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _showSignInButton = true;
    });
  }

  Future<void> _signIn() async {
    setState(() {
      _isSigningIn = true;
    });
    final user = await AuthService().signInWithGoogle();
    if (user != null) {
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } else {
      setState(() {
        _isSigningIn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: GestureDetector(
        onTap: _showSignInButton && !_isSigningIn ? _signIn : null,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isSigningIn)
                AnimatedTextKit(
                  animatedTexts: [
                    TyperAnimatedText('Initializing...'),
                    TyperAnimatedText('Connecting to Firebase...'),
                    TyperAnimatedText('Sign in'),
                  ],
                  isRepeatingAnimation: false,
                  onFinished: () {
                    setState(() {
                      _showSignInButton = true;
                    });
                  },
                ),
              if (_showSignInButton && !_isSigningIn)
                DefaultTextStyle(
                  style: const TextStyle(fontSize: 20.0, fontFamily: 'monospace'),
                  child: AnimatedTextKit(
                    animatedTexts: [
                      WavyAnimatedText('Click Anywhere to Signin'),
                    ],
                    isRepeatingAnimation: true,
                  ),
                ),
              if (_isSigningIn)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16.0),
                    AnimatedTextKit(
                      animatedTexts: [
                        TyperAnimatedText('Signing in...'),
                        TyperAnimatedText('Fetching user data...'),
                        TyperAnimatedText('Almost there...'),
                      ],
                      isRepeatingAnimation: false,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
