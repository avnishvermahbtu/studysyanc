import 'package:flutter/material.dart';

class BacklogCard extends StatelessWidget {
  final String subject;
  final String chapter;
  final bool completed;
  final Function(bool?) onChanged;
  final VoidCallback onDelete;

  const BacklogCard({
    super.key,
    required this.subject,
    required this.chapter,
    required this.completed,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.grey.shade900,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: ListTile(
        leading: Checkbox(
          value: completed,
          onChanged: onChanged,
        ),

        title: Text(
          chapter,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(.2),
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Text(
              subject,
              style: const TextStyle(
                color: Colors.blue,
              ),
            ),
          ),
        ),

        trailing: IconButton(
          icon: const Icon(
            Icons.delete,
            color: Colors.red,
          ),
          onPressed: onDelete,
        ),
      ),
    );
  }
}