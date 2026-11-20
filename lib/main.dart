import 'package:flutter/material.dart';

import 'api_service.dart';
import 'screens/public_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSession();
  runApp(const JobBoardApp());
}

class JobBoardApp extends StatelessWidget {
  const JobBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bacheca Lavoro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const JobsListScreen(),
    );
  }
}