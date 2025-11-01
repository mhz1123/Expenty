import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/terminal_window.dart';
import '../models/transaction.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final transactions = appProvider.transactions;

    final totalPages = (transactions.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage > transactions.length ? transactions.length : startIndex + _itemsPerPage;
    final currentTransactions = transactions.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction Log',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            TerminalWindow(
              title: 'history -p $_currentPage',
              child: Column(
                children: [
                  _buildTransactionList(currentTransactions),
                  if (totalPages > 1)
                    _buildPaginationControls(totalPages),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Amount')),
        ],
        rows: transactions.map((t) {
          return DataRow(
            cells: [
              DataCell(Text(t.date.toLocal().toString().split(' ')[0])),
              DataCell(Text(t.description)),
              DataCell(Text(t.category)),
              DataCell(
                Text(
                  '${t.type == 'credit' ? '+' : '-'}\$${t.amount.toStringAsFixed(2)}',
                  style: TextStyle(color: t.type == 'credit' ? Colors.green : Colors.red),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          onPressed: _currentPage > 1
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
          onPressed: _currentPage < totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
          child: const Text('next >'),
        ),
      ],
    );
  }
}