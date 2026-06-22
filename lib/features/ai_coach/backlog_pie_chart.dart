import 'dart:math';
import 'package:flutter/material.dart';

class BacklogPieChart extends StatelessWidget {
  final Map<String, int> subjectCounts;

  const BacklogPieChart({super.key, required this.subjectCounts});

  Color _getSubjectColor(String sub) {
    switch (sub.toLowerCase()) {
      case 'physics':
        return const Color(0xff06b6d4); // Cyan
      case 'chemistry':
        return const Color(0xffec4899); // Pink/Magenta
      case 'mathematics':
      case 'math':
        return const Color(0xfff59e0b); // Amber/Orange
      case 'biology':
        return const Color(0xff10b981); // Emerald/Green
      default:
        return const Color(0xff6366f1); // Indigo
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = subjectCounts.values.fold<int>(0, (sum, val) => sum + val);
    if (total == 0) return const SizedBox.shrink();

    // Sort to keep order consistent
    final List<MapEntry<String, int>> entries = subjectCounts.entries
        .where((entry) => entry.value > 0)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff0f172a).withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "📊 Subject Breakdown",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "$total pending nodes",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Custom Painter for Donut Chart
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: DonutChartPainter(
                    entries: entries,
                    colors: entries.map((e) => _getSubjectColor(e.key)).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Legends
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.map((entry) {
                    final color = _getSubjectColor(entry.key);
                    final percent = (entry.value / total * 100).toInt();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70, 
                                fontSize: 13, 
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          ),
                          Text(
                            "$percent%",
                            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final List<Color> colors;

  DonutChartPainter({required this.entries, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = entries.fold<double>(0, (sum, val) => sum + val.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8; // Margin for stroke width
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -pi / 2;

    for (int i = 0; i < entries.length; i++) {
      final sweepAngle = (entries[i].value / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      // Draw arc slightly shorter than sweep to allow round caps spacing
      canvas.drawArc(rect, startAngle + 0.08, sweepAngle - 0.16, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
