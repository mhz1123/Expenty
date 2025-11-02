
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
  bool _showSignInPrompt = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _startLogAnimation();
  }

  void _startLogAnimation() async {
    // Simulate log messages appearing with a slight delay
    await Future.delayed(const Duration(milliseconds: 500));
    // After logs, show the sign-in prompt
    setState(() {
      _showSignInPrompt = true;
    });
  }

  Future<void> _signIn() async {
    if (_isSigningIn) return; // Prevent multiple sign-in attempts

    setState(() {
      _isSigningIn = true;
    });

    // Simulate additional log messages during sign-in
    await Future.delayed(const Duration(seconds: 1));

    final user = await AuthService().signInWithGoogle();
    if (user != null) {
      await Future.delayed(const Duration(seconds: 2)); // Simulate app loading
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } else {
      setState(() {
        _isSigningIn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed. Please try again.', style: TextStyle(color: Colors.black))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Whitish grey background
      body: GestureDetector(
        onTap: _showSignInPrompt && !_isSigningIn ? _signIn : null,
        child: Container(
          color: Colors.transparent, // Make sure GestureDetector covers the whole screen
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_showSignInPrompt)
                  AnimatedTextKit(
                    animatedTexts: [
                      TyperAnimatedText(
                        'Initializing...',
                        textStyle: const TextStyle(color: Colors.black, fontSize: 18.0, fontFamily: 'monospace'),
                        speed: const Duration(milliseconds: 50),
                      ),
                      TyperAnimatedText(
                        'Connecting to Firebase...',
                        textStyle: const TextStyle(color: Colors.black, fontSize: 18.0, fontFamily: 'monospace'),
                        speed: const Duration(milliseconds: 50),
                      ),
                      TyperAnimatedText(
                        'Awaiting user input...',
                        textStyle: const TextStyle(color: Colors.black, fontSize: 18.0, fontFamily: 'monospace'),
                        speed: const Duration(milliseconds: 50),
                      ),
                    ],
                    isRepeatingAnimation: false,
                    onFinished: () {
                      setState(() {
                        _showSignInPrompt = true;
                      });
                    },
                  ),
                if (_showSignInPrompt && !_isSigningIn)
                  Column(
                    children: [
                      const Text(
                        'Sign in',
                        style: TextStyle(color: Colors.black, fontSize: 24.0, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 20),
                      DefaultTextStyle(
                        style: const TextStyle(fontSize: 20.0, fontFamily: 'monospace', color: Colors.black),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            FlickerAnimatedText(
                              'Click Anywhere to Signin',
                              textStyle: const TextStyle(color: Colors.black),
                            ),
                          ],
                          isRepeatingAnimation: true,
                          onTap: () {
                            if (!_isSigningIn) {
                              _signIn();
                            }
                          },
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
                            textStyle: const TextStyle(color: Colors.black, fontSize: 18.0, fontFamily: 'monospace'),
                            speed: const Duration(milliseconds: 50),
                          ),
                          TyperAnimatedText(
                            'Fetching user data...',
                            textStyle: const TextStyle(color: Colors.black, fontSize: 18.0, fontFamily: 'monospace'),
                            speed: const Duration(milliseconds: 50),
                          ),
                          TyperAnimatedText(
                            'Starting application...',
                            textStyle: const TextStyle(color: Colors.black, fontSize: 18.0, fontFamily: 'monospace'),
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
