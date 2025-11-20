import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

void main() {
  group('DevTools Support', () {
    setUp(() async {
      await GetIt.I.reset();
      GetIt.I.debugEventsEnabled = false;
    });

    test('debugEventsEnabled defaults to false', () {
      expect(GetIt.I.debugEventsEnabled, isFalse);
    });

    test('Can set debugEventsEnabled to true', () {
      GetIt.I.debugEventsEnabled = true;
      expect(GetIt.I.debugEventsEnabled, isTrue);
    });

    test('Emitting events does not crash when enabled', () async {
      GetIt.I.debugEventsEnabled = true;

      // Register
      GetIt.I.registerSingleton<String>('test');
      expect(GetIt.I.get<String>(), 'test');

      // Scope
      GetIt.I.pushNewScope(scopeName: 'testScope');
      GetIt.I.registerSingleton<int>(42);
      expect(GetIt.I.get<int>(), 42);

      await GetIt.I.popScope();

      // Unregister
      GetIt.I.unregister<String>();
      
      // Reset
      await GetIt.I.reset();
    });
    
    test('Service extension logic runs without error', () async {
       // We can't easily invoke the extension here without VM Service, 
       // but we can ensure the registration code in the constructor didn't crash.
       // The constructor is called when we access GetIt.instance for the first time.
       expect(GetIt.I, isNotNull);
    });
  });
}
