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
  bool _configLoaded = false;

  // Track processed messages to avoid duplicates
  final Set<String> _processedMessageIds = {};

  SmsParserService({required this.appProvider});

  Future<void> start() async {
    try {
      debugPrint('Starting SMS Parser Service...');

      // Wait for app provider to be initialized
      int attempts = 0;
      while (!appProvider.isInitialized && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (!appProvider.isInitialized) {
        debugPrint(
          'AppProvider not initialized after waiting. Using defaults.',
        );
      }

      // Load config from AppProvider (which got it from Firestore)
      await _loadConfig();

      if (!_configLoaded) {
        debugPrint('SMS config not loaded. SMS parsing disabled.');
        return;
      }

      debugPrint('SMS Config loaded successfully:');
      debugPrint('  Sender ID: "$senderId"');
      debugPrint('  Debit Keywords: $debitKeywords');
      debugPrint('  Credit Keywords: $creditKeywords');

      // Request SMS permissions
      final bool? permissionsGranted = await _telephony.requestSmsPermissions;

      if (permissionsGranted != true) {
        debugPrint('SMS permissions not granted.');
        return;
      }

      debugPrint('SMS permissions granted. Processing existing messages...');

      // Process any existing unread SMS messages
      await _processExistingSms();

      // Listen to incoming SMS in foreground
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          debugPrint('Foreground SMS received from: ${message.address}');
          await _processMessage(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
      );

      debugPrint('SMS Parser Service started successfully');
    } catch (e) {
      debugPrint('Error starting SMS Parser Service: $e');
    }
  }

  Future<void> _loadConfig() async {
    try {
      // Get config from AppProvider (which already loaded it from Firestore)
      final smsConfig = appProvider.smsConfig;

      if (smsConfig == null) {
        debugPrint('No SMS config available in AppProvider');
        _configLoaded = false;
        return;
      }

      senderId = smsConfig.senderId.trim();
      debitKeywords =
          smsConfig.debitKeywords.where((k) => k.trim().isNotEmpty).toList();
      creditKeywords =
          smsConfig.creditKeywords.where((k) => k.trim().isNotEmpty).toList();

      // Validate config
      if (debitKeywords.isEmpty && creditKeywords.isEmpty) {
        debugPrint(
          'Warning: No keywords configured. SMS parsing will be limited.',
        );
        _configLoaded = false;
        return;
      }

      _configLoaded = true;
      debugPrint('SMS config loaded from AppProvider');
    } catch (e) {
      debugPrint('Failed to load SMS config: $e');
      _configLoaded = false;
    }
  }

  /// Get the last SMS checkpoint timestamp from Firestore
  Future<DateTime?> _getLastCheckpoint() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final doc = await _firestore.collection('sms_checkpoints').doc(uid).get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['lastProcessedTime'] != null) {
          final timestamp = data['lastProcessedTime'] as Timestamp;
          debugPrint('Last checkpoint: ${timestamp.toDate()}');
          return timestamp.toDate();
        }
      }

      debugPrint('No checkpoint found, will process from 60 days ago');
      return null;
    } catch (e) {
      debugPrint('Error getting checkpoint: $e');
      return null;
    }
  }

  /// Update the last SMS checkpoint timestamp in Firestore
  Future<void> _updateCheckpoint(DateTime timestamp) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore.collection('sms_checkpoints').doc(uid).set({
        'lastProcessedTime': Timestamp.fromDate(timestamp),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Updated checkpoint to: $timestamp');
    } catch (e) {
      debugPrint('Error updating checkpoint: $e');
    }
  }

  Future<void> _processExistingSms() async {
    try {
      debugPrint('Processing existing SMS messages...');

      // Get the last checkpoint
      DateTime? lastCheckpoint = await _getLastCheckpoint();

      // If no checkpoint exists, default to 60 days ago
      final DateTime startDate =
          lastCheckpoint ?? DateTime.now().subtract(const Duration(days: 60));

      debugPrint('Processing SMS from: $startDate');

      List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.ID,
        ],
        filter: SmsFilter.where(
          SmsColumn.DATE,
        ).greaterThan(startDate.millisecondsSinceEpoch.toString()),
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.ASC),
        ], // Process oldest first
      );

      debugPrint('Found ${messages.length} messages after checkpoint');

      int processedCount = 0;
      int matchedCount = 0;
      DateTime? latestMessageTime;

      for (var message in messages) {
        final address = (message.address ?? '').toString().trim();
        final messageDate =
            message.date != null
                ? DateTime.fromMillisecondsSinceEpoch(message.date!)
                : DateTime.now();

        // Track the latest message time
        if (latestMessageTime == null ||
            messageDate.isAfter(latestMessageTime)) {
          latestMessageTime = messageDate;
        }

        // Filter by sender FIRST if configured
        if (senderId.isNotEmpty) {
          final lowerAddr = address.toLowerCase();
          final matchedSender = senderId
              .toLowerCase()
              .split(',')
              .any((s) => lowerAddr.contains(s.trim()));

          if (!matchedSender) {
            continue; // Skip this message
          }
          matchedCount++;
        }

        final processed = await _processMessage(message);
        if (processed) processedCount++;
      }

      // Update checkpoint to the latest message time
      if (latestMessageTime != null) {
        await _updateCheckpoint(latestMessageTime);
      } else if (messages.isEmpty) {
        // If no new messages, update checkpoint to current time
        await _updateCheckpoint(DateTime.now());
      }

      debugPrint('Finished processing SMS messages:');
      debugPrint('  Total messages after checkpoint: ${messages.length}');
      debugPrint('  Matched sender filter: $matchedCount');
      debugPrint('  Successfully parsed: $processedCount');
      debugPrint('  New checkpoint set to: $latestMessageTime');
    } catch (e) {
      debugPrint('Error processing existing SMS: $e');
    }
  }

  Future<bool> _processMessage(SmsMessage message) async {
    try {
      final address = (message.address ?? '').toString().trim();
      final body = (message.body ?? '').toString().trim();
      final messageId = '${address}_${message.date}_${body.hashCode}';

      // Skip if already processed in this session
      if (_processedMessageIds.contains(messageId)) {
        return false;
      }

      if (body.isEmpty) {
        return false;
      }

      // Filter by sender FIRST if configured
      if (senderId.isNotEmpty) {
        final lowerAddr = address.toLowerCase();
        final senderIds =
            senderId.toLowerCase().split(',').map((s) => s.trim()).toList();
        final matchedSender = senderIds.any((s) => lowerAddr.contains(s));

        if (!matchedSender) {
          debugPrint(
            '❌ Skipped: Sender "$address" does not match configured sender(s): $senderIds',
          );
          return false;
        }
      }

      debugPrint('📱 Processing message from $address');

      // Detect transaction type using configured keywords
      final type = _detectType(body);
      if (type == null) {
        debugPrint(
          '❌ Skipped: Not recognized as transaction: ${_shorten(body, 50)}',
        );
        return false;
      }

      // Extract amount
      final amount = _extractAmount(body);
      if (amount == null) {
        debugPrint(
          '❌ Skipped: Could not extract amount from: ${_shorten(body, 50)}',
        );
        return false;
      }

      // Extract date
      final date = _extractDate(body) ?? DateTime.now();

      // Extract category/merchant
      String category = _extractCategory(body, type);

      // Check if category exists in budgets, if not set to "Misc"
      final budgetCategories =
          appProvider.budgets.map((b) => b.category.toLowerCase()).toList();
      if (!budgetCategories.contains(category.toLowerCase())) {
        category = 'Misc';
      }

      // Check if transaction already exists in Firestore
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        // Check for exact match within a 1-hour window to avoid duplicates
        final dateStart = date.subtract(const Duration(hours: 1));
        final dateEnd = date.add(const Duration(hours: 1));

        final existingQuery =
            await _firestore
                .collection('transactions')
                .where('userId', isEqualTo: uid)
                .where('amount', isEqualTo: amount)
                .where('type', isEqualTo: type)
                .where(
                  'date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart),
                )
                .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dateEnd))
                .limit(1)
                .get();

        if (existingQuery.docs.isNotEmpty) {
          debugPrint('⚠️  Transaction already exists, skipping...');
          _processedMessageIds.add(messageId);
          return false;
        }
      }

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
        '✅ Adding transaction: $type ₹$amount on ${DateFormat('dd-MMM-yy').format(date)} - $category',
      );

      // Add to provider WITHOUT updating budget (updateBudget = false)
      await appProvider.addTransaction(txn, updateBudget: false);

      _processedMessageIds.add(messageId);

      // Update checkpoint for real-time messages
      final messageDate =
          message.date != null
              ? DateTime.fromMillisecondsSinceEpoch(message.date!)
              : DateTime.now();
      await _updateCheckpoint(messageDate);

      debugPrint('✅ Transaction added successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error processing message: $e');
      return false;
    }
  }

  String? _detectType(String body) {
    final lc = body.toLowerCase();

    // Check for debit keywords from config
    final hasDebit = debitKeywords.any(
      (k) => lc.contains(k.toLowerCase().trim()),
    );

    // Check for credit keywords from config
    final hasCredit = creditKeywords.any(
      (k) => lc.contains(k.toLowerCase().trim()),
    );

    if (hasDebit && !hasCredit) {
      debugPrint('  Type: DEBIT (matched keyword)');
      return 'debit';
    }
    if (hasCredit && !hasDebit) {
      debugPrint('  Type: CREDIT (matched keyword)');
      return 'credit';
    }

    // If both or neither matched, check common fallback patterns
    if (lc.contains('debited') ||
        lc.contains('withdrawn') ||
        lc.contains('spent') ||
        lc.contains('purchased')) {
      debugPrint('  Type: DEBIT (fallback pattern)');
      return 'debit';
    }
    if (lc.contains('credited') ||
        lc.contains('received') ||
        lc.contains('deposit')) {
      debugPrint('  Type: CREDIT (fallback pattern)');
      return 'credit';
    }

    debugPrint('  Type: UNKNOWN');
    return null;
  }

  double? _extractAmount(String body) {
    // Pattern to match amounts in various formats
    // Rs 100.00, Rs. 100, INR 100.00, 100.00, Rs100, ₹100, etc.
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
          debugPrint('  Amount: ₹$amount');
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
