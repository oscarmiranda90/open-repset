import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract final class RestAlarmPlayer {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/alarmEnd.mp3'));
    } catch (error) {
      debugPrint('Rest alarm could not play: $error');
    }
  }
}
