import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Geräte-Suffix ist stabil und kurz (eindeutiger Player-Name)', () async {
    final storage = StorageService();
    final first = await storage.loadOrCreateDeviceSuffix();
    final second = await storage.loadOrCreateDeviceSuffix();
    expect(first.length, 4);
    expect(second, first);
  });

  test('Sendspin-Identität wird persistiert (kein neuer Geister-Player pro Start)',
      () async {
    final storage = StorageService();
    expect(await storage.loadSendspinIdentity(), isEmpty);
    await storage.saveSendspinIdentity({'sendspin-identity-sk': 'abc'});
    expect(await storage.loadSendspinIdentity(), {'sendspin-identity-sk': 'abc'});
  });
}
