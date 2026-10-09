class UserModel {
  const UserModel({
    required this.id,
    required this.telephone,
    required this.nom,
    required this.role,
    this.ville,
    this.entreprise,
    this.rccm,
    this.metier,
    this.experience,
  });

  final String id;
  final String telephone;
  final String nom;
  final String role;
  final String? ville;
  final String? entreprise;
  final String? rccm;
  final String? metier;
  final int? experience;

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: '${map['id'] ?? ''}',
    telephone: map['telephone'] as String? ?? '',
    nom: map['fullName'] as String? ?? map['nom'] as String? ?? '',
    role: map['role'] as String? ?? 'mo',
    ville: map['city'] as String? ?? map['ville'] as String?,
    entreprise: map['companyName'] as String? ?? map['entreprise'] as String?,
    rccm: map['rccm'] as String?,
    metier: map['trade'] as String? ?? map['metier'] as String?,
    experience: (map['experienceYears'] ?? map['experience']) as int?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'telephone': telephone,
    'fullName': nom,
    'role': role,
    'city': ville,
    'companyName': entreprise,
    'rccm': rccm,
    'trade': metier,
    'experienceYears': experience,
  };
}
