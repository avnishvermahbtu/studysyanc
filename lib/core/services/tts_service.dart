import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  String? _currentlySpeakingText;
  bool _isSpeaking = false;
  
  // Callbacks list to support multiple UI listeners
  final List<Function(String?, bool)> _listeners = [];

  TTSService._internal() {
    _initTts();
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      _notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      _currentlySpeakingText = null;
      _notifyListeners();
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      _currentlySpeakingText = null;
      _notifyListeners();
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      _currentlySpeakingText = null;
      _notifyListeners();
    });
  }

  void addListener(Function(String?, bool) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(String?, bool) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_currentlySpeakingText, _isSpeaking);
    }
  }

  bool isSpeakingText(String text) {
    return _isSpeaking && _currentlySpeakingText == text;
  }

  Future<void> toggleSpeak(String text) async {
    if (isSpeakingText(text)) {
      await stop();
    } else {
      await stop();
      _currentlySpeakingText = text;
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    _currentlySpeakingText = null;
    _notifyListeners();
  }
}
