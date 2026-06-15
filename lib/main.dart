import 'package:flutter/material.dart';

void main() => runApp(const MorkvaApp());

/// Minimal app shell. The full design system and navigation land in Epic 0's
/// UI work; this exists so the engine (Epic 1) compiles and runs on web and
/// mobile from the single codebase.
class MorkvaApp extends StatelessWidget {
  const MorkvaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MorkvaCRM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8821E)),
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('MorkvaCRM'))),
    );
  }
}
