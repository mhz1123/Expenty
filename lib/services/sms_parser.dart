import 'package:flutter/foundation.dart';
import 'package:another_telephony/telephony.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/app_provider.dart';

class SmsParserService {
  final Telephony _telephony = Telephony.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppProvider appProvider;

  // Config loaded from Firestore
  String senderId = '';
  List<String> debitKeywords = [];
  List<String> creditKeywords = [];

  SmsParserService({required this.appProvider});

  Future<void> start() async {
    try {
      // Load config from Firestore
      await _loadConfig();

      // Request SMS permissions
      final bool? permissionsGranted = await _telephony.requestSmsPermissions;

      if (permissionsGranted != true) {
        debugPrint('SMS permissions not granted.');
        return;
      }

      debugPrint('SMS permissions granted. Setting up listeners...');

      // Listen to incoming SMS in foreground
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          debugPrint('Foreground SMS received from: ${message.address}');
          await _processMessage(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
      );

      // Process any existing unread SMS messages
      await _processExistingSms();

      debugPrint('SMS Parser Service started successfully');
    } catch (e) {
      debugPrint('Error starting SMS Parser Service: $e');
    }
  }

  Future<void> _loadConfig() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('No user logged in, using default config');
        return;
      }

      final docRef = _firestore.collection('sms_config').doc(uid);
      final snap = await docRef.get();

      if (!snap.exists) {
        debugPrint('No SMS config found for user');
        return;
      }

      final data = snap.data()!;
      senderId = data['senderId'] as String? ?? '';
      debitKeywords = List<String>.from(data['debitKeywords'] ?? []);
      creditKeywords = List<String>.from(data['creditKeywords'] ?? []);

      debugPrint(
        'SMS config loaded: senderId=$senderId, debitKeywords=${debitKeywords.length}, creditKeywords=${creditKeywords.length}',
      );
    } catch (e) {
      debugPrint('Failed to load SMS config: $e');
    }
  }

  Future<void> _processExistingSms() async {
    try {
      debugPrint('Processing existing SMS messages...');

      // Get inbox messages from last 30 days
      final DateTime thirtyDaysAgo = DateTime.now().subtract(
        const Duration(days: 30),
      );

      List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(
          SmsColumn.DATE,
        ).greaterThan(thirtyDaysAgo.millisecondsSinceEpoch.toString()),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      debugPrint('Found ${messages.length} messages to process');

      for (var message in messages) {
        await _processMessage(message);
      }

      debugPrint('Finished processing existing SMS messages');
    } catch (e) {
      debugPrint('Error processing existing SMS: $e');
    }
  }

  Future<void> _processMessage(SmsMessage message) async {
    try {
      final address = (message.address ?? '').toString().trim();
      final body = (message.body ?? '').toString().trim();

      if (body.isEmpty) {
        return;
      }

      // Filter by sender if configured
      if (senderId.isNotEmpty) {
        final lowerAddr = address.toLowerCase();
        final matchedSender = senderId
            .toLowerCase()
            .split(',')
            .any((s) => lowerAddr.contains(s.trim()));

        if (!matchedSender) {
          debugPrint('Sender $address does not match configured sender ID');
          return;
        }
      }

      // Detect transaction type
      final type = _detectType(body);
      if (type == null) {
        debugPrint('Message not recognized as credit/debit: ${_shorten(body)}');
        return;
      }

      // Extract amount
      final amount = _extractAmount(body);
      if (amount == null) {
        debugPrint('Amount parse failed for: ${_shorten(body)}');
        return;
      }

      // Extract date
      final date = _extractDate(body) ?? DateTime.now();

      // Extract category/merchant (optional)
      final category = _extractCategory(body, type);

      // Create transaction
      final txn = Transaction(
        id: '',
        amount: amount,
        date: date,
        type: type,
        category: category,
        description: 'SMS: ${_shorten(body, 100)}',
      );

      debugPrint(
        'Adding transaction: $type Rs.$amount on ${DateFormat('dd-MMM-yy').format(date)}',
      );

      // Add to provider WITHOUT updating budget (updateBudget = false)
      await appProvider.addTransaction(txn, updateBudget: false);

      debugPrint('Transaction added successfully');
    } catch (e) {
      debugPrint('Error processing message: $e');
    }
  }

  String? _detectType(String body) {
    final lc = body.toLowerCase();

    // Check for debit keywords
    final hasDebit = debitKeywords.any(
      (k) => lc.contains(k.toLowerCase().trim()),
    );

    // Check for credit keywords
    final hasCredit = creditKeywords.any(
      (k) => lc.contains(k.toLowerCase().trim()),
    );

    if (hasDebit && !hasCredit) return 'debit';
    if (hasCredit && !hasDebit) return 'credit';

    // If both or neither, try to determine from common patterns
    if (lc.contains('debited') ||
        lc.contains('withdrawn') ||
        lc.contains('spent')) {
      return 'debit';
    }
    if (lc.contains('credited') ||
        lc.contains('received') ||
        lc.contains('deposit')) {
      return 'credit';
    }

    return null;
  }

  double? _extractAmount(String body) {
    // Pattern to match amounts in various formats
    // Rs 100.00, Rs. 100, INR 100.00, 100.00, Rs100, etc.
    final amountRegex = RegExp(
      r'(?:rs\.?|inr|₹|\$)\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:[.,][0-9]{1,2})?)|([0-9]{1,3}(?:[,\s][0-9]{3})*(?:[.,][0-9]{1,2})?)\s*(?:rs\.?|inr)',
      caseSensitive: false,
    );

    final matches = amountRegex.allMatches(body);

    for (var match in matches) {
      var raw = match.group(1) ?? match.group(2) ?? '';
      if (raw.isEmpty) continue;

      // Remove commas and spaces
      raw = raw.replaceAll(RegExp(r'[,\s]'), '');

      // Handle different decimal separators
      // If it looks like 1.234.56 (European style), convert to 1234.56
      if (raw.contains('.') && raw.indexOf('.') != raw.lastIndexOf('.')) {
        raw = raw.replaceAll('.', '');
      }
      // Replace comma with dot for decimal
      raw = raw.replaceAll(',', '.');

      try {
        final amount = double.parse(raw);
        if (amount > 0) {
          return amount;
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  DateTime? _extractDate(String body) {
    // Patterns for date extraction
    final patterns = [
      r'\b(\d{1,2}[-/]\w{3}[-/]\d{2,4})\b', // 14-Oct-25, 14/Oct/2025
      r'\b(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b', // 14-10-25, 14/10/2025
      r'\b(\d{4}[-/]\d{1,2}[-/]\d{1,2})\b', // 2025-10-14
      r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b', // 14 October 2025
    ];

    for (final p in patterns) {
      final m = RegExp(p, caseSensitive: false).firstMatch(body);
      if (m != null) {
        final s = m.group(1)!;

        final formats = [
          DateFormat('d-MMM-yy'),
          DateFormat('d/MMM/yy'),
          DateFormat('d-MMM-yyyy'),
          DateFormat('d/MMM/yyyy'),
          DateFormat('d-M-yy'),
          DateFormat('d/M/yy'),
          DateFormat('dd-MM-yyyy'),
          DateFormat('dd/MM/yyyy'),
          DateFormat('yyyy-MM-dd'),
          DateFormat('d MMM yyyy'),
          DateFormat('d MMMM yyyy'),
        ];

        for (final f in formats) {
          try {
            var parsed = f.parseLoose(s);
            // If year is 2-digit and less than 50, assume 2000s
            if (parsed.year < 100) {
              parsed = DateTime(parsed.year + 2000, parsed.month, parsed.day);
            }
            return parsed;
          } catch (_) {}
        }
      }
    }

    return null;
  }

  String _extractCategory(String body, String type) {
    // Try to extract merchant/payee name
    // Common patterns: "credited by X", "paid to X", "from X", etc.

    if (type == 'debit') {
      // Look for patterns like "paid to", "debited for"
      final patterns = [
        r'(?:paid to|debited for|at)\s+([A-Za-z0-9\s]+?)(?:\s+for|\s+on|\.|UPI)',
        r'([A-Z][A-Za-z0-9\s]{2,20})\s+credited',
      ];

      for (final p in patterns) {
        final m = RegExp(p, caseSensitive: false).firstMatch(body);
        if (m != null) {
          final merchant = m.group(1)?.trim() ?? '';
          if (merchant.length > 2 && merchant.length < 30) {
            return merchant;
          }
        }
      }
      return 'Expense';
    } else {
      // Look for patterns like "from X", "credited by X"
      final patterns = [
        r'(?:from|by)\s+([A-Za-z0-9\s]+?)(?:\.|UPI|$)',
        r'credited with.*from\s+([A-Z][A-Za-z0-9\s]{2,20})',
      ];

      for (final p in patterns) {
        final m = RegExp(p, caseSensitive: false).firstMatch(body);
        if (m != null) {
          final source = m.group(1)?.trim() ?? '';
          if (source.length > 2 && source.length < 30) {
            return source;
          }
        }
      }
      return 'Income';
    }
  }

  String _shorten(String s, [int len = 140]) =>
      s.length <= len ? s : '${s.substring(0, len)}...';
}

// Background message handler - stores message in Firestore for later processing
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  try {
    debugPrint('Background SMS handler called');

    // Store in Firestore for processing when app opens
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    await firestore.collection('sms_queue').add({
      'address': message.address ?? '',
      'body': message.body ?? '',
      'date': message.date ?? DateTime.now().millisecondsSinceEpoch,
      'receivedAt': FieldValue.serverTimestamp(),
      'processed': false,
    });

    debugPrint('Background SMS stored in queue');
  } catch (e) {
    debugPrint('Background handler error: $e');
  }
}
