import 'package:smartagri/core/storage/token_store.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([Map<String, String>? initial])
    : values = <String, String>{...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
