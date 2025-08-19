import 'package:flutter/material.dart';
import 'sounds.dart';
import 'settings.dart';
import 'history.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hear4Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Hear4Me Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  // --- Bottom Navigation Bar Tap Handler ---
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- Helper to Build Home Screen Content ---
  Widget _buildHomeContent(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            WatchStatusCard(isConnected: true, batteryPercent: 75),
            SizedBox(height: 16),
            SoundLevelCard(currentDb: 62, thresholdDb: 85),
            SizedBox(height: 18),
            _SectionTitle('Quick Actions'),
            SizedBox(height: 8),
            _QuickActionsRow(),
          ],
        ),
      ),
    );
  }

  // --- List of Widgets for each Tab ---
  List<Widget> _getWidgetOptions(BuildContext context) {
    return <Widget>[
      _buildHomeContent(context),
      SoundsScreen(),
      HistoryScreen(),
      const Center(child: Text('Profile Screen Content', style: TextStyle(fontSize: 24))),
      const SettingsScreen(),
    ];
  }

  // --- List of AppBar Titles for each Tab ---
  static const List<String> _appBarTitles = <String>[
    'Hear4Me',
    'Sounds',
    'History',
    'Profile',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = _getWidgetOptions(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Sounds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}

/// --- Widgets for the Home Screen ---

class WatchStatusCard extends StatelessWidget {
  final bool isConnected;
  final int batteryPercent;
  const WatchStatusCard({super.key, required this.isConnected, required this.batteryPercent});

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF2E7D32);      // dark green text
    final bgGreen = const Color(0xFFE8F5E9);    // light green background
    final borderGreen = const Color(0xFF66BB6A); // border color

    return Container(
      decoration: BoxDecoration(
        color: bgGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGreen, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Icon(Icons.signal_cellular_alt, color: green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Watch Connected' : 'Disconnected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: green,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Hearing Aid Watch',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54, // grey
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.battery_full, color: green),
          const SizedBox(width: 4),
          Text(
            '$batteryPercent%',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: green,
            ),
          ),
        ],
      ),
    );
  }
}

class SoundLevelCard extends StatelessWidget {
  final int currentDb;
  final int thresholdDb;
  const SoundLevelCard({super.key, required this.currentDb, required this.thresholdDb});

  @override
  Widget build(BuildContext context) {
    final over = currentDb >= thresholdDb;
    final valColor = over ? Colors.red.shade700 : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      width: double.infinity,
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Current Sound Level',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 30),
          Text(
            '$currentDb',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: valColor,
            ),
          ),
          const Text('dB', style: TextStyle(fontSize: 24, color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(over ? Icons.warning_amber : Icons.notifications_none,
                  size: 18, color: over ? Colors.red : Colors.black45),
              const SizedBox(width: 6),
              Text(
                'Alert threshold: $thresholdDb dB',
                style: TextStyle(
                  fontSize: 20,
                  color: over ? Colors.red : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.do_not_disturb_on,
            iconColor: Colors.red,
            label: 'Do Not Disturb',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.music_note,
            iconColor: Colors.black87,
            label: 'Sound Profiles',
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _QuickActionCard({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label tapped'))),
        child: SizedBox(
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: iconColor),
              const SizedBox(height: 10),
              Text(label, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
  }
}
