// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/auth_provider.dart';
import 'utils/constants.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final auth = AuthProvider();
  await auth.init();

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: AegisApp(auth: auth),
    ),
  );
}

class AegisApp extends StatelessWidget {
  final AuthProvider auth;
  const AegisApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(auth);

    return MaterialApp.router(
      title: 'Aegis',
      debugShowCheckedModeBanner: false,
      theme: buildAegisTheme(),
      routerConfig: router,
    );
  }
}
