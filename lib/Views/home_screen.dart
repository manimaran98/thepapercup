import 'package:flutter/material.dart';
import 'package:thepapercup/Views/Sales/sales.dart';
import 'package:thepapercup/Views/Sales/inventory.dart';
import 'package:thepapercup/Views/account_screen.dart';

class HomeScreen extends StatefulWidget {
  final int selectedIndex;
  const HomeScreen({super.key, required this.selectedIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _screens = [
      const SalesScreen(userId: ''), // We'll update this with actual user ID
      const InventoryScreen(),
      const AccountScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
