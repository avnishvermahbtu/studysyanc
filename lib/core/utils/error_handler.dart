import 'package:flutter/material.dart';

void showApiKeyErrorDialog(BuildContext context, Object error) {
  final errorStr = error.toString().toLowerCase();

  // 1. Detect Network/Internet related issues (Offline/SocketExceptions)
  if (errorStr.contains("socketexception") ||
      errorStr.contains("failed host lookup") ||
      errorStr.contains("no address associated with hostname") ||
      errorStr.contains("clientexception")) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0f172a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Connection Failed 🌐",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: const Text(
            "Unable to connect to StudySync services. Please check your internet connection and try again.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Dismiss",
                style: TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
    return;
  }

  // 2. Detect API key related issues (invalid key, quota exceeded, blocked, etc.)
  if (errorStr.contains("api key") ||
      errorStr.contains("apikey") ||
      errorStr.contains("api_key") ||
      errorStr.contains("invalid") ||
      errorStr.contains("not valid") ||
      errorStr.contains("key not found")) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0f172a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xffef4444).withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xffef4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "API Key Error",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your Gemini API Key is invalid or not working correctly.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                "Details: ${error.toString()}",
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  } else if (errorStr.contains("503") ||
      errorStr.contains("429") ||
      errorStr.contains("overloaded") ||
      errorStr.contains("high demand") ||
      errorStr.contains("resource exhausted") ||
      errorStr.contains("unavailable")) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0f172a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Servers Busy ⚡",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: const Text(
            "The AI study service is currently experiencing very high demand. Please wait a few seconds and try again.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  } else {
    // Show standard AlertDialog box for other errors
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0f172a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "AI Service Error ⚠️",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Gemini API query encountered an error:",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
