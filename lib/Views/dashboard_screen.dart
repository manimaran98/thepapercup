import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../services/sales_service.dart';
import '../modal/receipt_model.dart';
import '../services/receipt_service.dart';
import 'package:thepapercup/modal/receipt_model.dart';
import 'package:thepapercup/services/receipt_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime selectedDate = DateTime.now();
  String selectedPeriod = 'Today'; // Today, Week, Month, Year
  bool isLoading = true;
  bool showByAmount = true; // Toggle between amount and quantity

  final SalesService _salesService = SalesService();

  // Analytics Data
  Map<String, double> salesData = {};
  Map<String, double> categoryData = {};
  Map<String, double> paymentData = {};
  Map<String, double> profitData = {};
  Map<String, dynamic> inventoryData = {};

  // Quantity Data
  Map<String, int> categoryQuantityData = {};
  Map<String, int> paymentQuantityData = {};

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  DateTime _getStartDate() {
    final date =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    switch (selectedPeriod) {
      case 'Today':
        return date;
      case 'Week':
        // Get the start of the selected week (Monday)
        final monday = date.subtract(Duration(days: date.weekday - 1));
        return monday;
      case 'Month':
        // Get the start of the selected month
        return DateTime(date.year, date.month, 1);
      case 'Year':
        // Get the start of the selected year
        return DateTime(date.year, 1, 1);
      default:
        return date;
    }
  }

  DateTime _getEndDate() {
    final date =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    switch (selectedPeriod) {
      case 'Today':
        // End of selected day
        return date
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
      case 'Week':
        // End of the selected week (Sunday)
        final monday = date.subtract(Duration(days: date.weekday - 1));
        return monday
            .add(const Duration(days: 7))
            .subtract(const Duration(milliseconds: 1));
      case 'Month':
        // End of the selected month
        final lastDay = DateTime(date.year, date.month + 1, 0);
        return DateTime(
            lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999);
      case 'Year':
        // End of the selected year
        return DateTime(date.year, 12, 31, 23, 59, 59, 999);
      default:
        return date
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
    }
  }

  Future<void> loadDashboardData() async {
    setState(() => isLoading = true);
    try {
      // Get date range based on selected period
      DateTime startDate = _getStartDate();
      DateTime endDate = _getEndDate();

      print('Loading data for period: $selectedPeriod');
      print('Selected date: $selectedDate');
      print('Start date: $startDate');
      print('End date: $endDate');

      // Load sales data
      salesData = await _salesService.getTopSellingItems(startDate, endDate);

      // Load category data
      categoryData = await _salesService.getSalesByCategory(startDate, endDate);
      categoryQuantityData =
          await _salesService.getSalesQuantityByCategory(startDate, endDate);

      // Load payment method data
      paymentData =
          await _salesService.getSalesByPaymentMethod(startDate, endDate);
      paymentQuantityData = await _salesService.getSalesQuantityByPaymentMethod(
          startDate, endDate);

      // Load profit data
      profitData = await _salesService.getProfitAnalysis(startDate, endDate);

      // Load inventory data
      await _loadInventoryData();

      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadInventoryData() async {
    try {
      final QuerySnapshot inventorySnapshot =
          await FirebaseFirestore.instance.collection('itemsForSale').get();

      Map<String, dynamic> inventory = {};
      for (var doc in inventorySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        inventory[data['name'] as String] = {
          'quantity': data['quantity'] ?? 0,
          'category': data['category'] ?? 'Uncategorized',
          'lastUpdated': data['lastUpdated'] ?? DateTime.now(),
        };
      }

      setState(() {
        inventoryData = inventory;
      });
    } catch (e) {
      print('Error loading inventory data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  selectedDate = picked;
                  // When a specific date is selected, set period to Today
                  selectedPeriod = 'Today';
                });
                loadDashboardData();
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                selectedPeriod = value;
                // Don't reset selectedDate when changing period
              });
              loadDashboardData();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'Today',
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: 'Week',
                child: Text('This Week'),
              ),
              const PopupMenuItem(
                value: 'Month',
                child: Text('This Month'),
              ),
              const PopupMenuItem(
                value: 'Year',
                child: Text('This Year'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: generateReport,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter
            Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Today', label: Text('Today')),
                    ButtonSegment(value: 'Week', label: Text('Week')),
                    ButtonSegment(value: 'Month', label: Text('Month')),
                    ButtonSegment(value: 'Year', label: Text('Year')),
                  ],
                  selected: {selectedPeriod},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      selectedPeriod = newSelection.first;
                      selectedDate = DateTime.now(); // Reset to current date
                    });
                    loadDashboardData();
                  },
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                        selectedPeriod = 'Today';
                      });
                      loadDashboardData();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // View Toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('By Amount')),
                ButtonSegment(value: false, label: Text('By Quantity')),
              ],
              selected: {showByAmount},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  showByAmount = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    'RM${profitData['revenue']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Orders',
                    '${salesData.length}',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Average Order',
                    'RM${profitData['revenue']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.analytics,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Charts
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.6, // Further adjusted aspect ratio
                    child: _buildChartCard(
                      'Sales by Category',
                      _buildCategoryChart(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.6, // Further adjusted aspect ratio
                    child: _buildChartCard(
                      'Sales by Payment Method',
                      _buildPaymentMethodChart(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Recent Transactions
            _buildChartCard(
              'Recent Transactions',
              Column(
                children: [
                  // View All Transactions Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TransactionHistoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('View All Transactions'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Recent Transactions List
                  SizedBox(
                    height: 100, // Further reduced fixed height
                    child: StreamBuilder<List<ReceiptModel>>(
                      stream: ReceiptService().getReceipts(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final receipts = snapshot.data ?? [];
                        if (receipts.isEmpty) {
                          return const Center(
                            child: Text('No transactions found'),
                          );
                        }

                        // Get only the latest receipt
                        final latestReceipt = receipts.first;

                        return ListView(
                          children: [
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getPaymentMethodColor(
                                      latestReceipt.paymentMethod),
                                  child: Icon(
                                    _getPaymentMethodIcon(
                                        latestReceipt.paymentMethod),
                                    color: Colors.white,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Receipt #${latestReceipt.id}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(
                                      'RM${latestReceipt.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${DateFormat('dd/MM/yyyy HH:mm').format(latestReceipt.timestamp)} - ${latestReceipt.paymentMethod}',
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          '${latestReceipt.items.length} items',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (latestReceipt.isPrinted)
                                          const Icon(Icons.print,
                                              size: 16, color: Colors.blue),
                                        if (latestReceipt.isEmailed)
                                          const Icon(Icons.email,
                                              size: 16, color: Colors.orange),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () => _showReceiptDetails(latestReceipt),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopSellingItems() {
    final sortedItems = salesData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedItems.take(5).map((entry) {
      return Card(
        child: ListTile(
          title: Text(entry.key),
          trailing: Text(
            'RM${entry.value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildLowStockItems() {
    final lowStockItems = inventoryData.entries
        .where((entry) => (entry.value['quantity'] as int) < 10)
        .toList();

    return lowStockItems.map((entry) {
      return Card(
        child: ListTile(
          title: Text(entry.key),
          subtitle: Text('Category: ${entry.value['category']}'),
          trailing: Text(
            'Qty: ${entry.value['quantity']}',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> generateReport() async {
    final pdf = pw.Document();

    // Add content to PDF
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          children: [
            pw.Header(
              level: 0,
              child: pw.Text(
                  'Sales Report - ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Sales by Item'),
            pw.Table.fromTextArray(
              data: salesData.entries
                  .map((e) => [e.key, 'RM${e.value.toStringAsFixed(2)}'])
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Sales by Category'),
            pw.Table.fromTextArray(
              data: categoryData.entries
                  .map((e) => [e.key, 'RM${e.value.toStringAsFixed(2)}'])
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Payment Methods'),
            pw.Table.fromTextArray(
              data: paymentData.entries
                  .map((e) => [e.key, 'RM${e.value.toStringAsFixed(2)}'])
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Profit Analysis'),
            pw.Table.fromTextArray(
              data: [
                [
                  'Revenue',
                  'RM${profitData['revenue']?.toStringAsFixed(2) ?? '0.00'}'
                ],
                [
                  'Cost',
                  'RM${profitData['cost']?.toStringAsFixed(2) ?? '0.00'}'
                ],
                [
                  'Profit',
                  'RM${profitData['profit']?.toStringAsFixed(2) ?? '0.00'}'
                ],
                [
                  'Margin',
                  '${profitData['margin']?.toStringAsFixed(2) ?? '0.00'}%'
                ],
              ],
            ),
          ],
        ),
      ),
    );

    // Save PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/report.pdf');
    await file.writeAsBytes(await pdf.save());

    // Share PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Sales Report - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
    );
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'qr':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'qr':
        return Icons.qr_code;
      default:
        return Icons.payment;
    }
  }

  void _showReceiptDetails(ReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receipt #: ${receipt.id}'),
              Text(
                  'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(receipt.timestamp)}'),
              Text('Payment Method: ${receipt.paymentMethod}'),
              const Divider(),
              ...receipt.items.map((item) => Text(
                    '${item['name']} x${item['quantity']} - RM${item['total'].toStringAsFixed(2)}',
                  )),
              const Divider(),
              Text('Total: RM${receipt.total.toStringAsFixed(2)}'),
              if (receipt.change != null)
                Text('Change: RM${receipt.change!.toStringAsFixed(2)}'),
              if (receipt.customerEmail != null)
                Text('Email: ${receipt.customerEmail}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ReceiptService().printReceipt(receipt);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error printing receipt: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    if (categoryData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: showByAmount
            ? categoryData.values.reduce((a, b) => a > b ? a : b) * 1.2
            : categoryQuantityData.values.reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final category = categoryData.keys.elementAt(groupIndex);
              final value = showByAmount
                  ? 'RM${categoryData[category]?.toStringAsFixed(2)}'
                  : '${categoryQuantityData[category]} units';
              return BarTooltipItem(
                '$category\n$value',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value >= 0 && value < categoryData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      categoryData.keys.elementAt(value.toInt()),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  showByAmount
                      ? 'RM${value.toStringAsFixed(0)}'
                      : '${value.toInt()}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: categoryData.entries.map((entry) {
          final index = categoryData.keys.toList().indexOf(entry.key);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: showByAmount
                    ? entry.value
                    : categoryQuantityData[entry.key]?.toDouble() ?? 0,
                color: Colors.blue,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentMethodChart() {
    if (paymentData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: showByAmount
            ? paymentData.values.reduce((a, b) => a > b ? a : b) * 1.2
            : paymentQuantityData.values.reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final method = paymentData.keys.elementAt(groupIndex);
              final value = showByAmount
                  ? 'RM${paymentData[method]?.toStringAsFixed(2)}'
                  : '${paymentQuantityData[method]} units';
              return BarTooltipItem(
                '$method\n$value',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value >= 0 && value < paymentData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      paymentData.keys.elementAt(value.toInt()),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  showByAmount
                      ? 'RM${value.toStringAsFixed(0)}'
                      : '${value.toInt()}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: paymentData.entries.map((entry) {
          final index = paymentData.keys.toList().indexOf(entry.key);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: showByAmount
                    ? entry.value
                    : paymentQuantityData[entry.key]?.toDouble() ?? 0,
                color: Colors.green,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionSummaryItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
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
}

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'qr':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'qr':
        return Icons.qr_code;
      default:
        return Icons.payment;
    }
  }

  void _showReceiptDetails(BuildContext context, ReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receipt #: ${receipt.id}'),
              Text(
                  'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(receipt.timestamp)}'),
              Text('Payment Method: ${receipt.paymentMethod}'),
              const Divider(),
              ...receipt.items.map((item) => Text(
                    '${item['name']} x${item['quantity']} - RM${item['total'].toStringAsFixed(2)}',
                  )),
              const Divider(),
              Text('Total: RM${receipt.total.toStringAsFixed(2)}'),
              if (receipt.change != null)
                Text('Change: RM${receipt.change!.toStringAsFixed(2)}'),
              if (receipt.customerEmail != null)
                Text('Email: ${receipt.customerEmail}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ReceiptService().printReceipt(receipt);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error printing receipt: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filtering options
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ReceiptModel>>(
        stream: ReceiptService().getReceipts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final receipts = snapshot.data ?? [];
          if (receipts.isEmpty) {
            return const Center(
              child: Text('No transactions found'),
            );
          }

          return Column(
            children: [
              // Transaction Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTransactionSummaryItem(
                      'Total Sales',
                      'RM${receipts.fold(0.0, (sum, receipt) => sum + receipt.total).toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                    _buildTransactionSummaryItem(
                      'Total Orders',
                      receipts.length.toString(),
                      Icons.shopping_cart,
                      Colors.blue,
                    ),
                    _buildTransactionSummaryItem(
                      'Average Order',
                      'RM${(receipts.fold(0.0, (sum, receipt) => sum + receipt.total) / receipts.length).toStringAsFixed(2)}',
                      Icons.analytics,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Transaction List
              Expanded(
                child: ListView.builder(
                  itemCount: receipts.length,
                  itemBuilder: (context, index) {
                    final receipt = receipts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _getPaymentMethodColor(receipt.paymentMethod),
                          child: Icon(
                            _getPaymentMethodIcon(receipt.paymentMethod),
                            color: Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Receipt #${receipt.id}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              'RM${receipt.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${DateFormat('dd/MM/yyyy HH:mm').format(receipt.timestamp)} - ${receipt.paymentMethod}',
                            ),
                            Row(
                              children: [
                                Text(
                                  '${receipt.items.length} items',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                if (receipt.isPrinted)
                                  const Icon(Icons.print,
                                      size: 16, color: Colors.blue),
                                if (receipt.isEmailed)
                                  const Icon(Icons.email,
                                      size: 16, color: Colors.orange),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _showReceiptDetails(context, receipt),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionSummaryItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
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
}
