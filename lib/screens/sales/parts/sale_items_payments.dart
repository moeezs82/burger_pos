import 'package:flutter/material.dart';

class ScannerToggleButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onActivate;

  const ScannerToggleButton({
    super.key,
    required this.enabled,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: onActivate,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Colors.green : null,
        ),
        icon: Icon(enabled ? Icons.check_circle : Icons.qr_code_scanner),
        label: Text(enabled ? "Scanning Active" : "Start Scanning"),
      ),
    );
  }
}

class PaymentsCard extends StatelessWidget {
  final bool autoCashIfEmpty;
  final ValueChanged<bool> onToggleAutoCash;

  const PaymentsCard({
    super.key,
    required this.autoCashIfEmpty,
    required this.onToggleAutoCash,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text("Payments",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Auto-cash"),
              subtitle: const Text(
                "When ON, sends full invoice total as CASH.",
              ),
              value: autoCashIfEmpty,
              onChanged: onToggleAutoCash,
            ),
          ],
        ),
      ),
    );
  }
}
