import 'dart:convert';

class Milestone {
  final String dayOrWeek;
  final String title;
  final List<String> tasks;

  Milestone({
    required this.dayOrWeek,
    required this.title,
    required this.tasks,
  });

  Map<String, dynamic> toMap() {
    return {
      'dayOrWeek': dayOrWeek,
      'title': title,
      'tasks': tasks,
    };
  }

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      dayOrWeek: map['dayOrWeek'] ?? '',
      title: map['title'] ?? '',
      tasks: List<String>.from(map['tasks'] ?? []),
    );
  }
}

class Roadmap {
  final String title;
  final String description;
  final List<Milestone> milestones;

  Roadmap({
    required this.title,
    required this.description,
    required this.milestones,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'milestones': milestones.map((x) => x.toMap()).toList(),
    };
  }

  factory Roadmap.fromMap(Map<String, dynamic> map) {
    return Roadmap(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      milestones: List<Milestone>.from(
        (map['milestones'] ?? []).map((x) => Milestone.fromMap(x)),
      ),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Roadmap.fromJson(String source) => Roadmap.fromMap(jsonDecode(source));
}
