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

  group('Dispose coverage', () {
    test('reset disposes both regular and named registrations', () async {
      // Register same type with and without instance name
      GetIt.I.registerSingleton<TestClass>(
        TestClass(),
        dispose: (_) {},
      );
      GetIt.I.registerSingleton<TestClass>(
        TestClass(),
        instanceName: 'named1',
        dispose: (_) {},
      );
      GetIt.I.registerSingleton<TestClass>(
        TestClass(),
        instanceName: 'named2',
        dispose: (_) {},
      );

      expect(testClassConstructorCount, 3);

      // Reset with dispose=true should dispose all registrations
      await GetIt.I.reset();

      // After reset, should be able to register again
      GetIt.I.registerSingleton<TestClass>(TestClass());
      expect(testClassConstructorCount, 4);
    });
  });

  group('Disposal order coverage', () {
    test(
        'strict LIFO disposal order with mixed named and unnamed registrations',
        () async {
      // Disposal follows strict LIFO (Last-In-First-Out) based on registrationNumber
      // Mixing named and unnamed registrations of the same type should not affect order

      final disposalOrder = <String>[];

      GetIt.I.pushNewScope(scopeName: 'test');

      // Register in this order:
      GetIt.I.registerSingleton<TestClass>(
        TestClass(),
        dispose: (_) => disposalOrder.add('TestClass-unnamed'),
      );

      GetIt.I.registerSingleton<int>(
        42,
        dispose: (_) => disposalOrder.add('int-unnamed'),
      );

      GetIt.I.registerSingleton<TestClass>(
        TestClass(),
        instanceName: 'named',
        dispose: (_) => disposalOrder.add('TestClass-named'),
      );

      GetIt.I.registerSingleton<String>(
        'test',
        dispose: (_) => disposalOrder.add('String-unnamed'),
      );

      // Pop scope and verify strict LIFO order
      await GetIt.I.popScope();

      // Should dispose in exact reverse order of registration
      expect(disposalOrder, [
        'String-unnamed', // Registered 4th
        'TestClass-named', // Registered 3rd
        'int-unnamed', // Registered 2nd
        'TestClass-unnamed', // Registered 1st
      ]);
    });
  });

  group('getAll coverage', () {
    test('getAll with async lazy singletons', () async {
      // Register multiple async lazy singletons of same type
      GetIt.I.registerLazySingletonAsync<TestClass>(
        () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return TestClass();
        },
        instanceName: 'async1',
      );
      GetIt.I.registerLazySingletonAsync<TestClass>(
        () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return TestClass();
        },
        instanceName: 'async2',
      );

      // Trigger creation by accessing them
      await GetIt.I.getAsync<TestClass>(instanceName: 'async1');
      await GetIt.I.getAsync<TestClass>(instanceName: 'async2');

      // getAll should return both instances
      final all = GetIt.I.getAll<TestClass>();
      expect(all.length, 2);
      expect(testClassConstructorCount, 2);
    });

    test('getAll with onlyInScope parameter', () {
      // Register in base scope
      GetIt.I.registerSingleton<TestClass>(TestClass());

      // Create a named scope
      GetIt.I.pushNewScope(scopeName: 'testScope');
      GetIt.I.registerSingleton<TestClass>(TestClass());
      GetIt.I.registerSingleton<TestClass>(TestClass(), instanceName: 'named');

      // getAll with onlyInScope should only return from that scope
      final scopeInstances =
          GetIt.I.getAll<TestClass>(onlyInScope: 'testScope');
      expect(scopeInstances.length, 2); // Two in testScope

      // getAll without scope should return from current scope
      final currentInstances = GetIt.I.getAll<TestClass>();
      expect(currentInstances.length, 2); // Same as scopeInstances
    });

    test('getAll with fromAllScopes parameter', () {
      // Register in base scope
      GetIt.I.registerSingleton<TestClass>(TestClass());

      // Create first scope
      GetIt.I.pushNewScope(scopeName: 'scope1');
      GetIt.I.registerSingleton<TestClass>(TestClass());

      // Create second scope
      GetIt.I.pushNewScope(scopeName: 'scope2');
      GetIt.I.registerSingleton<TestClass>(TestClass());

      // getAll with fromAllScopes should return from all scopes
      final allScopeInstances = GetIt.I.getAll<TestClass>(fromAllScopes: true);
      expect(
        allScopeInstances.length,
        3,
      ); // One from each: base, scope1, scope2
    });

    test('getAllAsync with onlyInScope parameter', () async {
      // Register different types in different scopes to verify scope isolation
      GetIt.I.registerLazySingletonAsync<TestClass>(
        () async => TestClass(),
      );

      GetIt.I.pushNewScope(scopeName: 'scope1');
      GetIt.I.registerLazySingletonAsync<String>(
        () async => 'scope1-value',
      );

      GetIt.I.pushNewScope(scopeName: 'scope2');
      GetIt.I.registerLazySingletonAsync<int>(
        () async => 42,
      );

      // getAllAsync with onlyInScope should return only String from scope1
      final scope1Instances =
          await GetIt.I.getAllAsync<String>(onlyInScope: 'scope1');
      expect(scope1Instances.length, 1);
      expect(scope1Instances.first, isA<String>());
      expect(scope1Instances.first, 'scope1-value');
    });

    test('getAllAsync with fromAllScopes parameter', () async {
      // Register async lazy singletons in different scopes
      GetIt.I.registerLazySingletonAsync<TestClass>(
        () async => TestClass(),
        instanceName: 'base',
      );

      GetIt.I.pushNewScope(scopeName: 'scope1');
      GetIt.I.registerLazySingletonAsync<TestClass>(
        () async => TestClass(),
        instanceName: 'scope1',
      );

      GetIt.I.pushNewScope(scopeName: 'scope2');
      GetIt.I.registerLazySingletonAsync<TestClass>(
        () async => TestClass(),
        instanceName: 'scope2',
      );

      // getAllAsync with fromAllScopes should return from all scopes
      final allInstances =
          await GetIt.I.getAllAsync<TestClass>(fromAllScopes: true);
      expect(allInstances.length, 3);
    });
  });

  group('registerCachedFactoryParamAsync coverage', () {
    test('registerCachedFactoryParamAsync should cache instances', () async {
      int callCount = 0;

      GetIt.I.registerCachedFactoryParamAsync<TestClass, String, int>(
        (param1, param2) async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return TestClass();
        },
      );

      // First call should execute factory
      final instance1 = await GetIt.I.getAsync<TestClass>(
        param1: 'test',
        param2: 42,
      );
      expect(callCount, 1);
      expect(instance1, isA<TestClass>());

      // Second call with same params should return cached instance
      final instance2 = await GetIt.I.getAsync<TestClass>(
        param1: 'test',
        param2: 42,
      );
      expect(callCount, 1); // Should not call factory again
      expect(identical(instance1, instance2), true);

      // Call with different params should execute factory again
      final instance3 = await GetIt.I.getAsync<TestClass>(
        param1: 'different',
        param2: 99,
      );
      expect(callCount, 2);
      expect(identical(instance1, instance3), false);
    });
  });

  group('findFirstObjectRegistration coverage', () {
    test('findFirstObjectRegistration by instance across scopes', () {
      // Register String instances with different values in different scopes
      GetIt.I.registerSingleton<String>('base-value', instanceName: 'base');

      GetIt.I.pushNewScope(scopeName: 'scope1');
      GetIt.I.registerSingleton<String>('scope1-value', instanceName: 'scope1');

      GetIt.I.pushNewScope(scopeName: 'scope2');
      GetIt.I.registerSingleton<String>('scope2-value', instanceName: 'scope2');

      // Get the scope1 instance to find its registration
      final scope1Instance = GetIt.I.get<String>(instanceName: 'scope1');

      // findFirstObjectRegistration should find the specific instance
      final registration =
          GetIt.I.findFirstObjectRegistration(instance: scope1Instance);
      expect(registration, isNotNull);
      expect(registration!.registeredWithType, String);
      expect(registration.instanceName, 'scope1');

      // Verify we got the right instance by checking its value
      expect(scope1Instance, 'scope1-value');
    });

    test(
        'findFirstObjectRegistration by type and name searches current scope first',
        () async {
      // Register named instances with different values in each scope
      GetIt.I.registerSingleton<String>(
        'base-target',
        instanceName: 'target',
      );

      GetIt.I.pushNewScope(scopeName: 'scope1');
      GetIt.I.registerSingleton<String>(
        'scope1-target',
        instanceName: 'target',
      );

      GetIt.I.pushNewScope(scopeName: 'scope2');
      GetIt.I.registerSingleton<String>(
        'scope2-target',
        instanceName: 'target',
      );

      // findFirstObjectRegistration searches from current scope backwards
      // so it should find scope2's 'target' first
      final registration =
          GetIt.I.findFirstObjectRegistration<String>(instanceName: 'target');
      expect(registration, isNotNull);
      expect(registration!.registeredWithType, String);
      expect(registration.instanceName, 'target');

      // Verify it found the current scope's instance (scope2)
      final instance = GetIt.I.get<String>(instanceName: 'target');
      expect(instance, 'scope2-target');

      // Pop scope2 and verify we now find scope1's instance
      await GetIt.I.popScope();
      final registration2 =
          GetIt.I.findFirstObjectRegistration<String>(instanceName: 'target');
      final instance2 = GetIt.I.get<String>(instanceName: 'target');
      expect(instance2, 'scope1-target');
      expect(registration2!.instanceName, 'target');
    });

    test(
        'findFirstObjectRegistration by type only searches current scope first',
        () async {
      // Register unnamed instances with different values in each scope
      GetIt.I.registerSingleton<String>('base-unnamed');

      GetIt.I.pushNewScope(scopeName: 'scope1');
      GetIt.I.registerSingleton<String>('scope1-unnamed');

      GetIt.I.pushNewScope(scopeName: 'scope2');
      GetIt.I.registerSingleton<String>('scope2-unnamed');

      // Should find the unnamed registration from current scope (scope2)
      final registration = GetIt.I.findFirstObjectRegistration<String>();
      expect(registration, isNotNull);
      expect(registration!.registeredWithType, String);
      expect(registration.instanceName, null); // Unnamed

      // Verify it found the current scope's instance
      final instance = GetIt.I.get<String>();
      expect(instance, 'scope2-unnamed');

      // Pop scope2 and verify we now find scope1's instance
      await GetIt.I.popScope();
      final registration2 = GetIt.I.findFirstObjectRegistration<String>();
      final instance2 = GetIt.I.get<String>();
      expect(instance2, 'scope1-unnamed');
      expect(registration2!.instanceName, null); // Still unnamed
    });
  });
}
