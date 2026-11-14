import 'package:flutter/material.dart';
import '../../../core/widgets/pulse_mark.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: PulseMark(size: 64, animate: true)));
}
