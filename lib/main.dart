import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/branch_provider.dart';
import 'providers/app_lock_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/lock_screen.dart';

void main() {
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => BranchProvider()),
        ChangeNotifierProvider(
          create: (_) => AppLockProvider()..init(),
        ),
      ],
      child: Consumer<AppLockProvider>(
        builder: (context, appLock, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Counter IQ',
            theme: ThemeData(primarySwatch: Colors.blue),
            home: appLock.isChecking
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : Consumer<AuthProvider>(
                    builder: (ctx, auth, _) => auth.isAuthenticated
                        ? const HomeScreen()
                        : const LoginScreen(),
                  ),
            builder: (context, child) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showExpiryAlertIfNeeded(context);
              });

              return Stack(
                children: [
                  if (child != null) child,
                  if (appLock.shouldShowLockScreen)
                    Positioned.fill(
                      child: LockScreen(
                        // passKey: appLock.passKey,
                        message: appLock.message,
                        // onUnlockSuccess: () {
                        //   context.read<AppLockProvider>().unlockApp();
                        // },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showExpiryAlertIfNeeded(BuildContext context) {
    final provider = context.read<AppLockProvider>();

    if (!provider.shouldShowExpiryAlert) return;

    provider.markAlertShown();

    showDialog(
      context: appNavigatorKey.currentContext ?? context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Subscription Reminder'),
          content: Text(
            provider.remainingDays > 0
                ? 'Your application access will expire in ${provider.remainingDays} day(s).\n\n${provider.message}'
                : provider.message,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}