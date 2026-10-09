class JournalModel {
  const JournalModel({
    required this.id,
    required this.description,
    required this.date,
    required this.avancement,
    this.photoUrl,
    this.auteur,
  });

  final String id;
  final String description;
  final String? photoUrl;
  final String? auteur;
  final DateTime date;
  final int avancement;

  factory JournalModel.fromMap(Map<String, dynamic> map) => JournalModel(
    id: '${map['id'] ?? ''}',
    description: map['description'] as String? ?? '',
    photoUrl: map['photoUrl'] as String? ?? map['photo_url'] as String?,
    auteur: map['authorName'] as String?,
    date:
        DateTime.tryParse('${map['createdAt'] ?? map['date'] ?? ''}') ??
        DateTime.now(),
    avancement:
        (map['progress'] as num?)?.round() ?? (map['avancement'] as int? ?? 0),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'photoUrl': photoUrl,
    'authorName': auteur,
    'createdAt': date.toIso8601String(),
    'progress': avancement,
  };
}
