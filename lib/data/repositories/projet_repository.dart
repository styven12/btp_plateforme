import '../../core/services/api_service.dart';
import '../models/projet_model.dart';

class ProjetRepository {
  ProjetRepository({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<List<ProjetModel>> getMesProjets() async {
    final result = await _api.get('/projects');
    return (result['projects'] as List? ?? const [])
        .map((value) => ProjetModel.fromMap(value as Map<String, dynamic>))
        .toList();
  }

  Future<ProjetModel> creerProjet({
    required String nom,
    required String lieu,
    String? description,
  }) async {
    final result = await _api.post(
      '/projects',
      body: {'name': nom, 'location': lieu, 'description': description},
    );
    return ProjetModel.fromMap(result['project'] as Map<String, dynamic>);
  }

  Future<void> demanderAcces(String code) async {
    await _api.post('/projects/join', body: {'code': code});
  }

  Future<void> validerDemande({
    required String id,
    required bool accepter,
  }) async {
    await _api.patch(
      '/projects/requests/$id',
      body: {'status': accepter ? 'approved' : 'rejected'},
    );
  }

  Future<void> ajouterJournal({
    required String projetId,
    required String description,
    required int avancement,
    String? photoUrl,
  }) async {
    await _api.post(
      '/projects/$projetId/journal',
      body: {
        'description': description,
        'progress': avancement,
        'photoUrl': ?photoUrl,
      },
    );
  }

  Future<void> laisserAvis({
    required String projetId,
    required String cibleId,
    required int note,
    String? commentaire,
  }) async {
    await _api.post(
      '/projects/$projetId/reviews',
      body: {'targetId': cibleId, 'rating': note, 'comment': commentaire},
    );
  }
}
