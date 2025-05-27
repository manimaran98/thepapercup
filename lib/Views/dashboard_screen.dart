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
  final ReceiptService _receiptService = ReceiptService();

  // Analytics Data
  Map<String, double> salesData = {};
  Map<String, double> categoryData = {};
  Map<String, double> paymentData = {};
  Map<String, double> profitData = {};
  Map<String, dynamic> inventoryData =
      {}; // Inventory data, will now include categoryId

  // Quantity Data
  Map<String, int> categoryQuantityData = {};
  Map<String, int> paymentQuantityData = {};

  // Aggregated Item Data for Best Sellers Screen and detailed dashboard views
  Map<String, Map<String, dynamic>> aggregatedItemData = {};

  // Categories data
  Map<String, String> categoriesMap = {}; // Map categoryId to categoryName

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
      case 'All Time':
        // Return a very old date to include all records
        return DateTime(2020, 1, 1);
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
      case 'All Time':
        // Return current date and time for all time
        return DateTime.now();
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

      // Fetch receipts for the date range. Add 1 day to endDate to include the entire end day.
      final receipts = await _receiptService
          .getReceiptsByDateRange(
              startDate, endDate.add(const Duration(days: 1)))
          .first;

      // Load inventory data first to get category IDs
      await _loadInventoryData();

      // Load categories from the categories collection
      await _loadCategoriesMap();

      // Aggregate item data from receipts for Best Sellers Screen and detailed views
      aggregatedItemData = _aggregateItems(receipts);

      // Populate other dashboard data based on fetched receipts
      salesData.clear();
      categoryData.clear();
      paymentData.clear();
      categoryQuantityData.clear();
      paymentQuantityData.clear();
      profitData = {'revenue': 0.0, 'cost': 0.0, 'profit': 0.0, 'margin': 0.0};

      double totalRevenue = 0.0;

      for (var receipt in receipts) {
        totalRevenue += receipt.total;

        final paymentMethod = receipt.paymentMethod ?? 'Unknown';
        paymentData[paymentMethod] =
            (paymentData[paymentMethod] ?? 0.0) + receipt.total;
        paymentQuantityData[paymentMethod] =
            (paymentQuantityData[paymentMethod] ?? 0) +
                receipt.items
                    .fold(0, (sum, item) => sum + (item['quantity'] as int));

        for (var item in receipt.items) {
          final itemName = item['name'] as String;
          // Use the categoryId from inventoryData and categoriesMap to get the category name
          final categoryId = inventoryData[itemName]?['categoryId'] ?? '';
          final categoryName = categoriesMap[categoryId] ?? 'Uncategorized';

          final itemTotal = item['total'] as double;
          final itemQuantity = item['quantity'] as int;

          salesData[itemName] = (salesData[itemName] ?? 0.0) + itemTotal;

          categoryData[categoryName] =
              (categoryData[categoryName] ?? 0.0) + itemTotal;
          categoryQuantityData[categoryName] =
              (categoryQuantityData[categoryName] ?? 0) + itemQuantity;
        }
      }

      profitData['revenue'] = totalRevenue;

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
        final itemName = data['name'] as String;
        final categoryId = data['Category'] ?? '';
        // Use the categoriesMap to get the category name
        final categoryName = categoriesMap[categoryId] ?? 'Uncategorized';

        inventory[itemName] = {
          'quantity': data['quantity'] ?? 0,
          'categoryId': categoryId, // Store category ID
          'categoryName': categoryName, // Store category NAME
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

  Future<void> _loadCategoriesMap() async {
    try {
      final QuerySnapshot categoriesSnapshot =
          await FirebaseFirestore.instance.collection('categories').get();
      Map<String, String> loadedCategoriesMap = {};
      for (var doc in categoriesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedCategoriesMap[doc.id] =
            data['name'] as String; // Map category ID to name
      }
      setState(() {
        categoriesMap = loadedCategoriesMap;
      });
    } catch (e) {
      print('Error loading categories map: $e');
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
                    ButtonSegment(value: 'All Time', label: Text('All Time')),
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Sales',
                      'RM${profitData['revenue']?.toStringAsFixed(2) ?? '0.00'}',
                      Icons.attach_money,
                      const Color.fromRGBO(122, 81, 204, 1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Items Sold',
                      '${paymentQuantityData.values.fold<int>(0, (sum, quantity) => sum + quantity)}',
                      Icons.shopping_bag,
                      const Color.fromRGBO(122, 81, 204, 1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Orders',
                      '${salesData.length}',
                      Icons.receipt_long,
                      const Color.fromRGBO(122, 81, 204, 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BestSellersScreen(
                            items: aggregatedItemData,
                            startDate: _getStartDate(),
                            endDate: _getEndDate(),
                          ),
                        ),
                      );
                    },
                    child: _buildSummaryCard(
                      'Best Seller',
                      salesData.isNotEmpty
                          ? salesData.entries
                              .reduce((a, b) => a.value > b.value ? a : b)
                              .key
                          : 'No Data',
                      Icons.star,
                      const Color.fromRGBO(122, 81, 204, 1),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Profit Margin',
                    '${profitData['margin']?.toStringAsFixed(1) ?? '0.0'}%',
                    Icons.trending_up,
                    const Color.fromRGBO(122, 81, 204, 1),
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
                    aspectRatio: 1.6,
                    child: _buildChartCard(
                      'Top Selling Items',
                      _buildItemsChart(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.6,
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

    // Sort low stock items alphabetically by name for consistent display
    lowStockItems.sort((a, b) => a.key.compareTo(b.key));

    return lowStockItems.map((entry) {
      return Card(
        child: ListTile(
          title: Text(entry.key),
          // Use the stored categoryName for display
          subtitle: Text('Category: ${entry.value['categoryName']}'),
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
        return const Color.fromRGBO(122, 81, 204, 1);
      case 'card':
        return const Color.fromRGBO(122, 81, 204, 1);
      case 'qr':
        return const Color.fromRGBO(122, 81, 204, 1);
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

  Widget _buildItemsChart() {
    if (salesData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Sort items by sales amount/quantity and take top 5
    final sortedItems = salesData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(5).toList();

    // Get the maximum value for the Y axis
    final maxValue = showByAmount
        ? topItems.map((e) => e.value).reduce((a, b) => a > b ? a : b)
        : topItems.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = topItems[groupIndex].key;
              final value = showByAmount
                  ? 'RM${topItems[groupIndex].value.toStringAsFixed(2)}'
                  : '${topItems[groupIndex].value.toInt()} units';
              return BarTooltipItem(
                '$item\n$value',
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
                if (value >= 0 && value < topItems.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      topItems[value.toInt()].key,
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
        barGroups: topItems.asMap().entries.map((entry) {
          // For quantity view, we need to get the actual quantity from the sales data
          final value = showByAmount
              ? entry.value.value
              : entry.value.value.toInt().toDouble();
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: value,
                color: const Color.fromRGBO(122, 81, 204, 1),
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
                color: const Color.fromRGBO(122, 81, 204, 1),
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

  Map<String, Map<String, dynamic>> _aggregateItems(
      List<ReceiptModel> receipts) {
    Map<String, Map<String, dynamic>> items = {};

    for (var receipt in receipts) {
      for (var item in receipt.items) {
        final itemName = item['name'] as String;
        final quantity = item['quantity'] as int;
        final total = item['total'] as double;

        // Use the categoryId from inventoryData and categoriesMap to get the category name
        final categoryId = inventoryData[itemName]?['categoryId'] ?? '';
        final categoryName = categoriesMap[categoryId] ?? 'Uncategorized';

        if (items.containsKey(itemName)) {
          items[itemName]!['quantity'] += quantity;
          items[itemName]!['total'] += total;
        } else {
          items[itemName] = {
            'quantity': quantity,
            'total': total,
            'category': categoryName, // Store the category NAME here
          };
        }
      }
    }

    return items;
  }
}

class BestSellersScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> items;
  final DateTime startDate;
  final DateTime endDate;

  const BestSellersScreen({
    super.key,
    required this.items,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<BestSellersScreen> createState() => _BestSellersScreenState();
}

class _BestSellersScreenState extends State<BestSellersScreen> {
  String? selectedCategory;
  bool showByAmount = true;

  @override
  Widget build(BuildContext context) {
    // Get unique categories from items using categoryName
    final categories = widget.items.values
        .map((itemData) => itemData['category']
            as String) // Use 'category' (which now holds the name)
        .toSet()
        .toList();
    categories.insert(0, 'All');

    // Filter items by category NAME
    final filteredItems = selectedCategory == 'All' || selectedCategory == null
        ? widget.items
        : Map.fromEntries(
            widget.items.entries.where(
              (entry) =>
                  entry.value['category'] ==
                  selectedCategory, // Filter by 'category' (name)
            ),
          );

    // Sort items by amount or quantity
    final sortedItems = filteredItems.entries.toList()
      ..sort((a, b) {
        // Access 'total' and 'quantity' from the nested map
        final valueA = showByAmount
            ? a.value['total'] as double
            : a.value['quantity'] as int;
        final valueB = showByAmount
            ? b.value['total'] as double
            : b.value['quantity'] as int;
        return valueB.compareTo(valueA);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Sellers'),
        actions: [
          IconButton(
            icon: Icon(
                showByAmount ? Icons.attach_money : Icons.format_list_numbered),
            onPressed: () {
              setState(() {
                showByAmount = !showByAmount;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('dd/MM/yyyy').format(widget.startDate)} - ${DateFormat('dd/MM/yyyy').format(widget.endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  showByAmount ? 'By Amount' : 'By Quantity',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Category Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                // Use the generated categories list which includes 'All' and unique category names
                children: categories.map((category) {
                  final isSelected = category == selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label:
                          Text(category), // Use the category name for the label
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          selectedCategory = selected ? category : null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Items',
                    sortedItems.length.toString(),
                    Icons.inventory_2,
                    const Color.fromRGBO(122, 81, 204, 1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    'RM${sortedItems.fold(0.0, (sum, item) => sum + (item.value['total'] as double)).toStringAsFixed(2)}',
                    Icons.attach_money,
                    const Color.fromRGBO(122, 81, 204, 1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Quantity',
                    sortedItems
                        .fold(
                            0,
                            (sum, item) =>
                                sum + (item.value['quantity'] as int))
                        .toString(),
                    Icons.format_list_numbered,
                    const Color.fromRGBO(122, 81, 204, 1),
                  ),
                ),
              ],
            ),
          ),
          // Items List
          Expanded(
            child: ListView.builder(
              itemCount: sortedItems.length,
              itemBuilder: (context, index) {
                final item = sortedItems[index];
                final rank = index + 1;
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: rank <= 3
                          ? [
                              Colors.amber,
                              Colors.grey[400],
                              Colors.amber[700]
                            ][rank - 1]
                          : Colors.grey[300],
                      child: Text(
                        rank.toString(),
                        style: TextStyle(
                          color: rank <= 3 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      item.key, // item.key is the item name/ID
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(item.value['category']
                        as String), // Display category NAME here
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          showByAmount
                              ? 'RM${(item.value['total'] as double).toStringAsFixed(2)}'
                              : '${item.value['quantity']} units', // Display quantity here
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          showByAmount
                              ? '${item.value['quantity']} units' // Display quantity here
                              : 'RM${(item.value['total'] as double).toStringAsFixed(2)}', // Display total here
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
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
        ),
      ),
    );
  }
}

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTime? startDate;
  DateTime? endDate;
  final ReceiptService _receiptService = ReceiptService();

  @override
  void initState() {
    super.initState();
    // Set default date range to today
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day);
    endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _showReportDialog() async {
    final reportType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Daily Report'),
              subtitle: const Text('All transactions for a specific day'),
              onTap: () => Navigator.pop(context, 'Daily Report'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Monthly Report'),
              subtitle: const Text('Daily totals for a specific month'),
              onTap: () => Navigator.pop(context, 'Monthly Report'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Yearly Report'),
              subtitle: const Text('Monthly totals for a specific year'),
              onTap: () => Navigator.pop(context, 'Yearly Report'),
            ),
          ],
        ),
      ),
    );

    if (reportType == null) return;

    DateTime? selectedDate;
    if (reportType == 'Daily Report') {
      selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
    } else if (reportType == 'Monthly Report') {
      // Show month picker
      final now = DateTime.now();
      final year = now.year;
      final month = now.month;

      final selectedMonth = await showDialog<DateTime>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Month'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height *
                0.4, // 40% of screen height
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(12, (index) {
                  final monthDate = DateTime(year, index + 1);
                  return ListTile(
                    title: Text(DateFormat('MMMM yyyy').format(monthDate)),
                    selected: index + 1 == month,
                    onTap: () => Navigator.pop(context, monthDate),
                  );
                }),
              ),
            ),
          ),
        ),
      );
      selectedDate = selectedMonth;
    } else if (reportType == 'Yearly Report') {
      // Show year picker
      final now = DateTime.now();
      final currentYear = now.year;

      final selectedYear = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(currentYear - 2019, (index) {
              final year = currentYear - index;
              return ListTile(
                title: Text(year.toString()),
                selected: year == currentYear,
                onTap: () => Navigator.pop(context, year),
              );
            }),
          ),
        ),
      );
      if (selectedYear != null) {
        selectedDate = DateTime(selectedYear);
      }
    }

    if (selectedDate == null) return;

    try {
      Map<String, dynamic> report;
      if (reportType == 'Daily Report') {
        report = await _receiptService.generateDailyReport(selectedDate);
      } else if (reportType == 'Monthly Report') {
        report = await _receiptService.generateMonthlyReport(selectedDate);
      } else {
        report = await _receiptService.generateYearlyReport(selectedDate);
      }

      if (!mounted) return;
      await _receiptService.shareReport(report, reportType);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Color.fromRGBO(122, 81, 204, 1);
      case 'card':
        return const Color.fromRGBO(122, 81, 204, 1);
      case 'qr':
        return const Color.fromRGBO(122, 81, 204, 1);
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

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  Stream<List<ReceiptModel>> _getFilteredReceipts() {
    if (startDate != null && endDate != null) {
      // Add one day to endDate to include the entire end date
      final endDatePlusOne = endDate!.add(const Duration(days: 1));
      return _receiptService.getReceiptsByDateRange(startDate!, endDatePlusOne);
    }
    return _receiptService.getReceipts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _selectDateRange(context),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _showReportDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Filter Display
          if (startDate != null && endDate != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        startDate = null;
                        endDate = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
          // Transaction List
          Expanded(
            child: StreamBuilder<List<ReceiptModel>>(
              stream: _getFilteredReceipts(),
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
                            const Color.fromRGBO(122, 81, 204, 1),
                          ),
                          _buildTransactionSummaryItem(
                            'Total Orders',
                            receipts.length.toString(),
                            Icons.shopping_cart,
                            const Color.fromRGBO(122, 81, 204, 1),
                          ),
                          _buildTransactionSummaryItem(
                            'Average Order',
                            'RM${(receipts.fold(0.0, (sum, receipt) => sum + receipt.total) / receipts.length).toStringAsFixed(2)}',
                            Icons.analytics,
                            const Color.fromRGBO(122, 81, 204, 1),
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
                                backgroundColor: _getPaymentMethodColor(
                                    receipt.paymentMethod),
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
                              onTap: () =>
                                  _showReceiptDetails(context, receipt),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
