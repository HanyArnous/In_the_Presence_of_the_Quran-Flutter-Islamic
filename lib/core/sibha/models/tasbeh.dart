class Tasbeeh {
  final String arabic;
  final String translation;
  final String pronunciation;
  final int id;
  final int? defaultCount;
  final bool enableSound;

  Tasbeeh({
    required this.id,
    required this.arabic,
    required this.translation,
    required this.pronunciation,
    this.defaultCount,
    this.enableSound = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'arabic': arabic,
      'translation': translation,
      'pronunciation': pronunciation,
      'defaultCount': defaultCount,
      'enableSound': enableSound,
    };
  }

  factory Tasbeeh.fromJson(Map<String, dynamic> json) {
    return Tasbeeh(
      id: json['id'] as int,
      arabic: json['arabic'] as String,
      translation: json['translation'] as String? ?? '',
      pronunciation: json['pronunciation'] as String? ?? '',
      defaultCount: json['defaultCount'] as int?,
      enableSound: json['enableSound'] as bool? ?? true,
    );
  }
}