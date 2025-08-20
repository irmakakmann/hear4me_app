import 'package:flutter/material.dart';

class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  //Toggle states for each sound profile
  bool doorbellEnabled = true;
  bool smokeAlarmEnabled = true;
  bool phoneRingEnabled = true;
  bool carHornEnabled = true;



  //Helper to Build Sound Profile Toggle
  Widget buildSoundProfileToggle({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String pattern,
    required bool isEnabled,
    required Function(bool) onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          //Icon in circular background
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          //Sound details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.graphic_eq,
                            size: 12,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pattern,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          //Toggle switch
          Switch(
            value: isEnabled,
            onChanged: onToggle,
            activeColor: Colors.white,
            activeTrackColor: Colors.green,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
  Widget buildAlertItem({
    required String title,
    required String time,
    required String decibels,
    required String priority,
    required Color iconColor,
    required IconData icon,
  }) {
    Color priorityColor = priority == 'High'
        ? Colors.orange
        : priority == 'Medium'
        ? Colors.blue
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          //Alert Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          //Alert Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.volume_up,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      decibels,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          //Priority Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning,
                  size: 14,
                  color: priorityColor,
                ),
                const SizedBox(width: 4),
                Text(
                  priority,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: priorityColor,
                  ),
                ),
              ],
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Description text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                'Choose which sounds you want the watch to alert you on.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            const SizedBox(height: 20),

            //Sound Profiles Section
            buildSoundProfileToggle(
              title: 'Doorbell',
              description: 'Front door bell',
              icon: Icons.door_front_door,
              iconColor: Colors.brown,
              pattern: 'Pattern 1',
              isEnabled: doorbellEnabled,
              onToggle: (value) {
                setState(() {
                  doorbellEnabled = value;
                });
              },
            ),

            const SizedBox(height: 12),

            buildSoundProfileToggle(
              title: 'Smoke Alarm',
              description: 'Fire/smoke alarm',
              icon: Icons.local_fire_department,
              iconColor: Colors.red,
              pattern: 'Pattern 3',
              isEnabled: smokeAlarmEnabled,
              onToggle: (value) {
                setState(() {
                  smokeAlarmEnabled = value;
                });
              },
            ),

            const SizedBox(height: 12),

            buildSoundProfileToggle(
              title: 'Phone Ring',
              description: 'Phone ringing',
              icon: Icons.phone,
              iconColor: Colors.black87,
              pattern: 'Pattern 2',
              isEnabled: phoneRingEnabled,
              onToggle: (value) {
                setState(() {
                  phoneRingEnabled = value;
                });
              },
            ),

            const SizedBox(height: 12),

            buildSoundProfileToggle(
              title: 'Car Horn',
              description: 'Vehicle horn outside',
              icon: Icons.directions_car,
              iconColor: Colors.red,
              pattern: 'Pattern 4',
              isEnabled: carHornEnabled,
              onToggle: (value) {
                setState(() {
                  carHornEnabled = value;
                });
              },
            ),

            const SizedBox(height: 32),

            //Recent Alerts Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Alerts',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    //Navigate to full alert history
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            //Recent Alerts List
            buildAlertItem(
              title: 'Doorbell',
              time: 'Today, 2:15 PM',
              decibels: '82 dB',
              priority: 'High',
              iconColor: Colors.brown,
              icon: Icons.door_front_door,
            ),
            const SizedBox(height: 16),

            buildAlertItem(
              title: 'Car Horn',
              time: 'Today, 5:15 PM',
              decibels: '86 dB',
              priority: 'High',
              iconColor: Colors.red,
              icon: Icons.directions_car,
            ),
          ],
        ),
      ),
    );
  }
}