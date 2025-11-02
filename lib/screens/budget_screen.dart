import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/terminal_window.dart';
import '../models/budget.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);

  @override
  _BudgetScreenState createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _id;
  String _category = '';
  double _limit = 0;
  bool _isCompulsory = false;
  bool _isEditing = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newBudget = Budget(
        id: _isEditing ? _id! : '',
        category: _category,
        limit: _limit,
        spent: _isEditing ? Provider.of<AppProvider>(context, listen: false).budgets.firstWhere((b) => b.id == _id).spent : 0,
        isCompulsory: _isCompulsory,
      );
      await Provider.of<AppProvider>(context, listen: false).updateBudget(newBudget);
      _resetForm();
    }
  }

  void _editBudget(Budget budget) {
    setState(() {
      _id = budget.id;
      _category = budget.category;
      _limit = budget.limit;
      _isCompulsory = budget.isCompulsory;
      _isEditing = true;
    });
  }

  void _resetForm() {
    setState(() {
      _id = null;
      _category = '';
      _limit = 0;
      _isCompulsory = false;
      _isEditing = false;
    });
    _formKey.currentState!.reset();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final budgets = appProvider.budgets;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget Planner',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            TerminalWindow(
              title: _isEditing ? 'edit_budget.sh' : 'create_budget.sh',
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: ValueKey(_isEditing ? _id : 'category'),
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: (value) => value!.isEmpty ? 'Please enter a category' : null,
                      onSaved: (value) => _category = value!,
                    ),
                    TextFormField(
                      key: ValueKey(_isEditing ? '${_id}_limit' : 'limit'),
                      initialValue: _limit == 0 ? '' : _limit.toString(),
                      decoration: const InputDecoration(labelText: 'Limit (\$)'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Please enter a limit' : null,
                      onSaved: (value) => _limit = double.parse(value!),
                    ),
                    CheckboxListTile(
                      title: const Text('Compulsory (EMI, Rent, Bill)'),
                      value: _isCompulsory,
                      onChanged: (value) {
                        setState(() {
                          _isCompulsory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(_isEditing ? 'Update Budget' : 'Add Budget'),
                        ),
                        if (_isEditing)
                          ElevatedButton(
                            onPressed: _resetForm,
                            child: const Text('Cancel'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            TerminalWindow(
              title: 'Current Budget Plan',
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: budgets.length,
                itemBuilder: (context, index) {
                  final budget = budgets[index];
                  return ListTile(
                    title: Text(budget.category),
                    subtitle: Text('Spent: \u0024${budget.spent.toStringAsFixed(2)} / Limit: \u0024${budget.limit.toStringAsFixed(2)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editBudget(budget),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
