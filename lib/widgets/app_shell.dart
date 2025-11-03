import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/manual_entry_screen.dart';
import '../screens/sms_config_screen.dart';
import '../screens/profile_screen.dart';
import '../services/sms_parser.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('[ EXPENCER ]'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[200],
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.black),
              child: Text(
                '[ NAV ]',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
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
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Container(
          height: 50.0,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'STATUS: ONLINE | LATENCY: 12ms',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
