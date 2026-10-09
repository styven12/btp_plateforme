class AvisModel {
  const AvisModel({
    required this.id,
    required this.auteurId,
    required this.cibleId,
    required this.note,
    required this.date,
    this.commentaire = '',
    this.projetId,
    this.auteur,
  });

  final String id;
  final String? projetId;
  final String auteurId;
  final String cibleId;
  final String? auteur;
  final int note;
  final String commentaire;
  final DateTime date;

  factory AvisModel.fromMap(Map<String, dynamic> map) => AvisModel(
    id: '${map['id'] ?? ''}',
    projetId: map['projectId'] == null ? null : '${map['projectId']}',
    auteurId: '${map['authorId'] ?? ''}',
    cibleId: '${map['targetId'] ?? ''}',
    auteur: map['authorName'] as String?,
    note: (map['rating'] as num?)?.round() ?? 0,
    commentaire: map['comment'] as String? ?? '',
    date: DateTime.tryParse('${map['createdAt'] ?? ''}') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'projectId': projetId,
    'authorId': auteurId,
    'targetId': cibleId,
    'authorName': auteur,
    'rating': note,
    'comment': commentaire,
    'createdAt': date.toIso8601String(),
  };

  String get etoiles => '★' * note.clamp(0, 5) + '☆' * (5 - note.clamp(0, 5));
}
