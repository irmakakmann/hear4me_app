import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // sample data
    final items = <AlertItem>[
      AlertItem(
        name: 'Doorbell',
        when: 'Today, 2:15 PM',
        db: 82,
        icon: Icons.doorbell_outlined,
        severity: Severity.high,
      ),
      AlertItem(
        name: 'Phone Ring',
        when: 'Today, 1:42 PM',
        db: 75,
        icon: Icons.call_outlined,
        severity: Severity.medium,
      ),
      AlertItem(
        name: 'Smoke Alarm',
        when: 'Yesterday, 11:23 AM',
        db: 95,
        icon: Icons.local_fire_department_outlined,
        severity: Severity.critical,
      ),
      AlertItem(
        name: 'Car Horn',
        when: 'Yesterday, 9:15 AM',
        db: 70,
        icon: Icons.directions_car_filled_outlined,
        severity: Severity.normal,
      ),
    ];

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: items.length,
        itemBuilder: (_, i) => AlertCard(item: items[i]),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final AlertItem item;
  const AlertCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
    final subtitleStyle = const TextStyle(fontSize: 14, color: Colors.black54);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // left icon in light grey circle
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.black12.withOpacity(0.06),
              child: Icon(item.icon, size: 26, color: Colors.black45),
            ),
            const SizedBox(width: 14),

            // center: title + time + bottom row
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: titleStyle),
                  const SizedBox(height: 2),
                  Text(item.when, style: subtitleStyle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.hearing, size: 16, color: Colors.black45),
                      const SizedBox(width: 6),
                      Text('${item.db} dB', style: subtitleStyle),
                    ],
                  ),
                ],
              ),
            ),

            // right: severity chip
            SeverityChip(severity: item.severity),
          ],
        ),
      ),
    );
  }
}

class SeverityChip extends StatelessWidget {
  final Severity severity;
  const SeverityChip({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final data = severity.data;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: data.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 16, color: data.fg),
          const SizedBox(width: 6),
          Text(data.label, style: TextStyle(fontSize: 13, color: data.fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// MODEL + SEVERITY COLORS

class AlertItem {
  final String name;
  final String when;
  final int db;
  final IconData icon;
  final Severity severity;

  AlertItem({
    required this.name,
    required this.when,
    required this.db,
    required this.icon,
    required this.severity,
  });
}

enum Severity { normal, medium, high, critical }

extension _SeverityStyles on Severity {
  _ChipData get data {
    switch (this) {
      case Severity.normal:
        return _ChipData(
          'Normal',
          Icons.info_outline,
          const Color(0xFF2E7D32),      // green
          const Color(0xFFE8F5E9),
        );
      case Severity.medium:
        return _ChipData(
          'Medium',
          Icons.warning_amber_rounded,
          const Color(0xFF1976D2),      // blue
          const Color(0xFFE3F2FD),
        );
      case Severity.high:
        return _ChipData(
          'High',
          Icons.warning_rounded,
          const Color(0xFFF57C00),      // orange
          const Color(0xFFFFF3E0),
        );
      case Severity.critical:
        return _ChipData(
          'Critical',
          Icons.stop_circle_outlined,
          const Color(0xFFD32F2F),      // red
          const Color(0xFFFFEBEE),
        );
    }
  }
}

class _ChipData {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  const _ChipData(this.label, this.icon, this.fg, this.bg);
}
