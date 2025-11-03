import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/sms_config.dart';
import '../services/sms_parser.dart';

class SmsConfigDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const SmsConfigDialog({Key? key, required this.onSaved}) : super(key: key);

  @override
  _SmsConfigDialogState createState() => _SmsConfigDialogState();
}

class _SmsConfigDialogState extends State<SmsConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _senderIdController = TextEditingController();
  final _debitKeywordsController = TextEditingController();
  final _creditKeywordsController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  void _loadExistingConfig() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final smsConfig = appProvider.smsConfig;

    if (smsConfig != null) {
      _senderIdController.text = smsConfig.senderId;
      _debitKeywordsController.text = smsConfig.debitKeywords.join(', ');
      _creditKeywordsController.text = smsConfig.creditKeywords.join(', ');
    } else {
      // Default values
      _debitKeywordsController.text = 'debited, withdrawn, paid, spent';
      _creditKeywordsController.text = 'credited, received, deposit';
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final appProvider = Provider.of<AppProvider>(context, listen: false);

      final newConfig = SmsConfig(
        id: appProvider.smsConfig?.id ?? '',
        senderId: _senderIdController.text.trim(),
        debitKeywords:
            _debitKeywordsController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
        creditKeywords:
            _creditKeywordsController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
      );

      try {
        await appProvider.updateSmsConfig(newConfig);

        if (!mounted) return;

        // Process existing SMS messages
        setState(() {
          _isLoading = true;
        });

        final smsService = SmsParserService(appProvider: appProvider);
        await smsService.start();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS configuration saved and messages processed!'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onSaved();
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isSaving = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _skipForNow() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Skip SMS Configuration?'),
            content: const Text(
              'You can configure SMS parsing later from the SMS Config screen. '
              'Without this, transactions won\'t be automatically added from SMS.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onSaved();
                },
                child: const Text('Skip'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _senderIdController.dispose();
    _debitKeywordsController.dispose();
    _creditKeywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5F5F5),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child:
            _isLoading
                ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Processing SMS messages...',
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SMS Configuration',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _isSaving ? null : _skipForNow,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configure SMS parsing to automatically track transactions from bank SMS.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _senderIdController,
                          decoration: const InputDecoration(
                            labelText: 'Bank Sender ID',
                            hintText: 'e.g., AM-HDFCBK, SBIINB',
                            helperText: 'The sender name in your bank SMS',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a sender ID';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _debitKeywordsController,
                          decoration: const InputDecoration(
                            labelText: 'Debit Keywords',
                            hintText: 'debited, withdrawn, paid, spent',
                            helperText: 'Comma-separated keywords for expenses',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter at least one debit keyword';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _creditKeywordsController,
                          decoration: const InputDecoration(
                            labelText: 'Credit Keywords',
                            hintText: 'credited, received, deposit',
                            helperText: 'Comma-separated keywords for income',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter at least one credit keyword';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Check a bank SMS to find the sender ID. '
                                  'Keywords help identify debit/credit transactions.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSaving ? null : _skipForNow,
                              child: const Text('Skip for now'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              child:
                                  _isSaving
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Text('Save & Process SMS'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
