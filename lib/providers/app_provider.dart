import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart' as expenty_transaction;
import '../models/budget.dart';
import '../models/sms_config.dart';

class AppProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<expenty_transaction.Transaction> _transactions = [];
  List<Budget> _budgets = [];
  SmsConfig? _smsConfig;

  AppProvider() {
    _fetchTransactions();
    _fetchBudgets();
    _fetchSmsConfig();
  }

  Future<void> _fetchTransactions() async {
    final snapshot = await _firestore.collection('transactions').orderBy('date', descending: true).get();
    _transactions = snapshot.docs.map((doc) {
      dynamic date = doc['date'];
      if (date is String) {
        date = DateTime.parse(date);
      } else if (date is Timestamp) {
        date = date.toDate();
      }
      return expenty_transaction.Transaction(
        id: doc.id,
        type: doc['type'] as String,
        amount: (doc['amount'] as num).toDouble(),
        category: doc['category'] as String,
        description: doc['description'] as String,
        date: date,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> _fetchBudgets() async {
    final snapshot = await _firestore.collection('budgets').get();
    _budgets = snapshot.docs.map((doc) => Budget(
      id: doc.id,
      category: doc['category'] as String,
      limit: (doc['limit'] as num).toDouble(),
      spent: (doc['spent'] as num).toDouble(),
      isCompulsory: doc['isCompulsory'] as bool,
    )).toList();
    notifyListeners();
  }

  Future<void> _fetchSmsConfig() async {
    final snapshot = await _firestore.collection('sms_config').get();
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      _smsConfig = SmsConfig(
        id: doc.id,
        senderId: doc['senderId'] as String,
        debitKeywords: List<String>.from(doc['debitKeywords']),
        creditKeywords: List<String>.from(doc['creditKeywords']),
      );
    }
    notifyListeners();
  }

  List<expenty_transaction.Transaction> get transactions => _transactions;
  List<Budget> get budgets => _budgets;
  SmsConfig? get smsConfig => _smsConfig;

  Future<void> addTransaction(expenty_transaction.Transaction transaction) async {
    final newTransactionRef = await _firestore.collection('transactions').add({
      'type': transaction.type,
      'amount': transaction.amount,
      'category': transaction.category,
      'description': transaction.description,
      'date': transaction.date,
    });
    _transactions.insert(0, transaction.copyWith(id: newTransactionRef.id));

    if (transaction.type == 'debit') {
      final budgetIndex = _budgets.indexWhere((b) => b.category.toLowerCase() == transaction.category.toLowerCase());
      if (budgetIndex != -1) {
        final budget = _budgets[budgetIndex];
        final updatedBudget = budget.copyWith(spent: budget.spent + transaction.amount);
        await _firestore.collection('budgets').doc(budget.id).update({'spent': updatedBudget.spent});
        _budgets[budgetIndex] = updatedBudget;
      }
    }
    notifyListeners();
  }

  Future<void> updateBudget(Budget budget) async {
    final budgetIndex = _budgets.indexWhere((b) => b.id == budget.id);
    if (budgetIndex != -1) {
      await _firestore.collection('budgets').doc(budget.id).update({
        'category': budget.category,
        'limit': budget.limit,
        'spent': budget.spent,
        'isCompulsory': budget.isCompulsory,
      });
      _budgets[budgetIndex] = budget;
    } else {
      final newBudgetRef = await _firestore.collection('budgets').add({
        'category': budget.category,
        'limit': budget.limit,
        'spent': budget.spent,
        'isCompulsory': budget.isCompulsory,
      });
      _budgets.add(budget.copyWith(id: newBudgetRef.id));
    }
    notifyListeners();
  }

  Future<void> updateSmsConfig(SmsConfig smsConfig) async {
    if (_smsConfig != null) {
      await _firestore.collection('sms_config').doc(_smsConfig!.id).update({
        'senderId': smsConfig.senderId,
        'debitKeywords': smsConfig.debitKeywords,
        'creditKeywords': smsConfig.creditKeywords,
      });
      _smsConfig = smsConfig;
    }
    notifyListeners();
  }
}

extension on expenty_transaction.Transaction {
  expenty_transaction.Transaction copyWith({String? id}) {
    return expenty_transaction.Transaction(
      id: id ?? this.id,
      type: this.type,
      amount: this.amount,
      category: this.category,
      description: this.description,
      date: this.date,
    );
  }
}

extension on Budget {
  Budget copyWith({String? id, double? spent}) {
    return Budget(
      id: id ?? this.id,
      category: this.category,
      limit: this.limit,
      spent: spent ?? this.spent,
      isCompulsory: this.isCompulsory,
    );
  }
}