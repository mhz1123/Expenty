import 'package:flutter/material.dart';
import '../widgets/terminal_window.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = {
      'username': 'user_01',
      'email': 'user_01@expensetracker.local',
      'memberSince': '2023-01-15',
      'currency': 'USD',
      'notifications': 'enabled',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            TerminalWindow(
              title: 'cat /etc/user_profile',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileInfo('Username', user['username']!),
                  _buildProfileInfo('Email', user['email']!),
                  _buildProfileInfo('Member Since', user['memberSince']!),
                  _buildProfileInfo('Default Currency', user['currency']!),
                  _buildProfileInfo('Notifications', user['notifications']!, valueColor: Colors.green),
                ],
              ),
            ),
            TerminalWindow(
              title: 'user_actions.sh',
              child: Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: [
                  ElevatedButton(onPressed: () {}, child: const Text('Change Password')),
                  ElevatedButton(onPressed: () {}, child: const Text('Export Data')),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Delete Account'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo(String title, String value, {Color valueColor = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: valueColor)),
          ),
        ],
      ),
    );
  }
}