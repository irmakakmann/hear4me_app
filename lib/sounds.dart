// lib/sounds.dart
import 'package:flutter/material.dart';

class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});
  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  bool _useWatch = true;      // toggle watch mic / phone mic (UI only)
  bool _listening = false;    // UI flag only
  String _status = 'Idle';

  // Your existing profile toggles
  bool doorbellEnabled = true;
  bool smokeAlarmEnabled = true;
  bool phoneRingEnabled = true;
  bool carHornEnabled = true;

  void _startListening() {
    setState(() {
      _listening = true;
      _status = 'Listening… (UI only)';
    });
  }

  void _stopListening() {
    setState(() {
      _listening = false;
      _status = 'Idle';
    });
  }


  // -------------------- Your UI helpers (profiles & alerts) --------------------
  Widget _buildSoundProfileToggle({
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
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24.0)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.graphic_eq, size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(pattern, style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),
          Switch(
            value: isEnabled,
            onChanged: (v) => onToggle(v),
            activeColor: Colors.white,
            activeTrackColor: Colors.green,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({
    required String title,
    required String time,
    required String decibels,
    required String priority,
    required Color iconColor,
    required IconData icon,
  }) {
    final priorityColor = priority == 'High'
        ? Colors.orange
        : priority == 'Medium'
        ? Colors.blue
        : Colors.green;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8.0)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(time, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.volume_up, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(decibels, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16.0)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning, size: 14, color: priorityColor),
              const SizedBox(width: 4),
              Text(priority, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: priorityColor)),
            ]),
          ),
        ],
      ),
    );
  }

  // -------------------- BUILD --------------------
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Live Listening card =====
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.graphic_eq),
                  const SizedBox(width: 8),
                  const Text('Live Listening',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Switch(
                    value: _useWatch,
                    onChanged: _listening ? null : (v) => setState(() => _useWatch = v),
                  ),
                  const SizedBox(width: 4),
                  Text(_useWatch ? 'Watch mic' : 'Phone mic'),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  FilledButton.icon(
                    onPressed: !_listening ? _startListening : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _listening ? _stopListening : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Live classification results will appear here.',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Backend not connected – UI only.'),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 24),

          // ===== Sound Profiles =====
          const Text('Sound Profiles',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),

          _buildSoundProfileToggle(
            title: 'Doorbell',
            description: 'Front door bell',
            icon: Icons.door_front_door,
            iconColor: Colors.brown,
            pattern: 'Pattern 1',
            isEnabled: doorbellEnabled,
            onToggle: (v) => setState(() => doorbellEnabled = v),
          ),
          const SizedBox(height: 12),
          _buildSoundProfileToggle(
            title: 'Smoke Alarm',
            description: 'Fire/smoke alarm',
            icon: Icons.local_fire_department,
            iconColor: Colors.red,
            pattern: 'Pattern 3',
            isEnabled: smokeAlarmEnabled,
            onToggle: (v) => setState(() => smokeAlarmEnabled = v),
          ),
          const SizedBox(height: 12),
          _buildSoundProfileToggle(
            title: 'Phone Ring',
            description: 'Phone ringing',
            icon: Icons.phone,
            iconColor: Colors.black87,
            pattern: 'Pattern 2',
            isEnabled: phoneRingEnabled,
            onToggle: (v) => setState(() => phoneRingEnabled = v),
          ),
          const SizedBox(height: 12),
          _buildSoundProfileToggle(
            title: 'Car Horn',
            description: 'Vehicle horn outside',
            icon: Icons.directions_car,
            iconColor: Colors.red,
            pattern: 'Pattern 4',
            isEnabled: carHornEnabled,
            onToggle: (v) => setState(() => carHornEnabled = v),
          ),

          const SizedBox(height: 24),

          // ===== Recent Alerts =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Alerts',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              TextButton(onPressed: () {}, child: const Text('See All')),
            ],
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            title: 'Doorbell',
            time: 'Today, 2:15 PM',
            decibels: '82 dB',
            priority: 'High',
            iconColor: Colors.brown,
            icon: Icons.door_front_door,
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            title: 'Car Horn',
            time: 'Today, 5:15 PM',
            decibels: '86 dB',
            priority: 'High',
            iconColor: Colors.red,
            icon: Icons.directions_car,
          ),
        ],
      ),
    );
  }
}
