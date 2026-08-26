import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/rest_alarm_player.dart';
import '../../core/motion/repset_motion.dart';
import '../../core/notifications/rest_notification_service.dart';

class RestCountdownRail extends StatefulWidget {
  const RestCountdownRail({
    required this.durationSeconds,
    required this.startedAt,
    required this.onDurationTap,
    this.onFinished,
    this.now,
    super.key,
  });

  final int durationSeconds;
  final DateTime? startedAt;
  final VoidCallback onDurationTap;
  final Future<void> Function()? onFinished;
  final DateTime Function()? now;

  @override
  State<RestCountdownRail> createState() => _RestCountdownRailState();
}

class _RestCountdownRailState extends State<RestCountdownRail> {
  Timer? _ticker;
  late int _remainingSeconds;
  bool _alarmPlayed = false;

  bool get _isRunning => widget.startedAt != null && _remainingSeconds > 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _calculateRemaining();
    _startTickerIfNeeded();
    _syncBackgroundAlert();
  }

  @override
  void didUpdateWidget(covariant RestCountdownRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) _alarmPlayed = false;
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.durationSeconds != widget.durationSeconds) {
      _ticker?.cancel();
      _remainingSeconds = _calculateRemaining();
      _startTickerIfNeeded();
      _syncBackgroundAlert();
    }
  }

  int _calculateRemaining() {
    final startedAt = widget.startedAt;
    if (startedAt == null) return widget.durationSeconds;
    final elapsed = (widget.now?.call() ?? DateTime.now())
        .difference(startedAt)
        .inSeconds;
    return (widget.durationSeconds - elapsed)
        .clamp(0, widget.durationSeconds)
        .toInt();
  }

  void _startTickerIfNeeded() {
    if (!_isRunning) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _calculateRemaining();
      if (next != _remainingSeconds && mounted) {
        setState(() => _remainingSeconds = next);
      }
      if (next == 0) {
        _ticker?.cancel();
        if (!_alarmPlayed) {
          _alarmPlayed = true;
          unawaited(RestNotificationService.cancel(_notificationKey));
          unawaited((widget.onFinished ?? RestAlarmPlayer.play)());
        }
      }
    });
  }

  void _syncBackgroundAlert() {
    final startedAt = widget.startedAt;
    if (startedAt == null) {
      unawaited(RestNotificationService.cancel(_notificationKey));
      return;
    }
    unawaited(
      RestNotificationService.schedule(
        restId: _notificationKey,
        finishesAt: startedAt.add(Duration(seconds: widget.durationSeconds)),
      ),
    );
  }

  String get _notificationKey => '${widget.key}-${widget.startedAt}';

  @override
  void dispose() {
    _ticker?.cancel();
    // A rest belongs to its active workout. Once that workout is finished or
    // discarded, its scheduled background alert must not survive on the device.
    unawaited(RestNotificationService.cancel(_notificationKey));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.startedAt != null;
    final progress = widget.durationSeconds == 0
        ? 0.0
        : _remainingSeconds / widget.durationSeconds;
    final time = _formatDuration(
      active ? _remainingSeconds : widget.durationSeconds,
    );
    return Semantics(
      button: true,
      label: active
          ? '$time rest remaining. Change rest duration.'
          : '$time rest. Change rest duration.',
      child: InkWell(
        onTap: widget.onDurationTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: _DotTrack(
                  active: active,
                  progress: progress,
                  reverse: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedDefaultTextStyle(
                  duration: RepSetMotion.fast,
                  style: TextStyle(
                    color: active
                        ? const Color(0xffd7ff4f)
                        : const Color(0xff91a184),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  child: Text(time),
                ),
              ),
              Expanded(
                child: _DotTrack(active: active, progress: progress),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotTrack extends StatelessWidget {
  const _DotTrack({
    required this.active,
    required this.progress,
    this.reverse = false,
  });

  static const _dotCount = 12;
  final bool active;
  final double progress;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final litCount = (progress * _dotCount).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_dotCount, (index) {
        final lit =
            active &&
            (reverse ? index >= _dotCount - litCount : index < litCount);
        return AnimatedContainer(
          duration: RepSetMotion.fast,
          width: lit ? 4 : 3,
          height: lit ? 4 : 3,
          decoration: BoxDecoration(
            color: lit ? const Color(0xffd7ff4f) : const Color(0xff425044),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
