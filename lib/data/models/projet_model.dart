class ProjetModel {
  const ProjetModel({
    required this.id,
    required this.code,
    required this.nom,
    required this.entrepreneurId,
    this.moId,
    this.entreprise,
    this.lieu,
    this.description,
    this.avancement = 0,
    this.statut = 'active',
  });

  final String id;
  final String code;
  final String nom;
  final String entrepreneurId;
  final String? moId;
  final String? entreprise;
  final String? lieu;
  final String? description;
  final int avancement;
  final String statut;

  factory ProjetModel.fromMap(Map<String, dynamic> map) => ProjetModel(
    id: '${map['id'] ?? ''}',
    code: map['code'] as String? ?? '',
    nom: map['name'] as String? ?? map['nom'] as String? ?? '',
    entrepreneurId: '${map['entrepreneurId'] ?? map['entrepreneur_id'] ?? ''}',
    moId: map['ownerId'] == null ? null : '${map['ownerId']}',
    entreprise: map['companyName'] as String? ?? map['entreprise'] as String?,
    lieu: map['location'] as String? ?? map['lieu'] as String?,
    description: map['description'] as String?,
    avancement:
        (map['progress'] as num?)?.round() ?? (map['avancement'] as int? ?? 0),
    statut: map['status'] as String? ?? map['statut'] as String? ?? 'active',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': nom,
    'entrepreneurId': entrepreneurId,
    'ownerId': moId,
    'companyName': entreprise,
    'location': lieu,
    'description': description,
    'progress': avancement,
    'status': statut,
  };

  bool get aUnClient => moId != null;
}
