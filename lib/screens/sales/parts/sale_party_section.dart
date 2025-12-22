import 'package:flutter/material.dart';

class PartySectionCard extends StatelessWidget {
  final Map<String, dynamic>? selectedCustomer;

  final VoidCallback onPickCustomer;

  const PartySectionCard({
    super.key,
    required this.selectedCustomer,
    required this.onPickCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SelectField(
              label: "Customer",
              valueText: selectedCustomer?['first_name'] ?? "Select Customer",
              onTap: onPickCustomer,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Uniform input-like clickable field with optional clear icon.
class SelectField extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onTap;
  final bool showClear;
  final VoidCallback? onClear;

  const SelectField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.showClear = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ).copyWith(labelText: label),
        child: Row(
          children: [
            Expanded(child: Text(valueText, overflow: TextOverflow.ellipsis)),
            if (showClear)
              IconButton(
                tooltip: "Clear",
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
