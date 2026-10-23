import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/storage/token_store.dart';

import 'fake_token_storage.dart';

void main() {
  test('persists tokens in secure storage when remember is true', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore store = TokenStore(storage: storage);

    await store.save('access', 'refresh', 3600, remember: true);

    expect(storage.values[TokenStore.accessKey], 'access');
    expect(storage.values[TokenStore.refreshKey], 'refresh');
    expect(store.isPersistent, isTrue);

    final TokenStore restarted = TokenStore(storage: storage);
    final AuthTokens? tokens = await restarted.read();
    expect(tokens, isNotNull);
    expect(tokens!.accessToken, 'access');
    expect(tokens.refreshToken, 'refresh');
    expect(restarted.isPersistent, isTrue);
  });

  test('keeps tokens in memory only when remember is false', () async {
    final FakeTokenStorage storage = FakeTokenStorage(<String, String>{
      TokenStore.accessKey: 'old-access',
      TokenStore.refreshKey: 'old-refresh',
    });
    final TokenStore store = TokenStore(storage: storage);

    await store.save('memory-access', 'memory-refresh', 600, remember: false);

    expect(storage.values, isEmpty);
    expect(store.isPersistent, isFalse);

    final AuthTokens? memoryTokens = await store.read();
    expect(memoryTokens!.accessToken, 'memory-access');

    final TokenStore restarted = TokenStore(storage: storage);
    expect(await restarted.read(), isNull);
  });

  test('clears both memory and secure storage', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore store = TokenStore(storage: storage);
    await store.save('access', 'refresh', 3600, remember: true);

    await store.clear();

    expect(storage.values, isEmpty);
    expect(await store.read(), isNull);
    expect(store.isPersistent, isFalse);
  });
}
