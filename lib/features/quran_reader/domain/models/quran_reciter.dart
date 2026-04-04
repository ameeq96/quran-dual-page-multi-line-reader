class QuranReciter {
  const QuranReciter({
    required this.id,
    required this.name,
    required this.style,
  });

  factory QuranReciter.fromJson(Map<String, dynamic> json) {
    return QuranReciter(
      id: json['id'] as int,
      name: json['reciter_name'] as String,
      style: json['style'] as String?,
    );
  }

  final int id;
  final String name;
  final String? style;

  String get displayName {
    if (style == null || style!.trim().isEmpty) {
      return name;
    }
    return '$name - $style';
  }
}
