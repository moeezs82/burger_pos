import 'package:counter_iq/api/auth_service.dart';
import 'package:counter_iq/providers/auth_provider.dart';
import 'package:counter_iq/providers/branch_provider.dart';
import 'package:counter_iq/screens/customers/customers_screen.dart';
import 'package:counter_iq/screens/login_screen.dart';
import 'package:counter_iq/screens/product_screen.dart';
import 'package:counter_iq/screens/purchases/purchase_claim_screen.dart';
import 'package:counter_iq/screens/purchases/purchases_screen.dart';
import 'package:counter_iq/screens/reports/report_hub_screen.dart';
import 'package:counter_iq/screens/sales/sale_returns_screen.dart';
import 'package:counter_iq/screens/sales/sale_screen.dart';
import 'package:counter_iq/screens/stock_screen.dart';
import 'package:counter_iq/screens/users_screen.dart';
import 'package:counter_iq/screens/vendors/vendors_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    context.watch<BranchProvider>(); // keep if you need branch UI later

    final token = context.read<AuthProvider>().token!;
    final authService = AuthService(token: token);

    Future<void> guardedOpen(VoidCallback open) async {
      final ok = await showPasswordModalAndVerify(
        context: context,
        verify: (pass) => authService.verifyPassword(pass),
      );
      if (!context.mounted) return;
      if (ok) open();
    }

    final tiles = <_Tile>[
      _Tile(
        icon: Icons.point_of_sale,
        title: "Sales",
        subtitle: "Create invoices",
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesScreen()),
        ),
      ),
      _Tile(
        icon: Icons.restaurant,
        title: "Dine In",
        subtitle: "Create invoices",
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SalesScreen(sale_type: 'dine_in'),
          ),
        ),
      ),
      _Tile(
        icon: Icons.delivery_dining,
        title: "Delivery",
        subtitle: "Create invoices",
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SalesScreen(sale_type: 'delivery'),
          ),
        ),
      ),
      _Tile(
        icon: Icons.takeout_dining,
        title: "Take Away",
        subtitle: "Create invoices",
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SalesScreen(sale_type: 'takeaway'),
          ),
        ),
      ),
      _Tile(
        icon: Icons.shopping_bag,
        title: "Self",
        subtitle: "Create invoices",
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SalesScreen(sale_type: 'self'),
          ),
        ),
      ),
      _Tile(
        icon: Icons.assignment_return,
        title: "Sale Returns",
        subtitle: "Process returns",
        color: Colors.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SaleReturnsScreen()),
        ),
      ),

      // ✅ LOCKED (ask password)
      _Tile(
        icon: Icons.shopping_cart_checkout,
        title: "Purchases",
        subtitle: "Supplier bills",
        color: Colors.blue,
        onTap: () => guardedOpen(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PurchasesScreen()),
          );
        }),
      ),

      _Tile(
        icon: Icons.assignment_return_outlined,
        title: "Purchase Claim",
        subtitle: "Damage/shortage",
        color: Colors.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PurchaseClaimsScreen()),
        ),
      ),

      _Tile(
        icon: Icons.inventory_2,
        title: "Products",
        subtitle: "Catalog & SKUs",
        color: Colors.green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductsScreen()),
        ),
      ),

      // ✅ LOCKED
      _Tile(
        icon: Icons.warehouse,
        title: "Stocks",
        subtitle: "On-hand by branch",
        color: Colors.red,
        onTap: () => guardedOpen(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockScreen()),
          );
        }),
      ),

      // ✅ LOCKED
      _Tile(
        icon: Icons.people,
        title: "Customers",
        subtitle: "CRM basics",
        color: Colors.orange,
        onTap: () => guardedOpen(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomersScreen()),
          );
        }),
      ),

      // ✅ LOCKED
      _Tile(
        icon: Icons.groups_2,
        title: "Vendors",
        subtitle: "Supplier list",
        color: Colors.orange,
        onTap: () => guardedOpen(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VendorsScreen()),
          );
        }),
      ),

      // ✅ LOCKED
      _Tile(
        icon: Icons.groups_2,
        title: "Users",
        subtitle: "App Users / Salesmen",
        color: Colors.orange,
        onTap: () => guardedOpen(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UsersScreen()),
          );
        }),
      ),

      // ✅ LOCKED
      _Tile(
        icon: Icons.bar_chart,
        title: "Reports",
        subtitle: "Analytics & KPIs",
        color: Colors.purple,
        onTap: () => guardedOpen(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsHubScreen()),
          );
        }),
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    final cols = width >= 1100
        ? 5
        : width >= 900
            ? 4
            : width >= 600
                ? 3
                : 2;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text("POS"),
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.9),
                  theme.colorScheme.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: Text(
                    (auth.user?['name']?.toString().isNotEmpty ?? false)
                        ? auth.user!['name'][0].toUpperCase()
                        : "?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome back,",
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        auth.user?['name']?.toString() ?? "User",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "Role: ${auth.user?['role']?[0] ?? 'Unknown'}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                itemCount: tiles.length,
                itemBuilder: (_, i) => _DashboardCard(tile: tiles[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> showPasswordModalAndVerify({
  required BuildContext context,
  required Future<bool> Function(String password) verify,
}) async {
  final ctrl = TextEditingController();
  bool posting = false;
  String? err;

  final ok =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dlgCtx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              Future<void> submit() async {
                final pass = ctrl.text.trim();
                if (pass.isEmpty) {
                  setLocal(() => err = "Password is required");
                  return;
                }
                setLocal(() {
                  posting = true;
                  err = null;
                });
                try {
                  final verified = await verify(pass);
                  if (!verified) {
                    setLocal(() {
                      posting = false;
                      err = "Wrong password";
                    });
                    return;
                  }
                  Navigator.pop(dlgCtx, true);
                } catch (e) {
                  setLocal(() {
                    posting = false;
                    err = e.toString();
                  });
                }
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                title: const Text("Enter Password"),
                content: TextField(
                  controller: ctrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    errorText: err,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => submit(),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        posting ? null : () => Navigator.pop(dlgCtx, false),
                    child: const Text("Cancel"),
                  ),
                  FilledButton(
                    onPressed: posting ? null : submit,
                    child: posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Continue"),
                  ),
                ],
              );
            },
          );
        },
      ) ??
      false;

  return ok;
}

class _Tile {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _DashboardCard extends StatelessWidget {
  final _Tile tile;
  const _DashboardCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: tile.onTap,
      child: Card(
        elevation: 2,
        shadowColor: tile.color.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tile.color.withOpacity(0.08),
                tile.color.withOpacity(0.02),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tile.color.withOpacity(0.15),
                ),
                child: Icon(tile.icon, size: 26, color: tile.color),
              ),
              const SizedBox(height: 12),
              Text(
                tile.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                tile.subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
