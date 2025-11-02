import 'package:get_it/get_it.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:test/test.dart';

int testClassConstructorCount = 0;

class TestClass {
  TestClass() {
    testClassConstructorCount++;
  }
}

class TestClassDisposable implements Disposable {
  bool isDisposed = false;

  @override
  void onDispose() {
    isDisposed = true;
  }
}

class TestClassShadowHandler with ShadowChangeHandlers {
  bool isShadowed = false;
  Object? shadowingObject;

  @override
  void onGetShadowed(Object shadowing) {
    isShadowed = true;
    shadowingObject = shadowing;
  }

  @override
  void onLeaveShadow(Object shadowing) {
    isShadowed = false;
    shadowingObject = null;
  }
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    testClassConstructorCount = 0;
  });

  group('Weak reference coverage', () {
    test('resetLazySingleton with weak reference clears weakReferenceInstance',
        () async {
      // Register a lazy singleton with weak reference
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass(),
        useWeakReference: true,
      );

      // Get the instance
      final instance1 = GetIt.I<TestClass>();
      expect(testClassConstructorCount, 1);

      // Reset the lazy singleton
      await GetIt.I.resetLazySingleton<TestClass>();

      // Get a new instance - should create a new one
      final instance2 = GetIt.I<TestClass>();
      expect(testClassConstructorCount, 2);
      expect(identical(instance1, instance2), false);
    });
  });

  group('Disposable interface coverage', () {
    test('registerSingleton with Disposable and disposeFunc throws assertion',
        () {
      expect(
        () => GetIt.I.registerSingleton<TestClassDisposable>(
          TestClassDisposable(),
          dispose: (instance) {
            instance.onDispose();
          },
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ShadowChangeHandlers coverage', () {
    test('registerLazySingleton with ShadowChangeHandlers calls onGetShadowed',
        () {
      // Register in base scope
      final baseInstance = TestClassShadowHandler();
      GetIt.I.registerLazySingleton<TestClassShadowHandler>(
        () => baseInstance,
      );

      // Access the base instance first to create it
      final base = GetIt.I<TestClassShadowHandler>();
      expect(base, baseInstance);

      // Push a new scope
      GetIt.I.pushNewScope();

      // Register in new scope - this should shadow the base instance
      final scopeInstance = TestClassShadowHandler();
      GetIt.I.registerLazySingleton<TestClassShadowHandler>(
        () => scopeInstance,
      );

      // Access the lazy singleton to trigger creation and shadow callback
      final accessed = GetIt.I<TestClassShadowHandler>();

      // The base instance should be notified it's being shadowed
      expect(baseInstance.isShadowed, true);
      expect(baseInstance.shadowingObject, scopeInstance);
      expect(accessed, scopeInstance);
    });
  });

  group('Cached factory async coverage', () {
    test('registerCachedFactoryAsync returns cached instance', () async {
      int creationCount = 0;
      GetIt.I.registerCachedFactoryAsync<TestClass>(
        () async {
          creationCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return TestClass();
        },
      );

      // First call creates instance
      final instance1 = await GetIt.I.getAsync<TestClass>();
      expect(creationCount, 1);

      // Second call returns cached instance (weak reference still valid)
      final instance2 = await GetIt.I.getAsync<TestClass>();
      expect(creationCount, 1); // Should not create new instance
      expect(identical(instance1, instance2), true);
    });

    test('registerCachedFactoryAsync creates new instance after GC', () async {
      int creationCount = 0;
      GetIt.I.registerCachedFactoryAsync<TestClass>(
        () async {
          creationCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return TestClass();
        },
      );

      // First call creates instance (not keeping reference)
      await GetIt.I.getAsync<TestClass>();
      expect(creationCount, 1);

      // Force garbage collection
      await forceGC();
      await Future.delayed(const Duration(milliseconds: 50));

      // After GC, weak reference should be cleared, creating new instance
      final instance2 = await GetIt.I.getAsync<TestClass>();
      expect(creationCount, 2); // Should have created a new instance
      expect(instance2, isA<TestClass>());
    });
  });

  group('Async lazy singleton coverage', () {
    test('registerLazySingletonAsync with weak reference', () async {
      int creationCount = 0;
      GetIt.I.registerLazySingletonAsync<TestClass>(
        () async {
          creationCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return TestClass();
        },
        useWeakReference: true,
      );

      // First call creates instance
      final instance1 = await GetIt.I.getAsync<TestClass>();
      expect(creationCount, 1);

      // Second call returns same instance (weak reference still valid)
      final instance2 = await GetIt.I.getAsync<TestClass>();
      expect(creationCount, 1);
      expect(identical(instance1, instance2), true);
    });

    test(
        'registerLazySingletonAsync returns pending result on concurrent calls',
        () async {
      int creationCount = 0;
      GetIt.I.registerLazySingletonAsync<TestClass>(
        () async {
          creationCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return TestClass();
        },
      );

      // Start two concurrent getAsync calls
      final future1 = GetIt.I.getAsync<TestClass>();
      final future2 = GetIt.I.getAsync<TestClass>();

      // Both should complete
      final results = await Future.wait([future1, future2]);

      // Should only have created one instance
      expect(creationCount, 1);
      expect(identical(results[0], results[1]), true);
    });

    test(
        'registerLazySingletonAsync with ShadowChangeHandlers calls onGetShadowed',
        () async {
      // Register in base scope
      final baseInstance = TestClassShadowHandler();
      GetIt.I.registerLazySingletonAsync<TestClassShadowHandler>(
        () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return baseInstance;
        },
      );

      // Access the base instance first to create it
      final base = await GetIt.I.getAsync<TestClassShadowHandler>();
      expect(base, baseInstance);

      // Push a new scope
      GetIt.I.pushNewScope();

      // Register in new scope - this should shadow the base instance
      final scopeInstance = TestClassShadowHandler();
      GetIt.I.registerLazySingletonAsync<TestClassShadowHandler>(
        () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return scopeInstance;
        },
      );

      // Access the lazy singleton to trigger creation and shadow callback
      final accessed = await GetIt.I.getAsync<TestClassShadowHandler>();

      // The base instance should be notified it's being shadowed
      expect(baseInstance.isShadowed, true);
      expect(baseInstance.shadowingObject, scopeInstance);
      expect(accessed, scopeInstance);
    });
  });
}
