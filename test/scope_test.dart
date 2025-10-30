// ignore_for_file: unnecessary_type_check, unused_local_variable, unreachable_from_main

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  final String? id;

  TestClass([this.id]) {
    constructorCounter++;
  }

  void dispose() {
    disposeCounter++;
  }
}

class TestClassShadowChangHandler extends TestBaseClass
    with ShadowChangeHandlers {
  final String? id;
  final void Function(bool isShadowed, Object shadowIngObject) onShadowChange;

  TestClassShadowChangHandler(this.onShadowChange, [this.id]) {
    constructorCounter++;
  }

  void dispose() {
    disposeCounter++;
  }

  @override
  void onGetShadowed(Object shadowing) {
    onShadowChange(true, shadowing);
  }

  @override
  void onLeaveShadow(Object shadowing) {
    onShadowChange(false, shadowing);
  }
}

class TestClass2 {
  final String? id;

  TestClass2([this.id]);

  void dispose() {
    disposeCounter++;
  }
}

class TestClass3 {}

void main() {
  setUp(() async {
    // make sure the instance is cleared before each test
    await GetIt.I.reset();
    constructorCounter = 0;
    disposeCounter = 0;
    errorCounter = 0;
  });

  test('unregister constant that was registered in a lower scope', () {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));
    getIt.registerSingleton<TestClass2>(TestClass2('Basescope'));

    getIt.pushNewScope();

    getIt.registerSingleton<TestClass>(TestClass('2. scope'));

    final instance2 = getIt.get<TestClass2>();

    expect(instance2.id, 'Basescope');

    getIt.unregister<TestClass2>();

    expect(() => getIt.get<TestClass2>(), throwsStateError);
  });

  test('register constant in two scopes', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));
    getIt.registerSingleton<TestClass2>(TestClass2('Basescope'));

    getIt.pushNewScope();

    getIt.registerSingleton<TestClass>(TestClass('2. scope'));

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);
    expect(instance1.id, '2. scope');

    final instance2 = getIt.get<TestClass2>();

    expect(instance2.id, 'Basescope');
  });

  test('register constant in two scopes with ShadowChangeHandlers', () async {
    final getIt = GetIt.instance;

    bool isShadowed = false;
    Object? shadowingObject;

    getIt.registerSingleton<TestClassShadowChangHandler>(
      TestClassShadowChangHandler(
        (shadowState, shadow) {
          isShadowed = shadowState;
          shadowingObject = shadow;
        },
        'Basescope',
      ),
    );

    getIt.pushNewScope();

    final testClassShadowChangHandlerInstance = TestClassShadowChangHandler(
      (shadowState, shadow) {},
      'Scope 2',
    );
    getIt.registerSingleton<TestClassShadowChangHandler>(
      testClassShadowChangHandlerInstance,
    );

    expect(isShadowed, true);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
    shadowingObject = null;

    await getIt.popScope();

    expect(isShadowed, false);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
  });

  test('register constant in two scopes with ShadowChangeHandlers', () async {
    final getIt = GetIt.instance;

    bool isShadowed = false;
    Object? shadowingObject;

    getIt.registerSingleton<TestClassShadowChangHandler>(
      TestClassShadowChangHandler(
        (shadowState, shadow) {
          isShadowed = shadowState;
          shadowingObject = shadow;
        },
        'Basescope',
      ),
    );

    getIt.pushNewScope();

    final testClassShadowChangHandlerInstance = TestClassShadowChangHandler(
      (shadowState, shadow) {},
      'Scope 2',
    );
    getIt.registerSingleton<TestClassShadowChangHandler>(
      testClassShadowChangHandlerInstance,
    );

    expect(isShadowed, true);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
    shadowingObject = null;

    await getIt.popScope();

    expect(isShadowed, false);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
  });
  test(
    'register lazySingleton in two scopes with ShadowChangeHandlers and scopeChangedHandler',
    () async {
      final getIt = GetIt.instance;

      int scopeChanged = 0;
      bool isShadowed = false;
      Object? shadowingObject;

      getIt.onScopeChanged = (pushed) => scopeChanged++;

      getIt.registerLazySingleton<TestBaseClass>(
        () => TestClassShadowChangHandler(
          (shadowState, shadow) {
            isShadowed = shadowState;
            shadowingObject = shadow;
          },
          'Basescope',
        ),
      );

      getIt.pushNewScope();

      var testClassShadowChangHandlerInstance = TestClassShadowChangHandler(
        (shadowState, shadow) {},
        'Scope 2',
      );
      getIt.registerSingleton<TestBaseClass>(
        testClassShadowChangHandlerInstance,
      );

      /// As we haven't used the singleton in the lower scope
      /// it never created an instance that could be shadowed
      expect(isShadowed, false);
      expect(shadowingObject, null);
      await getIt.popScope();

      final lazyInstance = getIt<TestBaseClass>();

      getIt.pushNewScope();
      testClassShadowChangHandlerInstance = TestClassShadowChangHandler(
        (shadowState, shadow) {},
        'Scope 2',
      );

      getIt.registerSingleton<TestBaseClass>(
        testClassShadowChangHandlerInstance,
      );

      expect(isShadowed, true);
      expect(shadowingObject, testClassShadowChangHandlerInstance);
      shadowingObject = null;

      await getIt.popScope();

      expect(isShadowed, false);
      expect(shadowingObject, testClassShadowChangHandlerInstance);
      expect(scopeChanged, 4);
    },
  );

  test(
    'register AsyncSingleton in two scopes with ShadowChangeHandlers',
    () async {
      final getIt = GetIt.instance;

      bool isShadowed = false;
      Object? shadowingObject;

      getIt.registerSingleton<TestBaseClass>(
        TestClassShadowChangHandler(
          (shadowState, shadow) {
            isShadowed = shadowState;
            shadowingObject = shadow;
          },
          'Basescope',
        ),
      );

      getIt.pushNewScope();

      TestBaseClass? shadowingInstance;
      getIt.registerSingletonAsync<TestBaseClass>(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        final newInstance = TestClassShadowChangHandler(
          (shadowState, shadow) {},
          '2, Scope',
        );
        shadowingInstance = newInstance;
        return newInstance;
      });

      /// The instance is not created yet because the async init function hasn't completed
      expect(isShadowed, false);
      expect(shadowingObject, null);

      /// wait for the singleton so be created

      final asyncInstance = await getIt.getAsync<TestBaseClass>();

      expect(isShadowed, true);
      expect(shadowingObject, shadowingInstance);
      shadowingObject = null;

      await getIt.popScope();

      expect(isShadowed, false);
      expect(shadowingObject, shadowingInstance);
    },
  );

  test(
    'register SingletonWidthDependies in two scopes with ShadowChangeHandlers',
    () async {
      final getIt = GetIt.instance;

      bool isShadowed = false;
      Object? shadowingObject;

      getIt.registerSingletonAsync<TestClass>(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        final newInstance = TestClass('Basescope');
        return newInstance;
      });
      getIt.registerSingleton<TestBaseClass>(
        TestClassShadowChangHandler(
          (shadowState, shadow) {
            isShadowed = shadowState;
            shadowingObject = shadow;
          },
          '2, Scope',
        ),
      );

      getIt.pushNewScope();

      Object? shadowingInstance;
      getIt.registerSingletonWithDependencies<TestBaseClass>(
        () {
          final newInstance = TestClassShadowChangHandler(
            (shadowState, shadow) {},
            '2, Scope',
          );
          shadowingInstance = newInstance;
          return newInstance;
        },
        dependsOn: [TestClass],
      );

      /// The instance is not created yet because the async init function hasn't completed
      expect(isShadowed, false);
      expect(shadowingObject, null);

      await getIt.allReady();

      expect(isShadowed, true);
      expect(shadowingObject, shadowingInstance);
      shadowingObject = null;

      await getIt.popScope();

      expect(isShadowed, false);
      expect(shadowingObject, shadowingInstance);
    },
  );

  test('popscope', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));

    getIt.pushNewScope();

    getIt.registerSingleton<TestClass>(TestClass('2. scope'));
    getIt.registerSingleton<TestClass2>(TestClass2('2. scope'));

    final instanceTestClassScope2 = getIt.get<TestClass>();

    expect(instanceTestClassScope2 is TestClass, true);
    expect(instanceTestClassScope2.id, '2. scope');

    final instanceTestClass2Scope2 = getIt.get<TestClass2>();

    expect(instanceTestClass2Scope2 is TestClass2, true);
    expect(instanceTestClass2Scope2.id, '2. scope');

    await getIt.popScope();

    final instanceTestClassScope1 = getIt.get<TestClass>();

    expect(instanceTestClassScope1.id, 'Basescope');
    expect(() => getIt.get<TestClass2>(), throwsStateError);
  });

  test('popScopesTill inclusive=true', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));

    getIt.pushNewScope(scopeName: 'Level1');
    getIt.registerSingleton<TestClass>(TestClass('1. scope'));

    getIt.pushNewScope(scopeName: 'Level2');
    getIt.registerSingleton<TestClass>(TestClass('2. scope'));

    getIt.pushNewScope(scopeName: 'Level3');
    getIt.registerSingleton<TestClass>(TestClass('3. scope'));
    expect(getIt.get<TestClass>().id, '3. scope');

    await getIt.popScopesTill('Level2');

    expect(getIt.get<TestClass>().id, '1. scope');
    expect(() => getIt.get<TestClass2>(), throwsStateError);
  });

  test('popScopesTill inclusive=false', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));

    getIt.pushNewScope(scopeName: 'Level1');
    getIt.registerSingleton<TestClass>(TestClass('1. scope'));

    getIt.pushNewScope(scopeName: 'Level2');
    getIt.registerSingleton<TestClass>(TestClass('2. scope'));

    getIt.pushNewScope(scopeName: 'Level3');
    getIt.registerSingleton<TestClass>(TestClass('3. scope'));
    expect(getIt.get<TestClass>().id, '3. scope');

    await getIt.popScopesTill('Level2', inclusive: false);

    expect(getIt.get<TestClass>().id, '2. scope');
    expect(() => getIt.get<TestClass2>(), throwsStateError);
  });

  test('popScopesTill invalid scope', () async {
    final getIt = GetIt.instance;

    getIt.pushNewScope(scopeName: 'Level1');
    getIt.pushNewScope(scopeName: 'Level2');
    getIt.pushNewScope(scopeName: 'Level3');

    expect(getIt.hasScope('Level1'), isTrue);
    expect(getIt.hasScope('Level2'), isTrue);
    expect(getIt.hasScope('Level3'), isTrue);

    await getIt.popScopesTill('Level4');

    expect(getIt.hasScope('Level1'), isTrue);
    expect(getIt.hasScope('Level2'), isTrue);
    expect(getIt.hasScope('Level3'), isTrue);
  });

  test('popScopesTill inclusive=false top scope', () async {
    final getIt = GetIt.instance;

    getIt.pushNewScope(scopeName: 'Level1');
    getIt.pushNewScope(scopeName: 'Level2');
    getIt.pushNewScope(scopeName: 'Level3');

    expect(getIt.hasScope('Level1'), isTrue);
    expect(getIt.hasScope('Level2'), isTrue);
    expect(getIt.hasScope('Level3'), isTrue);

    await getIt.popScopesTill('Level3', inclusive: false);

    expect(getIt.hasScope('Level1'), isTrue);
    expect(getIt.hasScope('Level2'), isTrue);
    expect(getIt.hasScope('Level3'), isTrue);
  });

  test('popscope with destructors', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(
      TestClass('Basescope'),
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(
      dispose: () {
        return disposeCounter++;
      },
    );

    getIt.registerSingleton<TestClass>(
      TestClass('2. scope'),
      dispose: (x) => x.dispose(),
    );
    getIt.registerSingleton<TestClass2>(
      TestClass2('2. scope'),
      dispose: (x) => x.dispose(),
    );

    await getIt.popScope();

    expect(disposeCounter, 3);
  });

  test('popscope with destructors', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(
      TestClass('Basescope'),
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(
      dispose: () {
        return disposeCounter++;
      },
    );

    getIt.registerSingleton<TestClass>(
      TestClass('2. scope'),
      dispose: (x) => x.dispose(),
    );
    getIt.registerSingleton<TestClass2>(
      TestClass2('2. scope'),
      dispose: (x) => x.dispose(),
    );

    await getIt.popScope();

    expect(disposeCounter, 3);
  });

  test('popscope throws if already on the base scope', () async {
    final getIt = GetIt.instance;

    expect(() => getIt.popScope(), throwsStateError);
  });

  test('dropScope', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));

    getIt.pushNewScope(scopeName: 'scope2');
    getIt.registerSingleton<TestClass>(TestClass('2. scope'));
    getIt.registerSingleton<TestClass2>(TestClass2('2. scope'));

    getIt.pushNewScope();
    getIt.registerSingleton<TestClass3>(TestClass3());

    final instanceTestClassScope2 = getIt.get<TestClass>();

    expect(instanceTestClassScope2 is TestClass, true);
    expect(instanceTestClassScope2.id, '2. scope');

    await getIt.dropScope('scope2');

    final instanceTestClassScope1 = getIt.get<TestClass>();

    expect(instanceTestClassScope1.id, 'Basescope');
    expect(() => getIt.get<TestClass2>(), throwsStateError);

    final instanceTestClass3Scope3 = getIt.get<TestClass3>();
    expect(instanceTestClass3Scope3 is TestClass3, true);
  });

  test('dropScope throws if scope with name not found', () async {
    final getIt = GetIt.instance;

    getIt.pushNewScope(scopeName: 'scope2');
    await expectLater(
      () => getIt.dropScope('scope'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('isFinal', () async {
    final getIt = GetIt.instance;

    getIt.pushNewScope(
      scopeName: 'sealedScope',
      isFinal: true,
      init: (getIt) {
        getIt.registerSingleton(TestClass(), dispose: (x) => x.dispose());
      },
    );

    getIt.registerSingleton(TestClass2()); // gets into baseScope

    await getIt.popScope(); // it shouldn't affect the TestClass2

    expect(() => getIt.get<TestClass>(), throwsStateError);
    expect(getIt.get<TestClass2>(), isNotNull);
  });

  test('resetScope', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope0',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope1',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope2',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );

    await getIt.resetScope();

    expect(getIt<TestClass>(instanceName: 'scope0'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope1'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope2'), isNotNull);
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope3'),
      throwsStateError,
    );

    expect(disposeCounter, 2);

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });

  test('resetScope no dispose', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope0',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope1',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope2',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );

    await getIt.resetScope(dispose: false);

    expect(getIt<TestClass>(instanceName: 'scope0'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope1'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope2'), isNotNull);
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope3'),
      throwsStateError,
    );

    expect(disposeCounter, 0);

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });
  test('full reset', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope0',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope1',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope2',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );

    await getIt.reset();

    expect(
      () => getIt.get<TestClass>(instanceName: 'scope0'),
      throwsStateError,
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope1'),
      throwsStateError,
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope2'),
      throwsStateError,
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope3'),
      throwsStateError,
    );

    expect(disposeCounter, 7);

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });

  test('has registered scope test', () async {
    final getIt = GetIt.instance;
    getIt.pushNewScope(scopeName: 'scope1');
    getIt.pushNewScope(scopeName: 'scope2');
    getIt.pushNewScope(scopeName: 'scope3');

    expect(getIt.hasScope('scope2'), isTrue);
    expect(getIt.hasScope('scope4'), isFalse);

    await getIt.dropScope('scope2');

    expect(getIt.hasScope('scope2'), isFalse);
  });

  test('full reset no dispose', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope0',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope1',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope2',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );

    await getIt.reset(dispose: false);

    expect(
      () => getIt.get<TestClass>(instanceName: 'scope0'),
      throwsStateError,
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope1'),
      throwsStateError,
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope2'),
      throwsStateError,
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope3'),
      throwsStateError,
    );

    expect(disposeCounter, 0);

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });

  group('should remove scope with error during push', () {
    test('pushNewScope', () {
      final getIt = GetIt.instance;

      expect(
        () => getIt.pushNewScope(
          scopeName: 'scope1',
          init: (getIt) {
            getIt.registerSingleton(TestClass());
            throw Exception('Error during init');
          },
        ),
        throwsException,
      );

      // The scope should not be on the stack and the registered instance
      // should be removed.
      expect(getIt.hasScope('scope1'), isFalse);
      expect(getIt.isRegistered<TestClass>(), isFalse);

      // It should be possible to push a new scope.
      getIt.pushNewScope(scopeName: 'scope2');

      expect(getIt.hasScope('scope2'), isTrue);
    });

    test('pushNewScopeAsync', () async {
      final getIt = GetIt.instance;

      await expectLater(
        () => getIt.pushNewScopeAsync(
          scopeName: 'scope1',
          init: (getIt) async {
            getIt.registerSingleton(TestClass());
            throw Exception('Error during init');
          },
        ),
        throwsException,
      );

      // The scope should not be on the stack and the registered instance
      // should be removed.
      expect(getIt.hasScope('scope1'), isFalse);
      expect(getIt.isRegistered<TestClass>(), isFalse);

      // It should be possible to push a new scope.
      await getIt.pushNewScopeAsync(scopeName: 'scope2');

      expect(getIt.hasScope('scope2'), isTrue);
    });
  });

  group('resetLazySingletons', () {
    setUp(() async {
      await GetIt.I.reset();
      constructorCounter = 0;
      disposeCounter = 0;
    });

    test('resets all lazy singletons in current scope', () async {
      // Register lazy singletons in base scope
      GetIt.I.registerLazySingleton<TestClass>(() => TestClass('base'));
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('base2'),
        instanceName: 'instance2',
      );

      // Access them to create instances
      final instance1 = GetIt.I<TestClass>();
      final instance2 = GetIt.I<TestClass>(instanceName: 'instance2');
      expect(constructorCounter, 2);

      // Reset all lazy singletons in scope
      await GetIt.I.resetLazySingletons();

      // Next access should create new instances
      final newInstance1 = GetIt.I<TestClass>();
      final newInstance2 = GetIt.I<TestClass>(instanceName: 'instance2');
      expect(constructorCounter, 4);
      expect(identical(instance1, newInstance1), isFalse);
      expect(identical(instance2, newInstance2), isFalse);
    });

    test('only resets lazy singletons in current scope, not parent scopes',
        () async {
      // Register lazy singleton in base scope
      GetIt.I.registerLazySingleton<TestClass>(() => TestClass('base'));
      final baseInstance = GetIt.I<TestClass>();
      expect(constructorCounter, 1);

      // Push new scope and register another lazy singleton
      GetIt.I.pushNewScope();
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('scope'),
        instanceName: 'scope',
      );
      final scopeInstance = GetIt.I<TestClass>(instanceName: 'scope');
      expect(constructorCounter, 2);

      // Reset lazy singletons in current (inner) scope
      await GetIt.I.resetLazySingletons();

      // Base scope instance should NOT be reset
      final sameBaseInstance = GetIt.I<TestClass>();
      expect(identical(baseInstance, sameBaseInstance), isTrue);

      // Scope instance should be reset
      final newScopeInstance = GetIt.I<TestClass>(instanceName: 'scope');
      expect(constructorCounter, 3);
      expect(identical(scopeInstance, newScopeInstance), isFalse);
    });

    test('does not reset lazy singletons that have not been instantiated',
        () async {
      // Register lazy singletons but don't access them
      GetIt.I.registerLazySingleton<TestClass>(() => TestClass('lazy1'));
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('lazy2'),
        instanceName: 'lazy2',
      );

      expect(constructorCounter, 0);

      // Reset - should not create any instances
      await GetIt.I.resetLazySingletons();

      expect(constructorCounter, 0);

      // First access after reset should still work
      final instance1 = GetIt.I<TestClass>();
      final instance2 = GetIt.I<TestClass>(instanceName: 'lazy2');
      expect(constructorCounter, 2);
    });

    test('does not reset regular singletons', () async {
      // Register regular singleton
      final regularSingleton = TestClass('regular');
      GetIt.I.registerSingleton<TestClass>(regularSingleton);

      // Register lazy singleton
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('lazy'),
        instanceName: 'lazy',
      );
      final lazyInstance = GetIt.I<TestClass>(instanceName: 'lazy');

      final constructorCountBeforeReset = constructorCounter;

      // Reset lazy singletons
      await GetIt.I.resetLazySingletons();

      // Regular singleton should be unchanged
      final sameRegularSingleton = GetIt.I<TestClass>();
      expect(identical(regularSingleton, sameRegularSingleton), isTrue);

      // Lazy singleton should be reset
      final newLazyInstance = GetIt.I<TestClass>(instanceName: 'lazy');
      expect(identical(lazyInstance, newLazyInstance), isFalse);
      expect(constructorCounter, constructorCountBeforeReset + 1);
    });

    test('does not reset factories', () async {
      // Register factory
      GetIt.I.registerFactory<TestClass>(() => TestClass('factory'));

      // Call factory
      final factoryInstance1 = GetIt.I<TestClass>();
      final factoryInstance2 = GetIt.I<TestClass>();
      expect(constructorCounter, 2);

      // Reset lazy singletons (should not affect factories)
      await GetIt.I.resetLazySingletons();

      // Factory should still create new instances each time
      final factoryInstance3 = GetIt.I<TestClass>();
      expect(constructorCounter, 3);
    });

    test('calls dispose functions when dispose=true', () async {
      // Register lazy singleton with dispose function
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('lazy'),
        dispose: (instance) => instance.dispose(),
      );

      // Access to create instance
      final instance = GetIt.I<TestClass>();
      expect(disposeCounter, 0);

      // Reset with dispose=true (default)
      await GetIt.I.resetLazySingletons();

      expect(disposeCounter, 1);
    });

    test('does not call dispose functions when dispose=false', () async {
      // Register lazy singleton with dispose function
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('lazy'),
        dispose: (instance) => instance.dispose(),
      );

      // Access to create instance
      final instance = GetIt.I<TestClass>();
      expect(disposeCounter, 0);

      // Reset with dispose=false
      await GetIt.I.resetLazySingletons(dispose: false);

      expect(disposeCounter, 0);

      // But instance should still be reset
      final newInstance = GetIt.I<TestClass>();
      expect(identical(instance, newInstance), isFalse);
    });

    test('works with named instances', () async {
      // Register multiple named lazy singletons
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('unnamed'),
      );
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('named1'),
        instanceName: 'name1',
      );
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('named2'),
        instanceName: 'name2',
      );

      // Access all to create instances
      final unnamed = GetIt.I<TestClass>();
      final named1 = GetIt.I<TestClass>(instanceName: 'name1');
      final named2 = GetIt.I<TestClass>(instanceName: 'name2');
      expect(constructorCounter, 3);

      // Reset all lazy singletons
      await GetIt.I.resetLazySingletons();

      // All should be reset
      final newUnnamed = GetIt.I<TestClass>();
      final newNamed1 = GetIt.I<TestClass>(instanceName: 'name1');
      final newNamed2 = GetIt.I<TestClass>(instanceName: 'name2');
      expect(constructorCounter, 6);
      expect(identical(unnamed, newUnnamed), isFalse);
      expect(identical(named1, newNamed1), isFalse);
      expect(identical(named2, newNamed2), isFalse);
    });

    test('works with async dispose functions', () async {
      // Register lazy singleton with async dispose
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('lazy'),
        dispose: (instance) async {
          await Future.delayed(const Duration(milliseconds: 10));
          instance.dispose();
        },
      );

      // Access to create instance
      final instance = GetIt.I<TestClass>();
      expect(disposeCounter, 0);

      // Reset - should await async dispose
      await GetIt.I.resetLazySingletons();

      expect(disposeCounter, 1);
    });

    test('works when scope has mix of registered types', () async {
      // Register various types
      GetIt.I.registerSingleton<TestClass>(TestClass('singleton'));
      GetIt.I.registerFactory<TestClass>(
        () => TestClass('factory'),
        instanceName: 'factory',
      );
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('lazy'),
        instanceName: 'lazy',
      );

      // Access lazy singleton
      final lazyInstance = GetIt.I<TestClass>(instanceName: 'lazy');
      final constructorCountBefore = constructorCounter;

      // Reset lazy singletons
      await GetIt.I.resetLazySingletons();

      // Only lazy singleton should be reset
      final newLazyInstance = GetIt.I<TestClass>(instanceName: 'lazy');
      expect(identical(lazyInstance, newLazyInstance), isFalse);
      expect(constructorCounter, constructorCountBefore + 1);
    });

    test('resets lazy singletons in all scopes with inAllScopes=true',
        () async {
      // Register lazy singletons in base scope
      GetIt.I.registerLazySingleton<TestClass>(() => TestClass('base'));
      final baseInstance = GetIt.I<TestClass>();

      // Push scope and register another lazy singleton
      GetIt.I.pushNewScope(scopeName: 'scope1');
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('scope1'),
        instanceName: 'scope1',
      );
      final scope1Instance = GetIt.I<TestClass>(instanceName: 'scope1');

      // Push another scope and register lazy singleton
      GetIt.I.pushNewScope(scopeName: 'scope2');
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('scope2'),
        instanceName: 'scope2',
      );
      final scope2Instance = GetIt.I<TestClass>(instanceName: 'scope2');

      expect(constructorCounter, 3);

      // Reset all lazy singletons in all scopes
      await GetIt.I.resetLazySingletons(inAllScopes: true);

      // All instances should be reset
      final newBaseInstance = GetIt.I<TestClass>();
      final newScope1Instance = GetIt.I<TestClass>(instanceName: 'scope1');
      final newScope2Instance = GetIt.I<TestClass>(instanceName: 'scope2');

      expect(constructorCounter, 6);
      expect(identical(baseInstance, newBaseInstance), isFalse);
      expect(identical(scope1Instance, newScope1Instance), isFalse);
      expect(identical(scope2Instance, newScope2Instance), isFalse);
    });

    test('resets lazy singletons only in named scope with onlyInScope',
        () async {
      // Register lazy singletons in base scope
      GetIt.I.registerLazySingleton<TestClass>(() => TestClass('base'));
      final baseInstance = GetIt.I<TestClass>();

      // Push scope and register another lazy singleton
      GetIt.I.pushNewScope(scopeName: 'targetScope');
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('target'),
        instanceName: 'target',
      );
      final targetInstance = GetIt.I<TestClass>(instanceName: 'target');

      // Push another scope and register lazy singleton
      GetIt.I.pushNewScope(scopeName: 'otherScope');
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('other'),
        instanceName: 'other',
      );
      final otherInstance = GetIt.I<TestClass>(instanceName: 'other');

      expect(constructorCounter, 3);

      // Reset only lazy singletons in targetScope
      await GetIt.I.resetLazySingletons(onlyInScope: 'targetScope');

      // Base and other scope instances should NOT be reset
      final sameBaseInstance = GetIt.I<TestClass>();
      final sameOtherInstance = GetIt.I<TestClass>(instanceName: 'other');
      expect(identical(baseInstance, sameBaseInstance), isTrue);
      expect(identical(otherInstance, sameOtherInstance), isTrue);

      // Target scope instance should be reset
      final newTargetInstance = GetIt.I<TestClass>(instanceName: 'target');
      expect(constructorCounter, 4);
      expect(identical(targetInstance, newTargetInstance), isFalse);
    });

    test('onlyInScope takes precedence over inAllScopes', () async {
      // Register lazy singletons in base scope
      GetIt.I.registerLazySingleton<TestClass>(() => TestClass('base'));
      final baseInstance = GetIt.I<TestClass>();

      // Push scope and register another lazy singleton
      GetIt.I.pushNewScope(scopeName: 'targetScope');
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass('target'),
        instanceName: 'target',
      );
      final targetInstance = GetIt.I<TestClass>(instanceName: 'target');

      expect(constructorCounter, 2);

      // Reset with both parameters - onlyInScope should take precedence
      await GetIt.I.resetLazySingletons(
        inAllScopes: true,
        onlyInScope: 'targetScope',
      );

      // Base instance should NOT be reset (only targetScope processed)
      final sameBaseInstance = GetIt.I<TestClass>();
      expect(identical(baseInstance, sameBaseInstance), isTrue);

      // Target scope instance should be reset
      final newTargetInstance = GetIt.I<TestClass>(instanceName: 'target');
      expect(constructorCounter, 3);
      expect(identical(targetInstance, newTargetInstance), isFalse);
    });

    test('throws StateError when onlyInScope scope does not exist', () async {
      GetIt.I.registerLazySingleton<TestClass>(() => TestClass('base'));
      GetIt.I<TestClass>(); // Access to create instance

      expect(
        () => GetIt.I.resetLazySingletons(onlyInScope: 'nonexistent'),
        throwsStateError,
      );
    });
  });
}
