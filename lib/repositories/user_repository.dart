// // ignore: depend_on_referenced_packages
// class User {
//   final String id;
//   final String name;
//   final String email;

//   User({required this.id, required this.name, required this.email});

//   factory User.fromJson(Map<String, dynamic> json) {
//     return User(
//       id: json['id'] as String,
//       name: json['name'] as String,
//       email: json['email'] as String,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'name': name,
//       'email': email,
//     };
//   }
// }

// class UserRepository {
//   final ApiService _apiService;

//   UserRepository(this._apiService);

//   Future<User> getUser(String id) async {
//     final response = await _apiService.get('users/$id');
//     return User.fromJson(response);
//   }

//   Future<User> createUser(User user) async {
//     final response = await _apiService.post('users', user.toJson());
//     return User.fromJson(response);
//   }

//   // Adicione outros métodos para operações CRUD de usuário conforme necessário
// }

// class ApiService {
//   Future<Map<String, dynamic>> get(String endpoint) async {
//     // TODO: Implement actual API call logic
//     return {};
//   }

//   Future<Map<String, dynamic>> post(
//       String endpoint, Map<String, dynamic> data) async {
//     // TODO: Implement actual API call logic
//     return {};
//   }
// }
