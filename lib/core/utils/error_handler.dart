import 'package:flutter/material.dart';

void showApiKeyErrorDialog(BuildContext context, Object error) {
  final errorStr = error.toString().toLowerCase();

  // Detect API key related issues (invalid key, quota exceeded, blocked, etc.)
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
  } else {
    // Show standard floating snackbar for other errors
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error: ${error.toString()}"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
