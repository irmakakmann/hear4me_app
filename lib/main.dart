import 'package:flutter/material.dart';
import 'sounds.dart';
import 'setup.dart';

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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
    );
  }

  // --- List of Widgets for each Tab ---
  // This list will be initialized in the build method or initState
  // to ensure context is available for _buildHomeContent if needed,
  // or to pass necessary parameters.
  // For simplicity, we'll define them here, understanding _buildHomeContent
  // will be called with the current context during the build.
  List<Widget> _getWidgetOptions(BuildContext context) {
    return <Widget>[
      _buildHomeContent(context),
      SoundsScreen(),
      const Center(child: Text('History Screen Content', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Profile Screen Content', style: TextStyle(fontSize: 24))),
      const SetupScreen(),
    ];
  }

  // --- List of AppBar Titles for each Tab ---
  static const List<String> _appBarTitles = <String>[
    'Hear4Me',      // Title for Home (index 0)
    'Sounds',       // Title for Sounds (index 1)
    'History',      // Title for History (index 2)
    'Profile',      // Title for Profile (index 3)
    'setup',     // Title for Settings (index 4)
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = _getWidgetOptions(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]), // Set title based on selected index
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: widgetOptions.elementAt(_selectedIndex),
      ),
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
            label: 'Setup',
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
