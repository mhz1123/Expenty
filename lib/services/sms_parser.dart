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

  // loaded from Firestore config
  List<String> allowedSenders = [];
  List<String> debitKeywords = ['debited', 'withdrawn', 'paid', 'payment'];
  List<String> creditKeywords = ['credited', 'deposit', 'received'];

  SmsParserService({required this.appProvider});

  Future<void> start() async {
    // Load config once
    await _loadConfig();

    // Request permissions
    final bool? smsGranted = await _telephony.requestSmsPermissions;
    if (smsGranted != true) {
      debugPrint('SMS permissions not granted.');
      return;
    }

    // Start listening (foreground + optional background handler)
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        debugPrint('Foreground SMS: ${message.address} ${message.body}');
        await _processMessage(message, isBackground: false);
      },
      onBackgroundMessage: backgroundMessageHandler,
    );

    // Process any queued background messages that were stored earlier
    await processQueuedMessages();
  }

  Future<void> _loadConfig() async {
    try {
      final uid = _auth.currentUser?.uid;
      final docRef =
          uid == null
              ? _firestore.collection('sms_configs').doc('default')
              : _firestore.collection('sms_configs').doc(uid);

      final snap = await docRef.get();
      if (!snap.exists) return;

      final data = snap.data()!;
      if (data['allowedSenders'] is List) {
        allowedSenders = List<String>.from(data['allowedSenders']);
      }
      if (data['debitKeywords'] is List) {
        debitKeywords = List<String>.from(data['debitKeywords']);
      }
      if (data['creditKeywords'] is List) {
        creditKeywords = List<String>.from(data['creditKeywords']);
      }
      debugPrint('SMS config loaded: senders=${allowedSenders.length}');
    } catch (e) {
      debugPrint('Failed to load SMS config: $e');
    }
  }

  Future<void> _processMessage(
    dynamic message, {
    required bool isBackground,
  }) async {
    // Accept either an SmsMessage or a queued Map from Firestore
    final address =
        ((message is SmsMessage)
                ? (message.address ?? '')
                : (message is Map ? (message['address'] ?? '') : ''))
            .toString()
            .trim();
    final body =
        ((message is SmsMessage)
                ? (message.body ?? '')
                : (message is Map ? (message['body'] ?? '') : ''))
            .toString()
            .trim();

    // Filter by sender if configured
    if (allowedSenders.isNotEmpty) {
      final lowerAddr = address.toLowerCase();
      final matchedSender = allowedSenders.any(
        (s) => lowerAddr.contains(s.toLowerCase().trim()),
      );
      if (!matchedSender) {
        debugPrint('Sender $address not in allowedSenders -> ignore');
        return;
      }
    }

    final type = _detectType(body);
    if (type == null) {
      debugPrint('Message not recognized as credit/debit');
      return;
    }

    final amount = _extractAmount(body);
    if (amount == null) {
      debugPrint('Amount parse failed for: $body');
      return;
    }

    final date = _extractDate(body) ?? DateTime.now();

    final txn = Transaction(
      id: UniqueKey().toString(),
      amount: amount,
      date: date,
      type: type,
      category: 'sms',
      description: 'SMS ${address}: ${_shorten(body)}',
    );

    if (!isBackground) {
      // In foreground, we can call provider directly
      try {
        appProvider.addTransaction(txn);
      } catch (e) {
        debugPrint('addTransaction failed: $e');
      }
    } else {
      // If background (handler wrote raw to queue), this path may be used by
      // processQueuedMessages which runs in foreground to finalize processing.
      try {
        appProvider.addTransaction(txn);
      } catch (e) {
        debugPrint('addTransaction failed (background->foreground): $e');
      }
    }
  }

  String _shorten(String s, [int len = 140]) =>
      s.length <= len ? s : '${s.substring(0, len)}...';

  String? _detectType(String body) {
    final lc = body.toLowerCase();
    final hasDebit = debitKeywords.any((k) => lc.contains(k.toLowerCase()));
    final hasCredit = creditKeywords.any((k) => lc.contains(k.toLowerCase()));
    if (hasDebit && !hasCredit) return 'debit';
    if (hasCredit && !hasDebit) return 'credit';
    if (hasDebit) return 'debit';
    if (hasCredit) return 'credit';
    return null;
  }

  double? _extractAmount(String body) {
    final amountRegex = RegExp(
      r'(?:rs|inr|usd|eur|₹|\$)?\s*([0-9]{1,3}(?:[,.\s][0-9]{3})*(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    final match = amountRegex.firstMatch(body);
    if (match == null) return null;
    var raw = match.group(1) ?? '';
    raw = raw.replaceAll(RegExp(r'[,\s]'), '');
    // If dots used as thousand sep and comma as decimal, normalize
    if (raw.contains(RegExp(r'\.\d{3}'))) {
      raw = raw.replaceAll('.', '');
    } else {
      raw = raw.replaceAll(',', '.');
    }
    try {
      return double.parse(raw);
    } catch (_) {
      return null;
    }
  }

  DateTime? _extractDate(String body) {
    final patterns = [
      r'\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})\b',
      r'\b(\d{1,2}\s(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s\d{2,4})\b',
      r'\b(\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})\b',
    ];

    for (final p in patterns) {
      final m = RegExp(p, caseSensitive: false).firstMatch(body);
      if (m != null) {
        final s = m.group(1)!;
        final formats = [
          DateFormat('d/M/y'),
          DateFormat('d-M-y'),
          DateFormat('dd/MM/yyyy'),
          DateFormat('dd-MM-yyyy'),
          DateFormat('yyyy-M-d'),
          DateFormat('d MMM y'),
          DateFormat('d MMMM y'),
        ];
        for (final f in formats) {
          try {
            return f.parseLoose(s);
          } catch (_) {}
        }
        final parsed = DateTime.tryParse(s);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  // When the app starts, pick up queued background messages
  Future<void> processQueuedMessages() async {
    try {
      final querySnapshot =
          await _firestore
              .collection('sms_incoming_queue')
              .where('processed', isEqualTo: false)
              .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final address = data['address'] as String? ?? '';
        final body = data['body'] as String? ?? '';
        final queuedMsg = {
          'address': address,
          'body': body,
          'date': data['receivedAt'] ?? FieldValue.serverTimestamp(),
        };

        await _processMessage(queuedMsg, isBackground: true);

        await doc.reference.update({
          'processed': true,
          'processedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Processing queue failed: $e');
    }
  }
}

// Background handler — called by plugin when app is backgrounded
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  try {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore.collection('sms_incoming_queue').add({
      'address': message.address ?? '',
      'body': message.body ?? '',
      'receivedAt': FieldValue.serverTimestamp(),
      'processed': false,
    });
  } catch (e) {
    debugPrint('Background handler write failed: $e');
  }
}
