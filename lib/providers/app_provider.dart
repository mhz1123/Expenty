import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction.dart' as expenty_transaction;
import '../models/budget.dart';
import '../models/sms_config.dart';

class AppProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<expenty_transaction.Transaction> _transactions = [];
  List<Budget> _budgets = [];
  SmsConfig? _smsConfig;
  bool _isInitialized = false;

  AppProvider();

  bool get isInitialized => _isInitialized;
  List<expenty_transaction.Transaction> get transactions => _transactions;
  List<Budget> get budgets => _budgets;
  SmsConfig? get smsConfig => _smsConfig;

  Future<void> init() async {
    if (_isInitialized) return;

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in, skipping initialization');
      return;
    }

    debugPrint('Initializing AppProvider for user: ${user.uid}');

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      await Future.wait([
        _fetchTransactions(),
        _fetchBudgets(),
        _fetchSmsConfig(),
      ]);

      _isInitialized = true;
      notifyListeners();

      debugPrint('AppProvider initialized successfully');
      debugPrint('Transactions: ${_transactions.length}');
      debugPrint('Budgets: ${_budgets.length}');
    } catch (e) {
      debugPrint('Error initializing AppProvider: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('Cannot fetch transactions: No user logged in');
        return;
      }

      debugPrint('Fetching transactions for user: $uid');

      final snapshot =
          await _firestore
              .collection('transactions')
              .where('userId', isEqualTo: uid)
              .orderBy('date', descending: true)
              .get();

      _transactions =
          snapshot.docs.map((doc) {
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

      debugPrint('Fetched ${_transactions.length} transactions');
      notifyListeners();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Permission denied fetching transactions. Please check Firestore rules.',
        );
      } else {
        debugPrint(
          'Firebase error fetching transactions: ${e.code} - ${e.message}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
  }

  Future<void> _fetchBudgets() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('Cannot fetch budgets: No user logged in');
        return;
      }

      debugPrint('Fetching budgets for user: $uid');

      final snapshot =
          await _firestore
              .collection('budgets')
              .where('userId', isEqualTo: uid)
              .get();

      _budgets =
          snapshot.docs
              .map(
                (doc) => Budget(
                  id: doc.id,
                  category: doc['category'] as String,
                  limit: (doc['limit'] as num).toDouble(),
                  spent: (doc['spent'] as num).toDouble(),
                  isCompulsory: doc['isCompulsory'] as bool,
                ),
              )
              .toList();

      debugPrint('Fetched ${_budgets.length} budgets');
      notifyListeners();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Permission denied fetching budgets. Please check Firestore rules.',
        );
      } else {
        debugPrint('Firebase error fetching budgets: ${e.code} - ${e.message}');
      }
    } catch (e) {
      debugPrint('Error fetching budgets: $e');
    }
  }

  Future<void> _fetchSmsConfig() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('Cannot fetch SMS config: No user logged in');
        return;
      }

      debugPrint('Fetching SMS config for user: $uid');

      final doc = await _firestore.collection('sms_config').doc(uid).get();

      if (doc.exists) {
        _smsConfig = SmsConfig(
          id: doc.id,
          senderId: doc['senderId'] as String,
          debitKeywords: List<String>.from(doc['debitKeywords'] ?? []),
          creditKeywords: List<String>.from(doc['creditKeywords'] ?? []),
        );
        debugPrint('SMS config fetched successfully');
      } else {
        debugPrint('No SMS config found, creating default...');
        _smsConfig = SmsConfig(
          id: uid,
          senderId: '',
          debitKeywords: ['debited', 'withdrawn', 'paid', 'spent'],
          creditKeywords: ['credited', 'received', 'deposit'],
        );

        try {
          await _firestore.collection('sms_config').doc(uid).set({
            'senderId': _smsConfig!.senderId,
            'debitKeywords': _smsConfig!.debitKeywords,
            'creditKeywords': _smsConfig!.creditKeywords,
          });
          debugPrint('Default SMS config created');
        } catch (e) {
          debugPrint('Error creating default SMS config: $e');
        }
      }

      notifyListeners();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Permission denied fetching SMS config. Please check Firestore rules.',
        );
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          _smsConfig = SmsConfig(
            id: uid,
            senderId: '',
            debitKeywords: ['debited', 'withdrawn', 'paid', 'spent'],
            creditKeywords: ['credited', 'received', 'deposit'],
          );
        }
      } else {
        debugPrint(
          'Firebase error fetching SMS config: ${e.code} - ${e.message}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching SMS config: $e');
    }
  }

  Future<void> addTransaction(
    expenty_transaction.Transaction transaction, {
    bool updateBudget = true,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('Cannot add transaction: No user logged in');
        return;
      }

      final newTransactionRef = await _firestore
          .collection('transactions')
          .add({
            'userId': uid,
            'type': transaction.type,
            'amount': transaction.amount,
            'category': transaction.category,
            'description': transaction.description,
            'date': Timestamp.fromDate(transaction.date),
          });

      _transactions.insert(0, transaction.copyWith(id: newTransactionRef.id));

      if (updateBudget && transaction.type == 'debit') {
        final budgetIndex = _budgets.indexWhere(
          (b) => b.category.toLowerCase() == transaction.category.toLowerCase(),
        );

        if (budgetIndex != -1) {
          final budget = _budgets[budgetIndex];
          final updatedBudget = budget.copyWith(
            spent: budget.spent + transaction.amount,
          );

          await _firestore.collection('budgets').doc(budget.id).update({
            'spent': updatedBudget.spent,
          });

          _budgets[budgetIndex] = updatedBudget;
        }
      }

      notifyListeners();
      debugPrint('Transaction added successfully');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Permission denied adding transaction. Please check Firestore rules.',
        );
      }
      debugPrint('Error adding transaction: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    }
  }

  Future<void> updateTransaction(
    String id,
    String category,
    String description,
    double amount,
  ) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore.collection('transactions').doc(id).update({
        'category': category,
        'description': description,
        'amount': amount,
      });

      final index = _transactions.indexWhere((t) => t.id == id);
      if (index != -1) {
        _transactions[index] = _transactions[index].copyWith(
          category: category,
          description: description,
          amount: amount,
        );
      }

      notifyListeners();
      debugPrint('Transaction updated successfully');
    } on FirebaseException catch (e) {
      debugPrint('Error updating transaction: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  Future<void> deleteTransactions(List<String> ids) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final batch = _firestore.batch();
      for (final id in ids) {
        batch.delete(_firestore.collection('transactions').doc(id));
      }
      await batch.commit();

      _transactions.removeWhere((t) => ids.contains(t.id));

      notifyListeners();
      debugPrint('${ids.length} transaction(s) deleted successfully');
    } on FirebaseException catch (e) {
      debugPrint('Error deleting transactions: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error deleting transactions: $e');
      rethrow;
    }
  }

  Future<void> updateTransactionCategories(
    List<String> ids,
    String newCategory,
  ) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final batch = _firestore.batch();
      for (final id in ids) {
        batch.update(_firestore.collection('transactions').doc(id), {
          'category': newCategory,
        });
      }
      await batch.commit();

      for (final id in ids) {
        final index = _transactions.indexWhere((t) => t.id == id);
        if (index != -1) {
          _transactions[index] = _transactions[index].copyWith(
            category: newCategory,
          );
        }
      }

      notifyListeners();
      debugPrint('${ids.length} transaction(s) category updated');
    } on FirebaseException catch (e) {
      debugPrint('Error updating categories: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating categories: $e');
      rethrow;
    }
  }

  Future<void> updateBudget(Budget budget) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

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
          'userId': uid,
          'category': budget.category,
          'limit': budget.limit,
          'spent': budget.spent,
          'isCompulsory': budget.isCompulsory,
        });
        _budgets.add(budget.copyWith(id: newBudgetRef.id));
      }

      notifyListeners();
      debugPrint('Budget updated successfully');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Permission denied updating budget. Please check Firestore rules.',
        );
      }
      debugPrint('Error updating budget: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('Error updating budget: $e');
    }
  }

  Future<void> updateSmsConfig(SmsConfig smsConfig) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore.collection('sms_config').doc(uid).set({
        'senderId': smsConfig.senderId,
        'debitKeywords': smsConfig.debitKeywords,
        'creditKeywords': smsConfig.creditKeywords,
      });

      _smsConfig = smsConfig.copyWith(id: uid);
      notifyListeners();
      debugPrint('SMS config updated successfully');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Permission denied updating SMS config. Please check Firestore rules.',
        );
      }
      debugPrint('Error updating SMS config: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('Error updating SMS config: $e');
    }
  }
}

extension on expenty_transaction.Transaction {
  expenty_transaction.Transaction copyWith({
    String? id,
    String? category,
    String? description,
    double? amount,
  }) {
    return expenty_transaction.Transaction(
      id: id ?? this.id,
      type: this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
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

extension on SmsConfig {
  SmsConfig copyWith({String? id}) {
    return SmsConfig(
      id: id ?? this.id,
      senderId: this.senderId,
      debitKeywords: this.debitKeywords,
      creditKeywords: this.creditKeywords,
    );
  }
}
