import '../../core/services/api_service.dart';
import '../models/user.model.dart';

class AuthRepository {
  AuthRepository({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<UserModel> login({
    required String telephone,
    required String password,
  }) async {
    final result = await _api.post(
      '/auth/login',
      body: {'telephone': telephone, 'password': password},
    );
    final user = UserModel.fromMap(result['user'] as Map<String, dynamic>);
    await _api.saveToken(result['token'] as String, role: user.role);
    return user;
  }

  Future<UserModel> register(Map<String, dynamic> data) async {
    final result = await _api.post('/auth/register', body: data);
    final user = UserModel.fromMap(result['user'] as Map<String, dynamic>);
    await _api.saveToken(result['token'] as String, role: user.role);
    return user;
  }

  Future<void> logout() => _api.clearToken();
}
