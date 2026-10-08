import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Milio ya simu: kuita, mlio wa anayepigiwa, mute, na kukatika
class CallSounds {
  final AudioPlayer _loop = AudioPlayer(playerId: 'call_loop');
  final AudioPlayer _fx = AudioPlayer(playerId: 'call_fx');

  /// "Tuuu... tuuu" kwa mpigaji (kwenye spika ya sikio, kama simu ya kawaida)
  Future<void> startRingback({bool speaker = false}) => _startLoop(
    'ringback.wav',
    AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: speaker,
        audioMode: AndroidAudioMode.inCommunication,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.voiceCommunicationSignalling,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
    ),
  );

  /// Mlio wa simu inayoingia (unafuata sauti ya ringtone ya simu, na silent mode)
  Future<void> startRingtone() => _startLoop(
    'ringtone.wav',
    AudioContext(
      android: const AudioContextAndroid(
        audioMode: AndroidAudioMode.ringtone,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notificationRingtone,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
    ),
  );

  Future<void> stopLoop() async {
    try {
      await _loop.stop();
    } catch (_) {}
  }

  /// Mlio mfupi wakati wa mazungumzo (haukatizi sauti ya simu)
  Future<void> beep(String file, {required bool speaker}) => _playOnce(
    file,
    AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: speaker,
        audioMode: AndroidAudioMode.inCommunication,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.voiceCommunicationSignalling,
        audioFocus: AndroidAudioFocus.none,
      ),
    ),
  );

  Future<void> endTone() => _playOnce(
    'call_end.wav',
    AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.voiceCommunicationSignalling,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
    ),
  );

  Future<void> _startLoop(String file, AudioContext ctx) async {
    try {
      await _loop.stop();
      await _loop.setReleaseMode(ReleaseMode.loop);
      await _loop.setAudioContext(ctx);
      await _loop.play(AssetSource('sounds/$file'));
    } catch (e) {
      debugPrint('Sauti $file: $e');
    }
  }

  Future<void> _playOnce(String file, AudioContext ctx) async {
    try {
      await _fx.stop();
      await _fx.setReleaseMode(ReleaseMode.release);
      await _fx.setAudioContext(ctx);
      await _fx.play(AssetSource('sounds/$file'));
    } catch (e) {
      debugPrint('Sauti $file: $e');
    }
  }
}
