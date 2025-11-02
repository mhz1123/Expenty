import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/sms_config.dart';

final List<Transaction> DUMMY_TRANSACTIONS = [
  Transaction(
    id: '1',
    type: 'debit',
    amount: 50.00,
    category: 'Food',
    description: 'Lunch at cafe',
    date: DateTime.now().subtract(Duration(days: 1)),
  ),
  Transaction(
    id: '2',
    type: 'credit',
    amount: 2000.00,
    category: 'Salary',
    description: 'Monthly salary',
    date: DateTime.now().subtract(Duration(days: 2)),
  ),
  Transaction(
    id: '3',
    type: 'debit',
    amount: 15.50,
    category: 'Transport',
    description: 'Bus fare',
    date: DateTime.now().subtract(Duration(days: 3)),
  ),
  Transaction(
    id: '4',
    type: 'debit',
    amount: 120.00,
    category: 'Utilities',
    description: 'Electricity bill',
    date: DateTime.now().subtract(Duration(days: 8)),
  ),
  Transaction(
    id: '5',
    type: 'debit',
    amount: 80.00,
    category: 'Entertainment',
    description: 'Movie tickets',
    date: DateTime.now().subtract(Duration(days: 10)),
  ),
  Transaction(
    id: '6',
    type: 'debit',
    amount: 800.00,
    category: 'Rent',
    description: 'Monthly Rent',
    date: DateTime.now().subtract(Duration(days: 30)),
  ),
  Transaction(
    id: '7',
    type: 'credit',
    amount: 150.00,
    category: 'Freelance',
    description: 'Project payment',
    date: DateTime.now().subtract(Duration(days: 32)),
  ),
];

final List<Budget> DUMMY_BUDGET = [
  Budget(
    id: 'b1',
    category: 'Rent',
    limit: 800,
    spent: 800,
    isCompulsory: true,
  ),
  Budget(
    id: 'b2',
    category: 'Utilities',
    limit: 150,
    spent: 120,
    isCompulsory: true,
  ),
  Budget(
    id: 'b3',
    category: 'Food',
    limit: 400,
    spent: 50,
    isCompulsory: false,
  ),
  Budget(
    id: 'b4',
    category: 'Transport',
    limit: 100,
    spent: 15.50,
    isCompulsory: false,
  ),
  Budget(
    id: 'b5',
    category: 'Entertainment',
    limit: 150,
    spent: 80,
    isCompulsory: false,
  ),
];

final SmsConfig DUMMY_SMS_CONFIG = SmsConfig(
  senderId: 'YOUR-BANK',
  debitKeywords: ['debited', 'spent', 'paid'],
  creditKeywords: ['credited', 'received'],
  id: '',
);
