import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AmbientSoundService {
  static final AmbientSoundService _instance = AmbientSoundService._internal();
  factory AmbientSoundService() => _instance;

  AmbientSoundService._internal();

  final AudioPlayer _lofiPlayer = AudioPlayer();
  final AudioPlayer _rainPlayer = AudioPlayer();
  final AudioPlayer _campfirePlayer = AudioPlayer();

  bool _initialized = false;

  final String _lofiUrl = "https://pub-c5e31b5cdafb419a866169d8d3f28f4d.r2.dev/lofi_focus.mp3";
  final String _rainUrl = "https://pub-c5e31b5cdafb419a866169d8d3f28f4d.r2.dev/rain_loop.mp3";
  final String _campfireUrl = "https://pub-c5e31b5cdafb419a866169d8d3f28f4d.r2.dev/campfire_loop.mp3";

  Future<void> _initPlayers() async {
    if (_initialized) return;

    try {
      await _lofiPlayer.setReleaseMode(ReleaseMode.loop);
      await _rainPlayer.setReleaseMode(ReleaseMode.loop);
      await _campfirePlayer.setReleaseMode(ReleaseMode.loop);
      _initialized = true;
    } catch (e) {
      debugPrint("Error initializing players: $e");
    }
  }

  Future<void> playTrack(String type, double volume) async {
    await _initPlayers();
    try {
      if (type == "lofi") {
        if (_lofiPlayer.state != PlayerState.playing) {
          await _lofiPlayer.setVolume(volume);
          await _lofiPlayer.play(UrlSource(_lofiUrl));
        } else {
          await _lofiPlayer.setVolume(volume);
        }
      } else if (type == "rain") {
        if (_rainPlayer.state != PlayerState.playing) {
          await _rainPlayer.setVolume(volume);
          await _rainPlayer.play(UrlSource(_rainUrl));
        } else {
          await _rainPlayer.setVolume(volume);
        }
      } else if (type == "campfire") {
        if (_campfirePlayer.state != PlayerState.playing) {
          await _campfirePlayer.setVolume(volume);
          await _campfirePlayer.play(UrlSource(_campfireUrl));
        } else {
          await _campfirePlayer.setVolume(volume);
        }
      }
    } catch (e) {
      debugPrint("Error playing ambient track $type: $e");
    }
  }

  Future<void> stopTrack(String type) async {
    try {
      if (type == "lofi") {
        await _lofiPlayer.stop();
      } else if (type == "rain") {
        await _rainPlayer.stop();
      } else if (type == "campfire") {
        await _campfirePlayer.stop();
      }
    } catch (e) {
      debugPrint("Error stopping track $type: $e");
    }
  }

  Future<void> setTrackVolume(String type, double volume) async {
    try {
      if (type == "lofi") {
        await _lofiPlayer.setVolume(volume);
      } else if (type == "rain") {
        await _rainPlayer.setVolume(volume);
      } else if (type == "campfire") {
        await _campfirePlayer.setVolume(volume);
      }
    } catch (e) {
      debugPrint("Error setting volume for track $type: $e");
    }
  }

  Future<void> stopAll() async {
    try {
      await _lofiPlayer.stop();
      await _rainPlayer.stop();
      await _campfirePlayer.stop();
    } catch (e) {
      debugPrint("Error stopping all tracks: $e");
    }
  }

  Future<void> dispose() async {
    try {
      await _lofiPlayer.dispose();
      await _rainPlayer.dispose();
      await _campfirePlayer.dispose();
    } catch (e) {
      debugPrint("Error disposing ambient players: $e");
    }
  }
}
