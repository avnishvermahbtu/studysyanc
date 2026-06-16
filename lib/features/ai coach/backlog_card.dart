import 'package:flutter/material.dart';

class BacklogCard extends StatelessWidget {
  final String subject;
  final String chapter;
  final bool completed;
  final String priority;
  final int estimatedMinutes;
  final String notes;
  final Function(bool?) onChanged;
  final VoidCallback onDelete;

  const BacklogCard({
    super.key,
    required this.subject,
    required this.chapter,
    required this.completed,
    required this.priority,
    required this.estimatedMinutes,
    required this.notes,
    required this.onChanged,
    required this.onDelete,
  });

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

  Color _getPriorityColor(String prio) {
    switch (prio.toLowerCase()) {
      case 'high':
        return const Color(0xffef4444); // Red
      case 'medium':
        return const Color(0xfff97316); // Orange
      case 'low':
        return const Color(0xff22c55e); // Green
      default:
        return const Color(0xff64748b); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final subColor = _getSubjectColor(subject);
    final prioColor = _getPriorityColor(priority);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff0f172a).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed 
              ? Colors.green.withOpacity(0.3) 
              : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: completed
                ? Colors.green.withOpacity(0.05)
                : prioColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Priority Indicator Line
              Container(
                width: 5,
                color: completed ? Colors.green : prioColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Subject Badge, Priority Tag, Time Est
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: subColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: subColor.withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              subject,
                              style: TextStyle(
                                color: subColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Priority Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: prioColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(
                                color: prioColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Time Duration Estimate
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Colors.white54, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '${estimatedMinutes}m',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Chapter Title & Checkbox Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: completed ? TextDecoration.lineThrough : null,
                                    decorationColor: Colors.white54,
                                  ),
                                ),
                                if (notes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    notes,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Custom Interactive Checkbox
                          GestureDetector(
                            onTap: () => onChanged(!completed),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: completed ? Colors.green : Colors.transparent,
                                border: Border.all(
                                  color: completed ? Colors.green : Colors.white38,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: completed
                                  ? const Icon(Icons.check, size: 16, color: Colors.black)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 6),
                      // Actions row (e.g. Delete)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.redAccent.withOpacity(0.8),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Delete', style: TextStyle(fontSize: 12)),
                            onPressed: onDelete,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}