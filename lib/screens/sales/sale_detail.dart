import 'package:counter_iq/api/core/api_client.dart';
import 'package:counter_iq/providers/auth_provider.dart';
import 'package:counter_iq/widgets/product_picker_sheet.dart';
import 'package:counter_iq/widgets/user_picker_sheet.dart';
import 'package:counter_iq/widgets/vendor_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:counter_iq/services/thermal_printer_service.dart';
import 'package:counter_iq/services/receipt_preview_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

// parts
import 'package:counter_iq/screens/sales/parts/sale_items_section.dart';
import 'package:counter_iq/screens/sales/parts/sale_totals_editable.dart';

class SaleDetailScreen extends StatefulWidget {
  final int saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Map<String, dynamic>? _sale;
  bool _loading = true;
  bool _updated = false;

  Map<String, dynamic>? _selectedDeliveryBoy;
  int? _selectedDeliveryBoyId;
  bool _savingDeliveryBoy = false;

  // controllers for inline edit (filled from _sale on fetch)
  final discountCtl = TextEditingController();
  final taxCtl = TextEditingController();
  final deliveryCtl = TextEditingController();

  ApiClient get _api =>
      ApiClient(token: Provider.of<AuthProvider>(context, listen: false).token);

  @override
  void initState() {
    super.initState();
    _fetchSale();
  }

  @override
  void dispose() {
    discountCtl.dispose();
    taxCtl.dispose();
    deliveryCtl.dispose();
    super.dispose();
  }

  /* ====================== Data ====================== */

  Future<void> _fetchSale() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get("/sales/${widget.saleId}?include_balance=1");
      if (!mounted) return;
      setState(() {
        _sale = res['data'];
        // seed controllers
        discountCtl.text = (_sale?['discount'] ?? 0).toString();
        taxCtl.text = (_sale?['tax'] ?? 0).toString();
        deliveryCtl.text = (_sale?['delivery'] ?? 0).toString();
        _loading = false;
        final db = _sale?['delivery_boy'];
        _selectedDeliveryBoy = db;
        _selectedDeliveryBoyId = (db?['id'] is int)
            ? db['id']
            : int.tryParse('${db?['id']}');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load sale: $e")));
    }
  }

  bool get _deliveryBoyChanged {
    final currentId = int.tryParse('${_sale?['delivery_boy']?['id'] ?? ''}');
    return currentId != _selectedDeliveryBoyId;
  }

