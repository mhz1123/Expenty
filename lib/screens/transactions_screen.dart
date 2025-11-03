import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/terminal_window.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
  bool _isSelectionMode = false;
  final Set<String> _selectedTransactions = {};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTransactions.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedTransactions.contains(id)) {
        _selectedTransactions.remove(id);
      } else {
        _selectedTransactions.add(id);
      }
    });
  }

  void _selectAll(List<Transaction> transactions) {
    setState(() {
      if (_selectedTransactions.length == transactions.length) {
        _selectedTransactions.clear();
      } else {
        _selectedTransactions.clear();
        _selectedTransactions.addAll(transactions.map((t) => t.id));
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedTransactions.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text(
              'Delete ${_selectedTransactions.length} transaction(s)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.deleteTransactions(_selectedTransactions.toList());

      setState(() {
        _selectedTransactions.clear();
        _isSelectionMode = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transactions deleted')));
    }
  }

  Future<void> _bulkChangeCategory() async {
    if (_selectedTransactions.isEmpty) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final categories = appProvider.budgets.map((b) => b.category).toList();
    categories.add('Misc');

    final newCategory = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Category'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Update ${_selectedTransactions.length} transaction(s)'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'New Category'),
                  items:
                      categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                  onChanged: (value) {
                    Navigator.pop(context, value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    if (newCategory != null) {
      await appProvider.updateTransactionCategories(
        _selectedTransactions.toList(),
        newCategory,
      );

      setState(() {
        _selectedTransactions.clear();
        _isSelectionMode = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category updated to $newCategory')),
      );
    }
  }

  Future<void> _editTransaction(Transaction transaction) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final categories = appProvider.budgets.map((b) => b.category).toList();
    categories.add('Misc');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => _EditTransactionDialog(
            transaction: transaction,
            categories: categories,
          ),
    );

    if (result != null) {
      await appProvider.updateTransaction(
        transaction.id,
        result['category'] as String,
        result['description'] as String,
        result['amount'] as double,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction updated')));
    }
  }

  Future<void> _deleteTransaction(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text('Delete this transaction?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.deleteTransactions([id]);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final transactions = appProvider.transactions;

    final totalPages = (transactions.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex =
        startIndex + _itemsPerPage > transactions.length
            ? transactions.length
            : startIndex + _itemsPerPage;
    final currentTransactions = transactions.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Transaction Log',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Wrap(
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    if (_isSelectionMode) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: _bulkDelete,
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.category,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: _bulkChangeCategory,
                        tooltip: 'Category',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.select_all, size: 20),
                        onPressed: () => _selectAll(currentTransactions),
                        tooltip: 'Select All',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                    IconButton(
                      icon: Icon(
                        _isSelectionMode
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                      ),
                      onPressed: _toggleSelectionMode,
                      tooltip:
                          _isSelectionMode
                              ? 'Exit Selection'
                              : 'Select Multiple',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            if (_isSelectionMode && _selectedTransactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${_selectedTransactions.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            const SizedBox(height: 16.0),
            TerminalWindow(
              title: 'history -p $_currentPage',
              child: Column(
                children: [
                  _buildTransactionList(currentTransactions),
                  if (totalPages > 1) _buildPaginationControls(totalPages),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('No transactions yet')),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          if (_isSelectionMode) const DataColumn(label: SizedBox(width: 20)),
          const DataColumn(label: Text('Date')),
          const DataColumn(label: Text('Description')),
          const DataColumn(label: Text('Category')),
          const DataColumn(label: Text('Amount')),
          const DataColumn(label: Text('Actions')),
        ],
        rows:
            transactions.map((t) {
              final isSelected = _selectedTransactions.contains(t.id);

              return DataRow(
                selected: isSelected,
                onSelectChanged:
                    _isSelectionMode ? (_) => _toggleSelection(t.id) : null,
                cells: [
                  if (_isSelectionMode)
                    DataCell(
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(t.id),
                      ),
                    ),
                  DataCell(Text(DateFormat('dd-MMM-yy').format(t.date))),
                  DataCell(
                    SizedBox(
                      width: 200,
                      child: Text(
                        t.description,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(t.category)),
                  DataCell(
                    Text(
                      '${t.type == 'credit' ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: t.type == 'credit' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _editTransaction(t),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteTransaction(t.id),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed:
                _currentPage > 1
                    ? () {
                      setState(() {
                        _currentPage--;
                      });
                    }
                    : null,
            child: const Text('< prev'),
          ),
          Text('Page $_currentPage of $totalPages'),
          ElevatedButton(
            onPressed:
                _currentPage < totalPages
                    ? () {
                      setState(() {
                        _currentPage++;
                      });
                    }
                    : null,
            child: const Text('next >'),
          ),
        ],
      ),
    );
  }
}

class _EditTransactionDialog extends StatefulWidget {
  final Transaction transaction;
  final List<String> categories;

  const _EditTransactionDialog({
    required this.transaction,
    required this.categories,
  });

  @override
  _EditTransactionDialogState createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.transaction.description,
    );
    _amountController = TextEditingController(
      text: widget.transaction.amount.toString(),
    );
    _selectedCategory = widget.transaction.category;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Transaction'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items:
                  widget.categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(_amountController.text);
            if (amount != null && _descriptionController.text.isNotEmpty) {
              Navigator.pop(context, {
                'category': _selectedCategory,
                'description': _descriptionController.text,
                'amount': amount,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
