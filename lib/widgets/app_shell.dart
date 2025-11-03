import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/manual_entry_screen.dart';
import '../screens/sms_config_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/signin_screen.dart';
import '../services/sms_parser.dart';
import '../services/auth_service.dart';
import '../providers/app_provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  _AppShellState createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  SmsParserService? _smsService;
  bool _smsServiceStarted = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const TransactionsScreen(),
    const BudgetScreen(),
    const ManualEntryScreen(),
    const SmsConfigScreen(),
    const ProfileScreen(),
  ];

  final List<String> _screenTitles = [
    'dashboard',
    'transactions',
    'budget',
    'manual_entry',
    'sms_config',
    'profile',
  ];

  @override
  void initState() {
    super.initState();
    _startSmsService();
  }

  void _startSmsService() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);

      if (!_smsServiceStarted && appProvider.isInitialized) {
        _smsService = SmsParserService(appProvider: appProvider);
        _smsServiceStarted = true;

        // Start listening for new SMS
        Future.delayed(const Duration(seconds: 2), () {
          _smsService?.start();
        });
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close the drawer
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await AuthService().signOut();

      if (!mounted) return;

      // Navigate to sign-in screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      // If not on dashboard, go back to dashboard
      setState(() {
        _selectedIndex = 0;
      });
      return false; // Don't exit the app
    }
    // If on dashboard, allow exit
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('[ EXPENCER ]'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        drawer: Drawer(
          backgroundColor: Colors.grey[200],
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.only(
                  top: 54.0,
                  left: 16.0,
                  bottom: 16.0,
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '[ NAV ]',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (int i = 0; i < _screens.length; i++)
                      ListTile(
                        leading: const Text(
                          ' \$>',
                          style: TextStyle(color: Colors.grey),
                        ),
                        title: Text('cd ./${_screenTitles[i]}'),
                        onTap: () => _onItemTapped(i),
                        selected: i == _selectedIndex,
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  _handleSignOut();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        body: _screens[_selectedIndex],
      ),
    );
  }
}
