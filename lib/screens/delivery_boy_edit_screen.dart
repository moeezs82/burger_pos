import 'package:counter_iq/api/delivery_boy_service.dart';
import 'package:counter_iq/forms/user_form_screen.dart';
import 'package:counter_iq/providers/auth_provider.dart';
import 'package:counter_iq/providers/branch_provider.dart';
import 'package:counter_iq/screens/sales/sale_detail.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DeliveryBoyEditScreen extends StatefulWidget {
  final int deliveryBoyId;
  const DeliveryBoyEditScreen({super.key, required this.deliveryBoyId});

  @override
  State<DeliveryBoyEditScreen> createState() => _DeliveryBoyEditScreenState();
}

class _DeliveryBoyEditScreenState extends State<DeliveryBoyEditScreen>
    with SingleTickerProviderStateMixin {
  late DeliveryBoyService _service;
  late TabController _tab;

  // Receive modal state
  bool _postingReceive = false;
  final _amountController = TextEditingController();

  // Header state
  bool _loadingHeader = true;
  String? _errorHeader;
  Map<String, dynamic>? boy; // includes orders_total/received_total/balance

  // Orders state
  final int _pageSize = 10;
  bool _loadingOrders = false;
  bool _loadedOrdersOnce = false;
  String? _errorOrders;
  int _ordersPage = 1, _ordersLastPage = 1, _ordersTotal = 0;
  final List<Map<String, dynamic>> _orders = [];

  // Received state
  bool _loadingReceived = false;
  bool _loadedReceivedOnce = false;
  String? _errorReceived;
  int _rcvPage = 1, _rcvLastPage = 1, _rcvTotal = 0;
  final List<Map<String, dynamic>> _received = [];

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthProvider>().token!;
    _service = DeliveryBoyService(token: token);

    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHeader();
      _loadOrders(page: 1);
    });
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tab.indexIsChanging) {
      if (_tab.index == 0 && !_loadedOrdersOnce) _loadOrders(page: 1);
      if (_tab.index == 1 && !_loadedReceivedOnce) _loadReceived(page: 1);
    }
  }

  Future<void> _loadHeader() async {
    setState(() {
      _loadingHeader = true;
      _errorHeader = null;
    });
    try {
      final branchId = context.read<BranchProvider>().selectedBranchId;

      // Expected API response: data = { id, name, phone, email, status, orders_total, received_total, balance }
      final res = await _service.getDeliveryBoyDetail(id: widget.deliveryBoyId);

      setState(() {
        boy = (res['data'] as Map).cast<String, dynamic>();
      });
    } catch (e) {
      setState(() => _errorHeader = "Failed to load delivery boy: $e");
    } finally {
      setState(() => _loadingHeader = false);
    }
  }

  Future<void> _openReceiveModal() async {
    if (boy == null || _postingReceive) return;

    _amountController.text = "";

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              title: Row(
                children: [
                  const Icon(Icons.payments_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "Receive from Delivery Boy",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: "Close",
                    icon: const Icon(Icons.close),
                    onPressed: _postingReceive
                        ? null
                        : () => Navigator.pop(dlgCtx),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 320,
                    maxWidth: 420,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _amountController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Amount",
                            hintText: "0.00",
                            prefixIcon: Icon(Icons.currency_exchange_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final t = (v ?? "").trim();
                            if (t.isEmpty) return "Amount is required";
                            final parsed = double.tryParse(t);
                            if (parsed == null) return "Enter a valid number";
                            if (parsed <= 0) return "Amount must be > 0";
                            return null;
                          },
                          onFieldSubmitted: (_) async {
                            if (_postingReceive) return;
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            await _submitReceive(dlgCtx);
                            setLocal(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              actionsAlignment: MainAxisAlignment.end,
              actions: [
                OutlinedButton(
                  onPressed: _postingReceive
                      ? null
                      : () => Navigator.pop(dlgCtx),
                  child: const Text("Cancel"),
                ),
                FilledButton.icon(
                  onPressed: _postingReceive
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          await _submitReceive(dlgCtx);
                          setLocal(() {});
                        },
                  icon: _postingReceive
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReceive(BuildContext dlgCtx) async {
    setState(() => _postingReceive = true);
    try {
      final branchId = context.read<BranchProvider>().selectedBranchId;
      final amount = double.parse(_amountController.text.trim());
      // Expected endpoint: POST /delivery-boys/{id}/received
      await _service.createDeliveryBoyReceived(
        deliveryBoyId: widget.deliveryBoyId,
        amount: amount,
        branchId: branchId,
      );

      if (!mounted) return;

      Navigator.pop(dlgCtx);
      await _loadHeader();

      if (_tab.index == 0 && _loadedOrdersOnce) {
        await _loadOrders(page: _ordersPage);
      } else if (_tab.index == 1 && _loadedReceivedOnce) {
        await _loadReceived(page: _rcvPage);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Received recorded")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
      }
    } finally {
      if (mounted) setState(() => _postingReceive = false);
    }
  }

  Future<void> _loadOrders({required int page}) async {
    if (_loadingOrders) return;
    setState(() {
      _loadingOrders = true;
      _errorOrders = null;
    });
    try {
      final branchId = context.read<BranchProvider>().selectedBranchId;

      // Expected API response: data = { items: [], current_page, last_page, total }
      final res = await _service.getDeliveryBoyOrders(
        id: widget.deliveryBoyId,
        page: page,
        perPage: _pageSize,
        branchId: branchId,
      );

      final wrap = (res['data'] as Map).cast<String, dynamic>();
      final items = ((wrap['items'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      setState(() {
        _orders
          ..clear()
          ..addAll(items);
        _ordersPage = (wrap['current_page'] as num?)?.toInt() ?? page;
        _ordersLastPage =
            (wrap['last_page'] as num?)?.toInt() ?? _ordersLastPage;
        _ordersTotal = (wrap['total'] as num?)?.toInt() ?? _ordersTotal;
        _loadedOrdersOnce = true;
      });
    } catch (e) {
      setState(() => _errorOrders = "Failed to load orders: $e");
    } finally {
      setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadReceived({required int page}) async {
    if (_loadingReceived) return;
    setState(() {
      _loadingReceived = true;
      _errorReceived = null;
    });
    try {
      final branchId = context.read<BranchProvider>().selectedBranchId;

      // Expected API response: data = { items: [], current_page, last_page, total }
      final res = await _service.getDeliveryBoyReceived(
        id: widget.deliveryBoyId,
        page: page,
        perPage: _pageSize,
        branchId: branchId,
      );

      final wrap = (res['data'] as Map).cast<String, dynamic>();
      final items = ((wrap['items'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      setState(() {
        _received
          ..clear()
          ..addAll(items);
        _rcvPage = (wrap['current_page'] as num?)?.toInt() ?? page;
        _rcvLastPage = (wrap['last_page'] as num?)?.toInt() ?? _rcvLastPage;
        _rcvTotal = (wrap['total'] as num?)?.toInt() ?? _rcvTotal;
        _loadedReceivedOnce = true;
      });
    } catch (e) {
      setState(() => _errorReceived = "Failed to load received: $e");
    } finally {
      setState(() => _loadingReceived = false);
    }
  }

  Future<void> _refreshAll() async {
    if (_loadingHeader || _loadingOrders || _loadingReceived) return;

    await _loadHeader();

    if (_tab.index == 0) {
      await _loadOrders(page: _ordersPage);
    } else {
      await _loadReceived(page: _rcvPage);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Refreshed")));
  }

  Future<void> _openEdit() async {
    if (boy == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserFormScreen(user: boy)),
    );

    if (result == true) {
      await _loadHeader();
      if (_tab.index == 0 && _loadedOrdersOnce) _loadOrders(page: _ordersPage);
      if (_tab.index == 1 && _loadedReceivedOnce) {
        _loadReceived(page: _rcvPage);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Delivery boy updated")));
    }
  }

  String _m(num? v) => (v ?? 0).toStringAsFixed(2);

  Widget _segmentedTabBar(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final border = theme.dividerColor.withOpacity(0.35);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: TabBar(
          controller: _tab,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: theme.colorScheme.primary.withOpacity(0.08),
            border: Border.all(color: theme.colorScheme.primary, width: 0.8),
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          tabs: const [
            Tab(text: "Orders"),
            Tab(text: "Received"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Boy"),
        actions: [
          IconButton(
            tooltip: "Receive",
            icon: const Icon(Icons.payments_rounded),
            onPressed:
                (_loadingHeader ||
                    _loadingOrders ||
                    _loadingReceived ||
                    _postingReceive)
                ? null
                : _openReceiveModal,
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: (_loadingHeader || _loadingOrders || _loadingReceived)
                ? null
                : _refreshAll,
          ),
        ],
      ),
      body: _loadingHeader
          ? const Center(child: CircularProgressIndicator())
          : _errorHeader != null
          ? _ErrorView(message: _errorHeader!, onRetry: _loadHeader)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderBlockDeliveryBoy(boy: boy!, onEdit: _openEdit),
                        const SizedBox(height: 8),
                        _TotalsRowDeliveryBoy(boy: boy!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: (_loadingHeader || _postingReceive)
                          ? null
                          : _openReceiveModal,
                      icon: const Icon(Icons.payments_rounded),
                      label: const Text("Receive"),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                _segmentedTabBar(context),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _OrdersTab(
                        items: _orders,
                        isLoading: _loadingOrders,
                        error: _errorOrders,
                        page: _ordersPage,
                        lastPage: _ordersLastPage,
                        total: _ordersTotal,
                        onRetry: () => _loadOrders(page: _ordersPage),
                        onPrev: () => _loadOrders(page: _ordersPage - 1),
                        onNext: () => _loadOrders(page: _ordersPage + 1),
                        onRefresh: () async => _loadOrders(page: 1),
                      ),
                      _ReceivedTab(
                        items: _received,
                        isLoading: _loadingReceived,
                        error: _errorReceived,
                        page: _rcvPage,
                        lastPage: _rcvLastPage,
                        total: _rcvTotal,
                        onRetry: () => _loadReceived(page: _rcvPage),
                        onPrev: () => _loadReceived(page: _rcvPage - 1),
                        onNext: () => _loadReceived(page: _rcvPage + 1),
                        onRefresh: () async => _loadReceived(page: 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0.0;
  return 0.0;
}

String _money(dynamic v) => _toDouble(v).toStringAsFixed(2);

/* ============================ Tabs ============================ */

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onRetry,
    required this.onPrev,
    required this.onNext,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? error;
  final int page, lastPage, total;
  final VoidCallback onRetry, onPrev, onNext;
  final Future<void> Function() onRefresh;

  String _m(num? v) => (v ?? 0).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && items.isEmpty) {
      return _ErrorView(message: error!, onRetry: onRetry);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        children: [
          _SectionCard(
            child: items.isEmpty
                ? const _EmptyMini(text: "No orders to show")
                : Column(
                    children: [
                      for (final s in items) ...[
                        ListTile(
                          dense: true,
                          minVerticalPadding: 6,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          leading: const Icon(
                            Icons.local_shipping_rounded,
                            size: 18,
                          ),
                          title: Text(
                            s['invoice_no']?.toString() ?? "Invoice",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            "Date: ${s['invoice_date'] ?? s['date'] ?? '—'}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.75),
                            ),
                          ),
                          trailing: Text(
                            _money(s['total']),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () {
                            final saleId = (s['id'] as num?)?.toInt();
                            if (saleId == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SaleDetailScreen(saleId: saleId),
                              ),
                            );
                          },
                        ),
                        if (s != items.last)
                          Divider(
                            height: 10,
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.5),
                          ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          _Pager(
            page: page,
            lastPage: lastPage,
            total: total,
            onPrev: onPrev,
            onNext: onNext,
          ),
        ],
      ),
    );
  }
}

class _ReceivedTab extends StatelessWidget {
  const _ReceivedTab({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onRetry,
    required this.onPrev,
    required this.onNext,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? error;
  final int page, lastPage, total;
  final VoidCallback onRetry, onPrev, onNext;
  final Future<void> Function() onRefresh;

  String _m(num? v) => (v ?? 0).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && items.isEmpty) {
      return _ErrorView(message: error!, onRetry: onRetry);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        children: [
          _SectionCard(
            child: items.isEmpty
                ? const _EmptyMini(text: "No received entries to show")
                : Column(
                    children: [
                      for (final r in items) ...[
                        ListTile(
                          dense: true,
                          minVerticalPadding: 6,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          leading: const Icon(Icons.payments_rounded, size: 18),
                          title: Text(
                            (r['reference']?.toString().trim().isNotEmpty ??
                                    false)
                                ? r['reference'].toString()
                                : "Received",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            "Date: ${r['date'] ?? r['created_at'] ?? '—'}"
                            "${(r['method'] != null) ? "  •  ${r['method']}" : ""}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.75),
                            ),
                          ),
                          trailing: Text(
                            _money(r['amount']),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (r != items.last)
                          Divider(
                            height: 10,
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.5),
                          ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          _Pager(
            page: page,
            lastPage: lastPage,
            total: total,
            onPrev: onPrev,
            onNext: onNext,
          ),
        ],
      ),
    );
  }
}

/* ============================ Shared widgets ============================ */

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.35),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _HeaderBlockDeliveryBoy extends StatelessWidget {
  const _HeaderBlockDeliveryBoy({required this.boy, required this.onEdit});
  final Map<String, dynamic> boy;
  final VoidCallback onEdit;

  String _initialsFromName(String? name) {
    final t = (name ?? '').trim();
    if (t.isEmpty) return '?';
    final parts = t
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final s = (a + b).toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.textTheme.bodySmall?.color?.withOpacity(0.75);

    final name = (boy['name'] ?? '') as String;
    final email = (boy['email'] ?? '—').toString();
    final phone = (boy['phone'] ?? '—').toString();
    final status = (boy['status'] ?? 'active').toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            _initialsFromName(name),
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name.trim().isEmpty ? "(No name)" : name.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatusDot(status: status),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: "Edit delivery boy",
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.edit_rounded, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "Phone: $phone  •  Email: $email",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subtle, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalsRowDeliveryBoy extends StatelessWidget {
  const _TotalsRowDeliveryBoy({required this.boy});
  final Map<String, dynamic> boy;

  String _m(num? v) => _money(v);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final ordersTotal =
        (boy['orders_total'] as num?) ?? (boy['total_orders'] as num?) ?? 0;
    final receivedTotal =
        (boy['received_total'] as num?) ?? (boy['total_received'] as num?) ?? 0;
    final balance = (boy['balance'] as num?) ?? (ordersTotal - receivedTotal);

    Color balColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    if (balance > 0) {
      balColor = Colors.orange.shade800; // delivery boy owes company
    } else if (balance < 0) {
      balColor = Colors.green.shade800; // company owes delivery boy
    } else {
      balColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    }

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: "Balance",
            value: _m(balance),
            color: balColor,
            bold: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(label: "Debit (Orders)", value: _m(ordersTotal)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: "Credit (Received)",
            value: _m(receivedTotal),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.textTheme.bodySmall?.color?.withOpacity(0.75);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: subtle, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int lastPage;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withOpacity(0.75);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Total: $total", style: TextStyle(color: subtle)),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: page > 1 ? onPrev : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text("Prev"),
            ),
            const SizedBox(width: 8),
            Text("Page $page / $lastPage", style: TextStyle(color: subtle)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: page < lastPage ? onNext : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text("Next"),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: sub),
            const SizedBox(height: 8),
            const Text("Oops", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: sub),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color c;
    if (s == 'active') {
      c = Colors.green;
    } else if (s == 'inactive' || s == 'blocked') {
      c = Colors.red;
    } else {
      c = Colors.grey;
    }
    return Icon(Icons.circle, size: 8, color: c);
  }
}

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Center(
        child: Text(text, style: TextStyle(color: sub)),
      ),
    );
  }
}
