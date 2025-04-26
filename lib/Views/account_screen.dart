import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 50),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Settings Section
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to settings
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Sales History'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to sales history
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.support),
                  title: const Text('Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to support
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Logout Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Navigate to login screen
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
