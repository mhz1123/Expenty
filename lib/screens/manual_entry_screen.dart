import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/terminal_window.dart';
import '../models/transaction.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({Key? key}) : super(key: key);

  @override
  _ManualEntryScreenState createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'debit';
  double _amount = 0;
  String _category = '';
  String _description = '';

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newTransaction = Transaction(
        id: '',
        type: _type,
        amount: _amount,
        category: _category,
        description: _description,
        date: DateTime.now(),
      );
      await Provider.of<AppProvider>(context, listen: false).addTransaction(newTransaction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added successfully!')),
      );
      _formKey.currentState!.reset();
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
              'Manual Transaction Entry',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            TerminalWindow(
              title: 'log_transaction.sh',
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SegmentedButton<
                        String>(
                      segments: const [
                        ButtonSegment(value: 'debit', label: Text('Debit')),
                        ButtonSegment(value: 'credit', label: Text('Credit')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _type = newSelection.first;
                        });
                      },
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Amount (\$)'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Please enter an amount' : null,
                      onSaved: (value) => _amount = double.parse(value!),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: (value) => value!.isEmpty ? 'Please enter a category' : null,
                      onSaved: (value) => _category = value!,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Description'),
                      validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
                      onSaved: (value) => _description = value!,
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('Execute Log'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
