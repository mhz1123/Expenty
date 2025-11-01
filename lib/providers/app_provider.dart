
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/sms_config.dart';
import '../data/dummy_data.dart';

class AppProvider with ChangeNotifier {
  List<Transaction> _transactions = DUMMY_TRANSACTIONS;
  List<Budget> _budgets = DUMMY_BUDGET;
  SmsConfig _smsConfig = DUMMY_SMS_CONFIG;

  List<Transaction> get transactions => _transactions;
  List<Budget> get budgets => _budgets;
  SmsConfig get smsConfig => _smsConfig;

  void addTransaction(Transaction transaction) {
    _transactions.insert(0, transaction);
    // Update budget
    if (transaction.type == 'debit') {
      final budgetIndex = _budgets.indexWhere((b) => b.category.toLowerCase() == transaction.category.toLowerCase());
      if (budgetIndex != -1) {
        final budget = _budgets[budgetIndex];
        final updatedBudget = Budget(
          id: budget.id,
          category: budget.category,
          limit: budget.limit,
          spent: budget.spent + transaction.amount,
          isCompulsory: budget.isCompulsory,
        );
        _budgets[budgetIndex] = updatedBudget;
      }
    }
    notifyListeners();
  }

  void updateBudget(Budget budget) {
    final budgetIndex = _budgets.indexWhere((b) => b.id == budget.id);
    if (budgetIndex != -1) {
      _budgets[budgetIndex] = budget;
    } else {
      _budgets.add(budget);
    }
    notifyListeners();
  }

  void updateSmsConfig(SmsConfig smsConfig) {
    _smsConfig = smsConfig;
    notifyListeners();
  }
}
