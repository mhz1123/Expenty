import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../widgets/terminal_window.dart';
import '../models/transaction.dart';
import '../models/budget.dart';

enum Period { daily, weekly, monthly, yearly }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Period _selectedPeriod = Period.daily;

  // Added: shared color palette for categories so chart and legend match
  final List<Color> _categoryColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final List<Transaction> transactions = appProvider.transactions;
    final List<Budget> budgets = appProvider.budgets;

    // compute expenditures and categories for legend (matches chart)
    final expenditures = transactions.where((t) => t.type == 'debit').toList();
    final categories = expenditures.map((t) => t.category).toSet().toList();

    final totalIncome = transactions
        .where((t) => t.type == 'credit')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = transactions
        .where((t) => t.type == 'debit')
        .fold(0.0, (sum, t) => sum + t.amount);
    final balance = totalIncome - totalExpense;

    final compulsorySpending = budgets
        .where((b) => b.isCompulsory)
        .fold(0.0, (sum, b) => sum + b.limit);
    final discretionaryBudget = budgets
        .where((b) => !b.isCompulsory)
        .fold(0.0, (sum, b) => sum + b.limit);
    final discretionarySpent = budgets
        .where((b) => !b.isCompulsory)
        .fold(0.0, (sum, b) => sum + b.spent);

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
                  _buildFinancialInfo(
                    'Total Income',
                    '\$${totalIncome.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                  _buildFinancialInfo(
                    'Total Expense',
                    '\$${totalExpense.toStringAsFixed(2)}',
                    Colors.red,
                  ),
                  _buildFinancialInfo(
                    'Net Balance',
                    '\$${balance.toStringAsFixed(2)}',
                    balance >= 0 ? Colors.black : Colors.red,
                  ),
                ],
              ),
            ),
            TerminalWindow(
              title: 'expenditure_analysis.sh',
              child: Column(
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 16.0),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        height: 250,
                        width: _getChartWidth(),
                        child: LineChart(_getChartData(transactions, budgets)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  // Legend placed below the chart
                  _buildLegend(categories),
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
                        child: _buildBudgetInfo(
                          'Compulsory',
                          '\$${compulsorySpending.toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _buildBudgetInfo(
                          'Discretionary Limit',
                          '\$${discretionaryBudget.toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _buildBudgetInfo(
                          'Discretionary Spent',
                          '\$${discretionarySpent.toStringAsFixed(2)}',
                          color: Colors.red,
                        ),
                      ),
                      Expanded(
                        child: _buildBudgetInfo(
                          'Available',
                          '\$${(discretionaryBudget - discretionarySpent).toStringAsFixed(2)}',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  ...budgets
                      .map((budget) => _buildBudgetListItem(budget))
                      .toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getChartWidth() {
    switch (_selectedPeriod) {
      case Period.daily:
        return 600; // 7 days
      case Period.weekly:
        return 600; // 4-5 weeks
      case Period.monthly:
        return 800; // 12 months
      case Period.yearly:
        return 600; // Years
    }
  }

  Widget _buildFinancialInfo(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:
          Period.values.map((period) {
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

  LineChartData _getChartData(
    List<Transaction> transactions,
    List<Budget> budgets,
  ) {
    final now = DateTime.now();
    final expenditures = transactions.where((t) => t.type == 'debit').toList();

    // Get all time slots for the selected period
    final allSlots = _getAllTimeSlots(now, transactions);
    final slotLabels = _getSlotLabels(allSlots);

    // Calculate total budget limit for the period
    final totalBudgetLimit = budgets.fold(0.0, (sum, b) => sum + b.limit);
    final periodBudgetLimit = _calculatePeriodBudgetLimit(totalBudgetLimit);

    // Aggregate data by category
    final categories = expenditures.map((t) => t.category).toSet().toList();
    final lineBarsData = <LineChartBarData>[];
    // Use shared colors defined on the state so legend and chart are consistent
    final colors = _categoryColors;

    double maxY = periodBudgetLimit > 0 ? periodBudgetLimit : 100;

    // Create data for each category
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final categoryExpenditures =
          expenditures.where((t) => t.category == category).toList();
      final spots = _aggregateDataForAllSlots(categoryExpenditures, allSlots);

      if (spots.isEmpty) continue;

      // Update max Y
      for (var spot in spots) {
        if (spot.y > maxY) maxY = spot.y;
      }

      // Add expenditure line
      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: colors[i % colors.length],
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: colors[i % colors.length],
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: colors[i % colors.length].withOpacity(0.1),
          ),
        ),
      );
    }

    // Add budget limit line (horizontal dotted line)
    if (periodBudgetLimit > 0) {
      final budgetSpots = <FlSpot>[];
      for (int i = 0; i < allSlots.length; i++) {
        budgetSpots.add(FlSpot(i.toDouble(), periodBudgetLimit));
      }

      lineBarsData.add(
        LineChartBarData(
          spots: budgetSpots,
          isCurved: false,
          color: Colors.red.withOpacity(0.7),
          barWidth: 2,
          isStrokeCapRound: false,
          dotData: FlDotData(show: false),
          dashArray: [8, 4],
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return LineChartData(
      lineBarsData: lineBarsData,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: maxY > 0 ? maxY / 5 : 20,
            getTitlesWidget: (value, meta) {
              return Text(
                '\$${value.toInt()}',
                style: const TextStyle(fontSize: 10, color: Colors.black),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < slotLabels.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    slotLabels[index],
                    style: const TextStyle(fontSize: 10, color: Colors.black),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: maxY > 0 ? maxY / 5 : 20,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 1);
        },
        getDrawingVerticalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 1);
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey, width: 1),
      ),
      minX: 0,
      maxX: (allSlots.length - 1).toDouble(),
      minY: 0,
      maxY: maxY * 1.2,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '\$${spot.y.toStringAsFixed(2)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  List<String> _getAllTimeSlots(DateTime now, List<Transaction> transactions) {
    switch (_selectedPeriod) {
      case Period.daily:
        // Get all 7 days of current week
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return List.generate(7, (i) {
          final date = weekStart.add(Duration(days: i));
          return DateFormat('yyyy-MM-dd').format(date);
        });

      case Period.weekly:
        // Get all weeks of current month (typically 4-5 weeks)
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0);
        final weeks = <String>[];
        DateTime current = monthStart;

        while (current.isBefore(monthEnd) ||
            current.isAtSameMomentAs(monthEnd)) {
          final weekNumber =
              ((current.difference(DateTime(current.year, 1, 1)).inDays) / 7)
                  .floor() +
              1;
          final weekKey =
              '${current.year}-W${weekNumber.toString().padLeft(2, '0')}';
          if (!weeks.contains(weekKey)) {
            weeks.add(weekKey);
          }
          current = current.add(const Duration(days: 7));
        }
        return weeks;

      case Period.monthly:
        // Get all 12 months of current year
        return List.generate(12, (i) {
          final month = DateTime(now.year, i + 1);
          return DateFormat('yyyy-MM').format(month);
        });

      case Period.yearly:
        // Get all years from first transaction to now
        final years =
            transactions.map((t) => t.date.year).toSet().toList()..sort();

        if (years.isEmpty) {
          return [now.year.toString()];
        }

        return List.generate(
          years.last - years.first + 1,
          (i) => (years.first + i).toString(),
        );
    }
  }

  List<String> _getSlotLabels(List<String> slots) {
    return slots.map((slot) {
      switch (_selectedPeriod) {
        case Period.daily:
          try {
            final date = DateFormat('yyyy-MM-dd').parse(slot);
            return DateFormat('EEE').format(date);
          } catch (e) {
            return '';
          }

        case Period.weekly:
          final parts = slot.split('-W');
          if (parts.length == 2) {
            return 'W${parts[1]}';
          }
          return '';

        case Period.monthly:
          try {
            final date = DateFormat('yyyy-MM').parse(slot);
            return DateFormat('MMM').format(date);
          } catch (e) {
            return '';
          }

        case Period.yearly:
          return slot;
      }
    }).toList();
  }

  List<FlSpot> _aggregateDataForAllSlots(
    List<Transaction> transactions,
    List<String> allSlots,
  ) {
    final data = <String, double>{};

    // Initialize all slots with 0
    for (var slot in allSlots) {
      data[slot] = 0.0;
    }

    // Aggregate transaction data
    for (var t in transactions) {
      String key;
      switch (_selectedPeriod) {
        case Period.daily:
          key = DateFormat('yyyy-MM-dd').format(t.date);
          break;
        case Period.weekly:
          final weekNumber =
              ((t.date.difference(DateTime(t.date.year, 1, 1)).inDays) / 7)
                  .floor() +
              1;
          key = '${t.date.year}-W${weekNumber.toString().padLeft(2, '0')}';
          break;
        case Period.monthly:
          key = DateFormat('yyyy-MM').format(t.date);
          break;
        case Period.yearly:
          key = t.date.year.toString();
          break;
      }

      if (data.containsKey(key)) {
        data[key] = data[key]! + t.amount;
      }
    }

    // Create spots for all slots
    final spots = <FlSpot>[];
    for (int i = 0; i < allSlots.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[allSlots[i]]!));
    }

    return spots;
  }

  double _calculatePeriodBudgetLimit(double monthlyBudget) {
    if (monthlyBudget == 0) return 0;

    switch (_selectedPeriod) {
      case Period.daily:
        return monthlyBudget / 30; // Daily limit
      case Period.weekly:
        return monthlyBudget / 4; // Weekly limit
      case Period.monthly:
        return monthlyBudget; // Monthly limit
      case Period.yearly:
        return monthlyBudget * 12; // Yearly limit
    }
  }

  Widget _buildBudgetInfo(
    String title,
    String value, {
    Color color = Colors.black,
  }) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetListItem(Budget budget) {
    double progress = 0;
    if (budget.limit > 0) {
      progress = budget.spent / budget.limit;
      if (progress > 1.0) progress = 1.0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.category,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${budget.spent.toStringAsFixed(2)} / \$${budget.limit.toStringAsFixed(2)}',
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 0.8 ? Colors.red : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // New: build a small legend matching category order and colors used in the chart
  Widget _buildLegend(List<String> categories) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 8.0,
        children: List.generate(categories.length, (i) {
          final color = _categoryColors[i % _categoryColors.length];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(categories[i], style: const TextStyle(fontSize: 12)),
            ],
          );
        }),
      ),
    );
  }
}
