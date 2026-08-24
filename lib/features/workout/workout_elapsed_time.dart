import 'dart:async';

import 'package:flutter/material.dart';

class WorkoutElapsedTime extends StatefulWidget {
  const WorkoutElapsedTime({required this.startedAt, this.style, super.key});

  final DateTime startedAt;
  final TextStyle? style;

  @override
  State<WorkoutElapsedTime> createState() => _WorkoutElapsedTimeState();
}

class _WorkoutElapsedTimeState extends State<WorkoutElapsedTime> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds',
      style: widget.style,
    );
  }
}