  Future<void> _saveDeliveryBoy() async {
    if (_sale == null) return;

    setState(() => _savingDeliveryBoy = true);

    try {
      final saleId = _sale!['id'];

      // ✅ This returns JSON Map, throws Exception on non-2xx
      final json = await _api.put(
        "/sales/$saleId/delivery-boy",
        body: {
          "delivery_boy_id": _selectedDeliveryBoyId, // null = unassign
        },
      );

      if (!mounted) return;

      setState(() {
        // ✅ reflect change locally
        _sale!['delivery_boy'] = _selectedDeliveryBoyId == null
            ? null
            : _selectedDeliveryBoy;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(json['message'] ?? 'Delivery boy updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _savingDeliveryBoy = false);
    }
  }

  Future<void> _pickDeliveryBoy() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token!;
    final deliveryBoy = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UserPickerSheet(token: token),
    );
    if (!mounted) return;
    if (deliveryBoy == null) {
      setState(() {
        _selectedDeliveryBoy = null;
        _selectedDeliveryBoyId = null;
      });
    } else {
      setState(() {
        _selectedDeliveryBoy = deliveryBoy;
        _selectedDeliveryBoyId = deliveryBoy['id'];
      });
    }
  }

  Future<void> _updateDiscountTax() async {
    // push only discount & tax
    try {
      await _api.put(
        "/sales/${widget.saleId}",
        body: {
          "discount": double.tryParse(discountCtl.text.trim()) ?? 0.0,
          "tax": double.tryParse(taxCtl.text.trim()) ?? 0.0,
          "delivery": double.tryParse(deliveryCtl.text.trim()) ?? 0.0,
        },
      );
      if (!mounted) return;
      _updated = true;
      await _fetchSale();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Updated discount/tax.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    }
  }

  /* ====================== Print ====================== */

  Future<void> _printInvoice() async {
    if (_sale == null) return;

    double _d(v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

    final sale = _sale!;
    final itemsRaw = (sale['items'] as List?) ?? const [];
    final paymentsRaw = (sale['payments'] as List?) ?? const [];

    final subtotal = _d(sale['subtotal']);
    final discount = _d(sale['discount']);
    final tax = _d(sale['tax']);
    final delivery = _d(sale['delivery']); // if your API returns it
    final total = _d(sale['total']);

    final paid = paymentsRaw.fold<double>(
      0,
      (sum, p) => sum + _d((p as Map)['amount']),
    );

    // ---- meta from response (preferred) ----
    final metaRaw = sale['meta'];
    final meta = (metaRaw is Map)
        ? metaRaw.cast<String, dynamic>()
        : <String, dynamic>{};

    // ---- build customer snapshot: from meta, otherwise from customer object ----
    Map<String, dynamic> customerSnap = {};
    final snapRaw = meta['customer_snapshot'];
    if (snapRaw is Map) {
      customerSnap = snapRaw.cast<String, dynamic>();
    } else {
      final c = sale['customer'];
      if (c is Map) {
        customerSnap = {
          "name":
              ((c['first_name'] ?? c['name'] ?? "Walk-in").toString() +
                      " " +
                      (c['last_name'] ?? "").toString())
                  .trim(),
          "phone": (c['phone'] ?? c['mobile'] ?? c['mobile_no'] ?? "")
              .toString(),
          "address": (c['address'] ?? c['full_address'] ?? "").toString(),
        };
      } else {
        customerSnap = {"name": "Walk-in", "phone": "", "address": ""};
      }
    }

    // ---- cash received: from meta first, otherwise assume paid (cash sale) ----
    final cashReceived = (meta['cash_received'] is num)
        ? (meta['cash_received'] as num).toDouble()
        : _d(meta['cash_received']) != 0
        ? _d(meta['cash_received'])
        : paid;

    // change amount
    final changeAmount = (cashReceived - total)
        .clamp(0, double.infinity)
        .toDouble();

    // delivery: from meta if exists else from sale['delivery']
    final metaDelivery = (meta['delivery'] is num)
        ? (meta['delivery'] as num).toDouble()
        : _d(meta['delivery']);
    final effectiveDelivery = metaDelivery != 0 ? metaDelivery : delivery;

    // ---- final meta for printing (ensure keys exist) ----
    final printMeta = <String, dynamic>{
      ...meta,
      "customer_snapshot": customerSnap,
      "cash_received": cashReceived,
      "delivery": effectiveDelivery,
      "payments": paymentsRaw,
    };

    final receiptNo = (sale['invoice_no'] ?? sale['id'] ?? 'N/A').toString();
    final createdAtStr = sale['created_at']?.toString();
    final dateTime = DateTime.tryParse(createdAtStr ?? '') ?? DateTime.now();

    // Build ReceiptItem list
    final receiptItems = itemsRaw.map((i) {
      final m = (i as Map);
      final name = (m['product']?['name'] ?? m['name'] ?? '-').toString();
      final price = _d(m['price']);
      final qty = _d(m['quantity']);
      final lineTotal = _d(m['total']) != 0 ? _d(m['total']) : (price * qty);

      return ReceiptItem(name: name, price: price, qty: qty, total: lineTotal);
    }).toList();

    // 🟡 set from your settings later
    final hasPrinter = false;

    if (!kIsWeb && hasPrinter) {
      const printerIp = "192.168.1.50";

      await ThermalPrinterService.instance.printSaleReceipt(
        printerIp: printerIp,
        shopName: "MR HUNGRY",
        shopAddress: "Mr Hungry Dhak Road Sukkur",
        shopPhone: "+923021922516",
        receiptNo: receiptNo,
        dateTime: dateTime,
        items: receiptItems,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        grandTotal: total,
        cashReceived: cashReceived,
        changeAmount: changeAmount,
        meta: printMeta,
      );
    } else {
      await ReceiptPreviewService.instance.previewReceipt(
        shopName: "MR HUNGRY",
        shopAddress: "Mr Hungry Dhak Road Sukkur",
        shopPhone: "+923021922516",
        receiptNo: receiptNo,
        dateTime: dateTime,
        items: receiptItems,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        grandTotal: total,
        cashReceived: cashReceived,
        changeAmount: changeAmount,
        meta: printMeta,
        logoAsset: 'assets/images/mr_hungry_logo.jpeg',
      );
    }
  }
  /* ====================== Build ====================== */

  String getSaleTitle(sale_type) {
    final t = (sale_type ?? '').toLowerCase();
    switch (t) {
      case 'dine_in':
        return 'Dine In';
      case 'delivery':
        return 'Delivery';
      case 'takeaway':
        return 'Take Away';
      case 'self':
        return 'Self';
      default:
        return 'Sales';
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = (_sale?['payments'] as List?) ?? [];
    final paid = payments.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p['amount'].toString()) ?? 0.0),
    );
    final total = double.tryParse(_sale?['total']?.toString() ?? "0") ?? 0.0;
    final remaining = total - paid;

    final balanceColor = remaining > 0
        ? Colors.red
        : remaining < 0
        ? Colors.orange
        : Colors.green;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _updated);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Sale Detail"),
          // actions: const [BranchIndicator(tappable: false)],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _sale == null
            ? const Center(child: Text("Sale not found"))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          "Invoice: ${_sale!['invoice_no']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Date: ${_sale!['created_at'].toString().substring(0, 10)}",
                            ),
                            Text(
                              "Sale Type: ${getSaleTitle(_sale!['sale_type'])}",
                            ),
                            Text(
                              "Customer: ${_sale!['customer']?['first_name'] ?? "Walk-in"} ${_sale!['customer']?['last_name'] ?? ""}",
                            ),
                            // Delivery Boy (editable)
                            InkWell(
                              onTap: _pickDeliveryBoy,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Delivery Boy: ${_selectedDeliveryBoy?['name'] ?? _sale?['delivery_boy']?['name'] ?? 'Select'}",
                                      ),
                                    ),
                                    const Icon(Icons.edit, size: 18),
                                  ],
                                ),
                              ),
                            ),

                            if (_deliveryBoyChanged) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _savingDeliveryBoy
                                          ? null
                                          : () {
                                              // reset selection back to current sale value
                                              final db = _sale?['delivery_boy'];
                                              setState(() {
                                                _selectedDeliveryBoy = db;
                                                _selectedDeliveryBoyId =
                                                    (db?['id'] is int)
                                                    ? db['id']
                                                    : int.tryParse(
                                                        '${db?['id']}',
                                                      );
                                              });
                                            },
                                      child: const Text("Cancel"),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _savingDeliveryBoy
                                          ? null
                                          : _saveDeliveryBoy,
                                      icon: _savingDeliveryBoy
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.save),
                                      label: const Text("Save"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.print),
                          onPressed: _printInvoice,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Items section
                    SaleItemsSection(sale: _sale!),

                    const SizedBox(height: 12),

                    // Summary with inline editable discount/tax
                    SaleTotalsEditable(
                      sale: _sale!,
                      discountController: discountCtl,
                      deliveryController: deliveryCtl,
                      taxController: taxCtl,
                      paid: paid,
                      balanceColor: balanceColor,
                      onSave: _updateDiscountTax,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
