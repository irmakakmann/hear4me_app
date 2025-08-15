import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  //Constants for consistent theming
  static const double _borderRadius = 16.0;
  static const double _cardPadding = 20.0;
  static const double _iconSize = 40.0;
  static const double _spacing = 16.0;
  static const double _cardMargin = 20.0;

  //Text styles
  static const TextStyle _titleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle _itemTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static const TextStyle _itemSubtitleStyle = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  //Animation controller for the scanning spinner
  late AnimationController _animationController;
  bool isScanning = true;
  bool deviceFound = false;

  //Sound Detection settings
  double alertThreshold = 85.0;
  bool aiProcessingEnabled = true;

  //Vibration & Alerts settings
  double vibrationStrength = 0.6;
  bool doNotDisturbEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _simulateDeviceDiscovery();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  void _simulateDeviceDiscovery() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          isScanning = false;
          deviceFound = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _testVibrationPattern() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing vibration pattern...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  //Helper to Build Consistent Card Container
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_cardPadding),
      margin: const EdgeInsets.only(bottom: _cardMargin),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  //Helper to Build Consistent Icon Container
  Widget _buildIconContainer({
    required IconData icon,
    required Color color,
    double size = _iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  //Helper to Build Settings Item Row
  Widget _buildSettingsItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: _spacing),
        child: Row(
          children: [
            _buildIconContainer(icon: icon, color: iconColor),
            const SizedBox(width: _spacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _itemTitleStyle),
                  const SizedBox(height: 4),
                  Text(subtitle, style: _itemSubtitleStyle),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  //Helper to Build Scanning Card
  Widget _buildScanningCard() {
    return _buildCard(
      child: Row(
        children: [
          RotationTransition(
            turns: _animationController,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: Colors.blue, width: 3),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
              'Scanning for hearing aid watches...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //Helper to Build Device Found Card
  Widget _buildDeviceFoundCard() {
    return _buildCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(32.0),
            ),
            child: const Icon(Icons.watch, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hearing Aid Watch',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.signal_cellular_alt, size: 16, color: Colors.blue),
                    SizedBox(width: 6),
                    Text(
                      'Available to pair',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //Helper to Build Instructions Card
  Widget _buildInstructionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_spacing),
      margin: const EdgeInsets.only(bottom: _cardMargin),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Container(
            width: _iconSize,
            height: _iconSize,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Icon(
              Icons.signal_cellular_alt,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: _spacing),
          Expanded(
            child: Text(
              'Make sure your watch is in pairing mode',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //Build Sound Detection Section
  Widget _buildSoundDetectionSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sound Detection', style: _titleStyle),
          const SizedBox(height: 20),

          //Alert Threshold
          _buildSettingsItem(
            icon: Icons.warning,
            iconColor: Colors.orange,
            title: 'Alert Threshold',
            subtitle: '${alertThreshold.round()} dB - Trigger alerts above this level',
            trailing: Text(
              '${alertThreshold.round()}dB',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          //AI Processing
          _buildSettingsItem(
            icon: Icons.psychology,
            iconColor: Colors.pink,
            title: 'AI Processing',
            subtitle: 'Advanced sound recognition on phone',
            trailing: Switch(
              value: aiProcessingEnabled,
              onChanged: (value) {
                setState(() {
                  aiProcessingEnabled = value;
                });
              },
              activeColor: Colors.white,
              activeTrackColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  //Build Vibration & Alerts Section
  Widget _buildVibrationAlertsSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vibration & Alerts', style: _titleStyle),
          const SizedBox(height: 20),

          //Vibration Strength
          Container(
            margin: const EdgeInsets.only(bottom: _spacing),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildIconContainer(icon: Icons.vibration, color: Colors.orange),
                    const SizedBox(width: _spacing),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vibration Strength', style: _itemTitleStyle),
                          Text('Adjust haptic feedback intensity', style: _itemSubtitleStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: vibrationStrength,
                  onChanged: (value) {
                    setState(() {
                      vibrationStrength = value;
                    });
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),

          //Pattern Preview
          _buildSettingsItem(
            icon: Icons.music_note,
            iconColor: Colors.blue,
            title: 'Pattern Preview',
            subtitle: 'Test vibration patterns',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) => Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )),
            ),
            onTap: _testVibrationPattern,
          ),

          //Do Not Disturb
          _buildSettingsItem(
            icon: Icons.nightlight_round,
            iconColor: Colors.orange,
            title: 'Do Not Disturb',
            subtitle: '11:00 PM - 7:00 AM',
            trailing: Switch(
              value: doNotDisturbEnabled,
              onChanged: (value) {
                setState(() {
                  doNotDisturbEnabled = value;
                });
              },
              activeColor: Colors.white,
              activeTrackColor: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          //Blue header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(color: Colors.blue),
            alignment: Alignment.center,
            child: const Text('Connect Watch', style: _headerStyle),
          ),

          //Content section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(_spacing),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  _buildInstructionsCard(),

                  if (isScanning) _buildScanningCard(),
                  if (deviceFound) _buildDeviceFoundCard(),

                  const SizedBox(height: 24),

                  _buildSoundDetectionSection(),
                  _buildVibrationAlertsSection(),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}