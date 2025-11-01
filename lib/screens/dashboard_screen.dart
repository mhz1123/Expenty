
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/terminal_window.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';

enum Period { daily, weekly, monthly, yearly }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Period _selectedPeriod = Period.daily;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final transactions = appProvider.transactions;
    final budgets = appProvider.budgets;

    final totalIncome = transactions.where((t) => t.type == 'credit').fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = transactions.where((t) => t.type == 'debit').fold(0.0, (sum, t) => sum + t.amount);
    final balance = totalIncome - totalExpense;

    final compulsorySpending = budgets.where((b) => b.isCompulsory).fold(0.0, (sum, b) => sum + b.limit);
    final discretionaryBudget = budgets.where((b) => !b.isCompulsory).fold(0.0, (sum, b) => sum + b.limit);
    final discretionarySpent = budgets.where((b) => !b.isCompulsory).fold(0.0, (sum, b) => sum + b.spent);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            TerminalWindow(
              title: 'financial_overview.sh',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFinancialInfo('Total Income', '\$${totalIncome.toStringAsFixed(2)}', Colors.green),
                  _buildFinancialInfo('Total Expense', '\$${totalExpense.toStringAsFixed(2)}', Colors.red),
                  _buildFinancialInfo('Net Balance', '\$${balance.toStringAsFixed(2)}', balance >= 0 ? Colors.black : Colors.red),
                ],
              ),
            ),
            TerminalWindow(
              title: 'expenditure_analysis.sh',
              child: Column(
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 16.0),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      _getChartData(transactions),
                    ),
                  ),
                ],
              ),
            ),
            TerminalWindow(
              title: 'budget_status.sh',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildBudgetInfo('Compulsory', '\$${compulsorySpending.toStringAsFixed(2)}'),
                      ),
                      Expanded(
                        child: _buildBudgetInfo('Discretionary Limit', '\$${discretionaryBudget.toStringAsFixed(2)}'),
                      ),
                      Expanded(
                        child: _buildBudgetInfo('Discretionary Spent', '\$${discretionarySpent.toStringAsFixed(2)}', color: Colors.red),
                      ),
                      Expanded(
                        child: _buildBudgetInfo('Available', '\$${(discretionaryBudget - discretionarySpent).toStringAsFixed(2)}', color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  ...budgets.map((budget) => _buildBudgetListItem(budget)).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialInfo(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4.0),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: Period.values.map((period) {
        return ChoiceChip(
          label: Text(period.toString().split('.').last),
          selected: _selectedPeriod == period,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedPeriod = period;
              });
            }
          },
        );
      }).toList(),
    );
  }

  LineChartData _getChartData(List<Transaction> transactions) {
    // This is a simplified version of the chart data processing.
    // A more complete implementation would aggregate data by the selected period.
    final spots = <FlSpot>[];
    for (int i = 0; i < transactions.length; i++) {
      if (transactions[i].type == 'debit') {
        spots.add(FlSpot(i.toDouble(), transactions[i].amount));
      }
    }

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          belowBarData: BarAreaData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: true),
    );
  }

  Widget _buildBudgetInfo(String title, String value, {Color color = Colors.black}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4.0),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildBudgetListItem(dynamic budget) {
    double progress = 0;
    if (budget.limit > 0) {
      progress = budget.spent / budget.limit;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(budget.category, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('\$${budget.spent.toStringAsFixed(2)} / \$${budget.limit.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 4.0),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(progress > 0.8 ? Colors.red : Colors.blue),
          ),
        ],
      ),
    );
  }
}
