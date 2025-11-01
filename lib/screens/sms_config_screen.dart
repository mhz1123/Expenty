import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/terminal_window.dart';
import '../models/sms_config.dart';

class SmsConfigScreen extends StatefulWidget {
  const SmsConfigScreen({Key? key}) : super(key: key);

  @override
  _SmsConfigScreenState createState() => _SmsConfigScreenState();
}

class _SmsConfigScreenState extends State<SmsConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _senderId;
  late String _debitKeywords;
  late String _creditKeywords;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final smsConfig = Provider.of<AppProvider>(context).smsConfig;
    _senderId = smsConfig.senderId;
    _debitKeywords = smsConfig.debitKeywords.join(', ');
    _creditKeywords = smsConfig.creditKeywords.join(', ');
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newConfig = SmsConfig(
        senderId: _senderId,
        debitKeywords: _debitKeywords.split(',').map((e) => e.trim()).toList(),
        creditKeywords: _creditKeywords.split(',').map((e) => e.trim()).toList(),
      );
      Provider.of<AppProvider>(context, listen: false).updateSmsConfig(newConfig);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration saved successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMS Parser Config',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            TerminalWindow(
              title: 'configure_parser.conf',
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _senderId,
                      decoration: const InputDecoration(labelText: 'Sender ID (e.g., AM-HDFCBK)'),
                      validator: (value) => value!.isEmpty ? 'Please enter a sender ID' : null,
                      onSaved: (value) => _senderId = value!,
                    ),
                    TextFormField(
                      initialValue: _debitKeywords,
                      decoration: const InputDecoration(labelText: 'Debit Keywords (comma-separated)'),
                      validator: (value) => value!.isEmpty ? 'Please enter debit keywords' : null,
                      onSaved: (value) => _debitKeywords = value!,
                    ),
                    TextFormField(
                      initialValue: _creditKeywords,
                      decoration: const InputDecoration(labelText: 'Credit Keywords (comma-separated)'),
                      validator: (value) => value!.isEmpty ? 'Please enter credit keywords' : null,
                      onSaved: (value) => _creditKeywords = value!,
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('Save Configuration'),
                    ),
                  ],
                ),
              ),
            ),
            TerminalWindow(
              title: 'SMS Simulation',
              child: Column(
                children: [
                  const Text('Paste a message here to test your configuration.'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Rs.500 has been debited from your account...',
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Implement SMS parsing logic
                    },
                    child: const Text('Parse Message'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}