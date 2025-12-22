import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

/// Totals card with inline editable Discount/Tax + Cash Received + Change.
class TotalsCardInline extends StatelessWidget {
  final String subtotal;

  final TextEditingController discountController;
  final TextEditingController taxController;
  final TextEditingController deliveryController;

  /// Total amount (as string) shown in UI (e.g. "950")
  final String total;

  /// NEW: user enters cash received here (e.g. "1000")
  final TextEditingController cashReceivedController;

  const TotalsCardInline({
    super.key,
    required this.subtotal,
    required this.discountController,
    required this.taxController,
    required this.deliveryController,
    required this.total,
    required this.cashReceivedController,
  });

  double _toDouble(String s) {
    final cleaned = s.trim().replaceAll(',', '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  String _money(num v) {
    // keep it simple; if you want 2 decimals always, change formatting here
    final d = v.toDouble();
    if (d % 1 == 0) return d.toStringAsFixed(0);
    return d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final totalAmount = _toDouble(total);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            // subtle tip line
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: t.hintColor),
                  const SizedBox(width: 6),
                  Text(
                    "Tip: tap values to edit",
                    style: t.textTheme.labelSmall?.copyWith(color: t.hintColor),
                  ),
                ],
              ),
            ),

            _rowStatic("Subtotal", "\$$subtotal"),

            // Editable Discount
            _rowEditable(
              context,
              label: "Discount",
              controller: discountController,
              prefix: "-\$",
              textColor: Colors.red,
            ),

            // Editable Tax
            _rowEditable(
              context,
              label: "Tax",
              controller: taxController,
              prefix: "\$",
              textColor: Colors.orange,
            ),
            // Editable Tax
            _rowEditable(
              context,
              label: "Delivery",
              controller: deliveryController,
              prefix: "\$",
              textColor: Colors.orange,
            ),

            const Divider(height: 8),

            // TOTAL
            ListTile(
              dense: false,
              title: const Text("Total", style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                "\$${_money(totalAmount)}",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
            ),

            // Cash received (user input)
            _rowEditable(
              context,
              label: "Cash Received",
              controller: cashReceivedController,
              prefix: "\$",
              textColor: t.colorScheme.primary,
              hintWhenZero: "enter cash",
            ),

            // Paid / Balance / Change (auto)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: cashReceivedController,
              builder: (context, _, __) {
                final cash = _toDouble(cashReceivedController.text);

                final paid = math.min(cash, totalAmount);
                final balance = math.max(0.0, totalAmount - cash);
                final change = math.max(0.0, cash - totalAmount);

                final balanceColor = balance > 0 ? Colors.red : Colors.green;

                return Column(
                  children: [
                    _rowStatic("Paid", "\$${_money(paid)}"),
                    ListTile(
                      dense: true,
                      title: const Text("Balance"),
                      trailing: Text(
                        "\$${_money(balance)}",
                        style: TextStyle(fontWeight: FontWeight.w800, color: balanceColor),
                      ),
                    ),
                    _rowStatic("Change / Return", "\$${_money(change)}"),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowStatic(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _rowEditable(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String prefix = "\$",
    Color? textColor,
    String? hintWhenZero,
  }) {
    final t = Theme.of(context);

    bool _isZeroOrEmpty(String s) {
      final v = double.tryParse(s.trim().replaceAll(',', ''));
      return s.trim().isEmpty || v == null || v == 0;
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final showHint = _isZeroOrEmpty(value.text);

        return ListTile(
          dense: true,
          title: Row(
            children: [
              Text(label),
              const SizedBox(width: 6),
              Icon(Icons.edit_outlined, size: 14, color: t.hintColor),
            ],
          ),
          trailing: SizedBox(
            width: 170,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
              decoration: InputDecoration(
                isDense: true,
                prefixText: prefix,
                hintText: showHint ? (hintWhenZero ?? "tap to add") : null,
                hintStyle: t.textTheme.titleSmall?.copyWith(color: t.hintColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                suffixIcon: Icon(Icons.edit_outlined, size: 16, color: t.hintColor),
                suffixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      },
    );
  }
}
