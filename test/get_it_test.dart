// ignore_for_file: unnecessary_type_check, avoid_redundant_argument_values, avoid_classes_with_only_static_members
import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

class TestBaseClassGeneric<T> {}

class TestClassGeneric<T> implements TestBaseClassGeneric<T> {}

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  TestClass() {
    constructorCounter++;
  }
  void dispose() {
    disposeCounter++;
  }
}

class TestClassDisposable extends TestBaseClass with Disposable {
  TestClassDisposable() {
    constructorCounter++;
  }
  void dispose() {
    disposeCounter++;
  }

  @override
  void onDispose() {
    dispose();
  }
}

class TestClass2 {}

class TestClassParam extends TestBaseClass {
  final String? param1;
  final int? param2;

  TestClassParam({this.param1, this.param2}) {
    constructorCounter++;
  }
}

class TestClassDisposableWithDependency with Disposable {
  final TestClassDisposable testClass;
  TestClassDisposableWithDependency(this.testClass) {
    constructorCounter *=
        3; // with this multiplication we can detect the order of the constructor.
  }

  void dispose() {
    disposeCounter *=
        3; // with this multiplication we can detect the order of disposal.
  }

  @override
  void onDispose() {
    dispose();
  }
}

void main() {
  setUp(() async {
    // make sure the instance is cleared before each test
    await GetIt.I.reset();
    constructorCounter = 0;
    disposeCounter = 0;
    errorCounter = 0;
  });

  test('register factory', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactory<TestBaseClass>(() => TestClass());

    //final instance1 = getIt.get<TestBaseClass>();

    final TestBaseClass instance1 = getIt<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestBaseClass>();

    expect(getIt.isRegistered<TestBaseClass>(), true);
    expect(getIt.isRegistered<TestClass2>(), false);
    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);
  });

  test('register factory with one Param', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String, void>(
      (s, _) => TestClassParam(param1: s),
    );

    //final instance1 = getIt.get<TestBaseClass>();

    final instance1 = getIt<TestClassParam>(param1: 'abc');
    final instance2 = getIt<TestClassParam>(param1: '123');

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, '123');
  });

  test('register factory with one nullable Param', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String?, void>(
      (s, _) => TestClassParam(param1: s),
    );

    final instance1 = getIt<TestClassParam>(param1: 'abc');
    final instance2 = getIt<TestClassParam>(param1: null);

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, null);
  });

  test('register factory with two Params', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String, int>(
      (s, i) => TestClassParam(param1: s, param2: i),
    );

    //final instance1 = getIt.get<TestBaseClass>();

    final instance1 = getIt<TestClassParam>(param1: 'abc', param2: 3);
    final instance2 = getIt<TestClassParam>(param1: '123', param2: 5);

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1.param2, 3);
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, '123');
    expect(instance2.param2, 5);
  });

  test('register factory with two nullable Params', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String?, int?>(
      (s, i) => TestClassParam(param1: s, param2: i),
    );

    final instance1 = getIt<TestClassParam>(param1: 'abc', param2: 3);
    final instance2 = getIt<TestClassParam>();

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1.param2, 3);
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, null);
    expect(instance2.param2, null);
  });

  test('register factory with Params with wrong type', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String, int>(
      (s, i) => TestClassParam(param1: s, param2: i),
    );

    expect(
      () => getIt.get<TestClassParam>(param1: 'abc', param2: '3'),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains("Cannot use parameter value of type 'String' as type 'int'"),
        ),
      ),
    );
  });

  test(
    'register factory with Params with non-nullable type but not pass it',
    () {
      final getIt = GetIt.instance;

      constructorCounter = 0;
      getIt.registerFactoryParam<TestClassParam, String, int>(
        (s, i) => TestClassParam(param1: s, param2: i),
      );

      expect(
        () => getIt.get<TestClassParam>(param2: '3'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Param1 is required (non-nullable) but null was passed'),
          ),
        ),
      );
    },
  );

  test('register factory with access as singleton', () {
    constructorCounter = 0;
    GetIt.instance.registerFactory<TestBaseClass>(() => TestClass());

    final TestBaseClass instance1 = GetIt.I<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = GetIt.I.get<TestBaseClass>();

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('register cached factory', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerCachedFactory<TestBaseClass>(() => TestClass());
    final TestBaseClass instance1 = getIt<TestBaseClass>();
    expect(instance1 is TestClass, true);
    final instance2 = getIt.get<TestBaseClass>();
    expect(getIt.isRegistered<TestBaseClass>(), true);
    expect(instance1, instance2);
    expect(constructorCounter, 1);
  });

  test('register cached factory with one param ', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerCachedFactoryParam<TestClassParam, String, void>(
      (s, _) => TestClassParam(param1: s),
    );
    final instance1 = getIt<TestClassParam>(param1: 'abc');
    final instance2 = getIt<TestClassParam>(param1: 'abc');
    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1, instance2);
    expect(constructorCounter, 1);
  });

  test('register cached factory with different params', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerCachedFactoryParam<TestClassParam, String, void>(
      (s, _) => TestClassParam(param1: s),
    );
    final instance1 = getIt<TestClassParam>(param1: 'abc');
    final instance2 = getIt<TestClassParam>(param1: '123');
    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance2.param1, '123');
    expect(instance2 is TestClassParam, true);
    expect(instance1, isNot(instance2));
    expect(constructorCounter, 2);
  });

  test('register cached factory with two equal params', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerCachedFactoryParam<TestClassParam, String, int>(
      (f, s) => TestClassParam(param1: f, param2: s),
    );
    final instance1 = getIt<TestClassParam>(param1: 'abc', param2: 1);
    final instance2 = getIt<TestClassParam>(param1: 'abc', param2: 1);
    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1, instance2);
    expect(constructorCounter, 1);
  });

  test('register cached factory with one different param out of two', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerCachedFactoryParam<TestClassParam, String, int>(
      (f, s) => TestClassParam(param1: f, param2: s),
    );
    final instance1 = getIt<TestClassParam>(param1: 'abc', param2: 1);
    final instance2 = getIt<TestClassParam>(param1: 'abc', param2: 2);
    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1.param2, 1);
    expect(instance2.param1, 'abc');
    expect(instance2.param2, 2);
    expect(instance2 is TestClassParam, true);
    expect(instance1, isNot(instance2));
    expect(constructorCounter, 2);
  });

  test('register constant', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestBaseClass>(TestClass());

    final instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I.reset();
  });

  test('register constant with maybeGet', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestBaseClass>(TestClass());

    final instance1 = getIt.maybeGet<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.maybeGet<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I.reset();
  });

  test('register constant with maybeGet not found', () async {
    final getIt = GetIt.instance;
    final instance1 = getIt.maybeGet<TestBaseClass>();
    expect(instance1, isNull);
  });

  test('reset', () async {
    final getIt = GetIt.instance;
    int destructorCounter = 0;

    getIt.registerSingleton<TestBaseClass>(TestClass());
    getIt.registerSingleton<TestBaseClass>(
      TestClass(),
      instanceName: 'instance2',
      dispose: (_) {
        destructorCounter++;
      },
    );

    await getIt.reset();
    expect(() => getIt.get<TestClass>(), throwsStateError);

    expect(destructorCounter, 1);
  });

  test('reset which Disposable Interface', () async {
    disposeCounter = 0;
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestBaseClass>(TestClassDisposable());

    await getIt.reset();
    expect(() => getIt.get<TestClass>(), throwsStateError);

    expect(disposeCounter, 1);
  });

  test('register lazySingleton', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(() => TestClass());

    expect(constructorCounter, 0);

    final instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    final instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I.reset();
  });
  test('register lazySingleton with weakReference', () async {
    final storage = <List<int>>[];

    void allocateMemory() {
      storage.add(List.generate(3000, (n) => n));
      if (storage.length > 1000) {
        storage.removeAt(0);
      }
    }

    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(
      () => TestClass(),
      useWeakReference: true,
    );

    expect(constructorCounter, 0);

    TestBaseClass? instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    TestBaseClass? instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.isReady<TestBaseClass>();
    instance1 = null;
    instance2 = null;
    for (var i = 0; i < 300; i++) {
      allocateMemory();
    }
    await Future.delayed(const Duration(milliseconds: 1000));
    storage.clear();
    await Future.delayed(const Duration(milliseconds: 10));
    // NativeRuntime.writeHeapSnapshotToFile('dump.heapsnapshot');
    getIt.get<TestBaseClass>();
    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('trying to access not registered type', () {
    final getIt = GetIt.instance;

    expect(() => getIt.get<int>(), throwsStateError);

    GetIt.I.reset();
  });

  test('register factory by Name', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactory(() => TestClass(), instanceName: 'FactoryByName');

    final TestClass instance1 = getIt<TestClass>(instanceName: 'FactoryByName');

    expect(instance1 is TestClass, true);

    // ignore: prefer_final_locals
    TestClass instance2 = getIt(instanceName: 'FactoryByName');

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('register constant by name', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'ConstantByName');

    final TestClass instance1 = getIt<TestClass>(
      instanceName: 'ConstantByName',
    );

    expect(instance1 is TestClass, true);

    final TestClass instance2 = getIt(instanceName: 'ConstantByName');

    expect(instance1, instance2);

    expect(constructorCounter, 1);
    GetIt.I.reset();
  });

  test('register lazySingleton by name', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(
      () => TestClass(),
      instanceName: 'LazyByName',
    );

    expect(constructorCounter, 0);

    final TestBaseClass instance1 = getIt<TestBaseClass>(
      instanceName: 'LazyByName',
    );

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    final TestBaseClass instance2 = getIt<TestBaseClass>(
      instanceName: 'LazyByName',
    );

    expect(instance1, instance2);

    expect(constructorCounter, 1);
    GetIt.I.reset();
  });

  test('register lazy singleton two instances of GetIt', () {
    final secondGetIt = GetIt.asNewInstance();

    constructorCounter = 0;
    GetIt.instance.registerLazySingleton<TestBaseClass>(() => TestClass());
    secondGetIt.registerLazySingleton<TestBaseClass>(() => TestClass());

    final TestBaseClass instance1 = GetIt.I<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = GetIt.I.get<TestBaseClass>();

    expect(instance1, instance2);
    expect(constructorCounter, 1);

    final instanceSecondGetIt = secondGetIt.get<TestBaseClass>();

    expect(instance1, isNot(instanceSecondGetIt));
    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('trying to access not registered type by name', () {
    final getIt = GetIt.instance;

    expect(
      () => getIt(instanceName: 'not there'),
      throwsA(isA<AssertionError>()),
    );
    GetIt.I.reset();
  });

  test('get all registered instances of the same type', () {
    final getIt = GetIt.instance;
    getIt.enableRegisteringMultipleInstancesOfOneType();
    constructorCounter = 0;

    getIt.registerLazySingleton<TestBaseClass>(() => TestClass());
    getIt.registerLazySingleton<TestBaseClass>(() => TestClass());

    expect(constructorCounter, 0);

    final Iterable<TestBaseClass> instances = getIt.getAll<TestBaseClass>();

    expect(instances.length, 2);
    expect(instances.first is TestClass, true);
    expect(instances.last is TestClass, true);
    expect(constructorCounter, 2);

    GetIt.I.reset();
    getIt.allowRegisterMultipleImplementationsOfoneType = false;
  });

  test(
    'reset lazy Singleton when the disposing function is a future',
    () async {
      final getIt = GetIt.instance;
      disposeCounter = 0;
      constructorCounter = 0;
      getIt.registerLazySingleton<TestBaseClass>(() => TestClass());

      expect(constructorCounter, 0);

      final instance1 = getIt.get<TestBaseClass>();

      expect(instance1 is TestClass, true);
      expect(constructorCounter, 1);

      final instance2 = getIt.get<TestBaseClass>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      await GetIt.I.resetLazySingleton<TestBaseClass>(
        disposingFunction: (testClass) async {
          if (testClass is TestClass) {
            await Future(() => testClass.dispose());
          }
        },
      );

      final instance3 = getIt.get<TestBaseClass>();

      expect(instance3 is TestClass, true);

      expect(instance1, isNot(instance3));

      expect(constructorCounter, 2);

      GetIt.I.reset();
    },
  );

  test(
    'reset lazy Singleton when the disposing function is not a future',
    () async {
      final getIt = GetIt.instance;

      disposeCounter = 0;
      constructorCounter = 0;
      getIt.registerLazySingleton<TestClass>(() => TestClass());

      expect(constructorCounter, 0);

      final instance1 = getIt.get<TestClass>();

      expect(instance1 is TestClass, true);
      expect(constructorCounter, 1);

      final instance2 = getIt.get<TestClass>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      GetIt.I.resetLazySingleton<TestClass>(
        disposingFunction: (x) => x.dispose(),
      );

      final instance3 = getIt.get<TestClass>();

      expect(disposeCounter, 1);

      expect(instance3 is TestClass, true);

      expect(instance1, isNot(instance3));

      expect(constructorCounter, 2);

      GetIt.I.reset();
    },
  );

  test(
    'reset lazy Singleton when the dispose of the register is a future',
    () async {
      final getIt = GetIt.instance;
      disposeCounter = 0;
      constructorCounter = 0;
      getIt.registerLazySingleton<TestBaseClass>(
        () => TestClass(),
        dispose: (testClass) async {
          if (testClass is TestClass) {
            await Future(() => testClass.dispose());
          }
        },
      );

      expect(constructorCounter, 0);

      final instance1 = getIt.get<TestBaseClass>();

      expect(instance1 is TestClass, true);
      expect(constructorCounter, 1);

      final instance2 = getIt.get<TestBaseClass>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      await GetIt.I.resetLazySingleton<TestBaseClass>();

      final instance3 = getIt.get<TestBaseClass>();

      expect(disposeCounter, 1);

      expect(instance3 is TestClass, true);

      expect(instance1, isNot(instance3));

      expect(constructorCounter, 2);

      GetIt.I.reset();
    },
  );

  test(
    'reset lazy Singleton when the dispose of the register is not a future',
    () async {
      final getIt = GetIt.instance;
      disposeCounter = 0;
      constructorCounter = 0;
      getIt.registerLazySingleton<TestBaseClass>(
        () => TestClass(),
        dispose: (testClass) {
          if (testClass is TestClass) {
            testClass.dispose();
          }
        },
      );

      expect(constructorCounter, 0);

      final instance1 = getIt.get<TestBaseClass>();

      expect(instance1 is TestClass, true);
      expect(constructorCounter, 1);

      final instance2 = getIt.get<TestBaseClass>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      GetIt.I.resetLazySingleton<TestBaseClass>();

      final instance3 = getIt.get<TestBaseClass>();

      expect(disposeCounter, 1);

      expect(instance3 is TestClass, true);

      expect(instance1, isNot(instance3));

      expect(constructorCounter, 2);

      GetIt.I.reset();
    },
  );

  test('reset LazySingleton by instance only', () {
    // Arrange
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestClass>(() => TestClass());
    final instance1 = getIt.get<TestClass>();

    // Act
    GetIt.I.resetLazySingleton(instance: instance1);

    // Assert
    final instance2 = getIt.get<TestClass>();
    expect(instance1, isNot(instance2));
    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test(
    'create a new instance even if dispose is not completed after resetLazySingleton',
    () {
      // Arrange
      final completer = Completer();
      GetIt.I.registerLazySingleton<TestClass>(
        () => TestClass(),
        dispose: (_) => completer.future,
      );
      final instance1 = GetIt.I.get<TestClass>();

      // Act
      GetIt.I.resetLazySingleton(instance: instance1);

      // Assert
      final instance2 = GetIt.I.get<TestClass>();
      expect(instance1, isNot(instance2));

      completer.complete();
    },
  );

  test(
    'unregister by instance when the dispose of the register is a future',
    () async {
      final getIt = GetIt.instance;
      disposeCounter = 0;
      constructorCounter = 0;

      getIt.registerSingleton<TestClass>(
        TestClass(),
        dispose: (dynamic testClass) async {
          if (testClass is TestClass) {
            await Future(() => testClass.dispose());
          }
        },
      );

      final instance1 = getIt.get<TestClass>();

      expect(instance1 is TestClass, true);

      final instance2 = getIt.get<TestClass>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      await getIt.unregister(instance: instance2);

      expect(disposeCounter, 1);

      expect(() => getIt.get<TestClass>(), throwsStateError);
    },
  );

  test(
    'unregister by instance when the dispose of the register is not a future',
    () async {
      final getIt = GetIt.instance;
      disposeCounter = 0;
      constructorCounter = 0;

      getIt.registerSingleton<TestClass>(
        TestClass(),
        dispose: (dynamic testClass) {
          if (testClass is TestClass) {
            testClass.dispose();
          }
        },
      );

      final instance1 = getIt.get<TestClass>();

      expect(instance1 is TestClass, true);

      final instance2 = getIt.get<TestClass>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      getIt.unregister(instance: instance2);

      expect(disposeCounter, 1);

      expect(() => getIt.get<TestClass>(), throwsStateError);
    },
  );

  test(
    'unregister by instance when the disposing function is not a future',
    () async {
      final getIt = GetIt.instance;
      disposeCounter = 0;
      constructorCounter = 0;

      getIt.registerSingleton<TestClass>(TestClass());

      final instance1 = getIt.get<TestClass>();

      expect(instance1 is TestClass, true);

      final instance2 = getIt.get<TestClass>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      getIt.unregister(
        instance: instance2,
        disposingFunction: (dynamic testClass) {
          if (testClass is TestClass) {
            testClass.dispose();
          }
        },
      );

      expect(disposeCounter, 1);

      expect(() => getIt.get<TestClass>(), throwsStateError);
    },
  );

  test(
    'unregister by instance when the disposing function is a future',
    () async {
      final getIt = GetIt.instance;
      disposeCounter = 0;
      constructorCounter = 0;

      getIt.registerSingleton<TestClass>(TestClass());

      final instance1 = getIt.get<TestClass>();

      expect(instance1 is TestClass, true);

      final instance2 = getIt.get<TestClass>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      await getIt.unregister(
        instance: instance2,
        disposingFunction: (dynamic testClass) async {
          if (testClass is TestClass) {
            await Future(() => testClass.dispose());
          }
        },
      );

      expect(disposeCounter, 1);

      expect(() => getIt.get<TestClass>(), throwsStateError);
    },
  );

  test('unregister by type', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister<TestClass>(
      disposingFunction: (testClass) {
        testClass.dispose();
      },
    );

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(), throwsStateError);
  });
  test('testing reference counting', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingletonIfAbsent<TestClass>(
      () => TestClass(),
      dispose: (param) => disposeCounter++,
    );

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.registerSingletonIfAbsent<TestClass>(
      () {
        assert(false, 'This should not be called');
        return TestClass();
      },
      dispose: (param) {
        assert(false, 'This should not be called');
      },
    );

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.releaseInstance(instance2);

    expect(getIt.isRegistered<TestClass>(), true);

    getIt.releaseInstance(instance2);

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(), throwsStateError);
  });
  test('testing reference counting - unregister', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingletonIfAbsent<TestClass>(
      () => TestClass(),
      dispose: (param) => disposeCounter++,
    );

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.registerSingletonIfAbsent<TestClass>(
      () {
        assert(false, 'This should not be called');
        return TestClass();
      },
      dispose: (param) {
        assert(false, 'This should not be called');
      },
    );

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.unregister<TestClass>();

    expect(getIt.isRegistered<TestClass>(), true);

    getIt.unregister<TestClass>();

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(), throwsStateError);
  });

  test('unregister by name', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');
    getIt.registerSingleton(TestClass(), instanceName: 'instanceName2');
    getIt.registerSingleton(TestClass2(), instanceName: 'instanceName');

    final TestClass instance1 = getIt.get(instanceName: 'instanceName');

    expect(instance1 is TestClass, true);

    await getIt.unregister<TestClass>(
      instanceName: 'instanceName',
      disposingFunction: (testClass) {
        testClass.dispose();
      },
    );

    expect(disposeCounter, 1);

    expect(
      () => getIt<TestClass>(instanceName: 'instanceName'),
      throwsStateError,
    );
    expect(getIt<TestClass>(instanceName: 'instanceName2'), isA<TestClass>());
    expect(getIt<TestClass2>(instanceName: 'instanceName'), isA<TestClass2>());
  });

  test('unregister by instance without disposing function', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister(instance: instance2);

    expect(disposeCounter, 0);

    expect(() => getIt.get<TestClass>(), throwsStateError);
  });

  test('unregister by type without disposing function', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister<TestClass>();

    expect(disposeCounter, 0);

    expect(() => getIt.get<TestClass>(), throwsStateError);
  });

  test(
    'unregister by type without disposing function function but with implementing Disposable',
    () async {
      final getIt = GetIt.instance;
      disposeCounter = 0;
      constructorCounter = 0;

      getIt.registerSingleton<TestClassDisposable>(TestClassDisposable());

      final instance1 = getIt.get<TestClassDisposable>();

      expect(instance1 is TestClassDisposable, true);

      final instance2 = getIt.get<TestClassDisposable>();

      expect(instance1, instance2);

      expect(constructorCounter, 1);

      await getIt.unregister<TestClassDisposable>();

      expect(disposeCounter, 1);

      expect(() => getIt.get<TestClassDisposable>(), throwsStateError);
    },
  );

  test('unregister by name without disposing ', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    final instance1 = getIt.get<TestClass>(instanceName: 'instanceName');

    expect(instance1 is TestClass, true);

    await getIt.unregister<TestClass>(instanceName: 'instanceName');

    expect(disposeCounter, 0);

    expect(
      () => getIt<TestClass>(instanceName: 'instanceName'),
      throwsStateError,
    );
  });
  test('change registration name with type and name', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    final TestClass instance1 = getIt.get(instanceName: 'instanceName');

    expect(instance1 is TestClass, true);

    getIt.changeTypeInstanceName<TestClass>(
      instanceName: 'instanceName',
      newInstanceName: 'instanceName2',
    );

    expect(disposeCounter, 0);

    expect(
      () => getIt<TestClass>(instanceName: 'instanceName'),
      throwsStateError,
    );
    expect(getIt<TestClass>(instanceName: 'instanceName2'), isA<TestClass>());
  });

  test('change registration name with type and name existing name', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');
    getIt.registerSingleton(TestClass(), instanceName: 'instanceNameExisting');

    final TestClass instance1 = getIt.get(instanceName: 'instanceName');

    expect(instance1 is TestClass, true);

    expect(
      () {
        getIt.changeTypeInstanceName<TestClass>(
          instanceName: 'instanceName',
          newInstanceName: 'instanceNameExisting',
        );
      },
      throwsStateError,
    );
  });

  test('change registration name of instance', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    final TestClass instance1 = getIt.get(instanceName: 'instanceName');

    expect(instance1 is TestClass, true);

    getIt.changeTypeInstanceName(
      instance: instance1,
      newInstanceName: 'instanceName2',
    );

    expect(disposeCounter, 0);

    expect(
      () => getIt<TestClass>(instanceName: 'instanceName'),
      throwsStateError,
    );
    expect(getIt<TestClass>(instanceName: 'instanceName2'), isA<TestClass>());
  });

  test(
    'can register a singleton with instanceName and retrieve it with generic parameters and instanceName',
    () {
      final getIt = GetIt.instance;

      getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

      final instance1 = getIt.get<TestClass>(instanceName: 'instanceName');

      expect(instance1 is TestClass, true);
    },
  );

  test(
    'can register a singleton with instanceName and retrieve it with Type parameter and instanceName',
    () {
      final getIt = GetIt.instance;

      getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

      final TestBaseClass instance1 = getIt.get(
        type: TestClass,
        instanceName: 'instanceName',
      );

      expect(instance1 is TestClass, true);
    },
  );

  test(
    'can register a singleton with instanceName and retrieve it with Type parameter and instanceName '
    'but with non matching receiving type',
    () {
      final getIt = GetIt.instance;

      getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

      expect(
        () {
          // ignore: unused_local_variable
          final TestClass2 instance1 = getIt.get(
            type: TestClass,
            instanceName: 'instanceName',
          );
        },
        throwsA(isA<AssertionError>()),
      );
    },
  );

  test('GenericType test', () {
    GetIt.I.registerSingleton<TestBaseClassGeneric<TestBaseClass>>(
      TestClassGeneric<TestBaseClass>(),
    );

    final instance1 = GetIt.I.get<TestBaseClassGeneric<TestBaseClass>>();

    expect(instance1 is TestClassGeneric<TestBaseClass>, true);
  });

  test('register LazySingleton with lambda and factory function', () {
    GetIt.I.registerLazySingleton(() => SingletonInjector.configuration());

    final Injector instance = GetIt.I<Injector>();

    expect(instance, isA<Injector>());
  });

  test('deregister in the same order of registering', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClassDisposable>(TestClassDisposable());

    final instance1 = getIt.get<TestClassDisposable>();

    expect(instance1 is TestClassDisposable, true);

    expect(constructorCounter, 1);

    getIt.registerSingleton<TestClassDisposableWithDependency>(
      TestClassDisposableWithDependency(getIt.get<TestClassDisposable>()),
    );

    final instance2 = getIt.get<TestClassDisposableWithDependency>();
    expect(constructorCounter, 3);
    expect(instance1 == instance2.testClass, true);

    await getIt.unregister<TestClassDisposable>();
    expect(disposeCounter, 1);

    final instance3 = getIt.get<TestClassDisposableWithDependency>();

    expect(instance2.testClass == instance3.testClass, true);

    await getIt.unregister<TestClassDisposableWithDependency>();
    expect(disposeCounter, 3);
  });

  test('deregister in reverse order of registering', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClassDisposable>(TestClassDisposable());

    final instance1 = getIt.get<TestClassDisposable>();

    expect(instance1 is TestClassDisposable, true);

    expect(constructorCounter, 1);

    getIt.registerSingleton<TestClassDisposableWithDependency>(
      TestClassDisposableWithDependency(getIt.get<TestClassDisposable>()),
    );

    final instance2 = getIt.get<TestClassDisposableWithDependency>();
    expect(constructorCounter, 3);
    expect(instance1 == instance2.testClass, true);

    await getIt.unregister<TestClassDisposableWithDependency>();
    expect(disposeCounter, 0);

    expect(() => getIt<TestClassDisposableWithDependency>(), throwsStateError);

    await getIt.unregister<TestClassDisposable>();
    expect(disposeCounter, 1);
  });

  test('deregister in reverse order of registering using reset', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClassDisposable>(TestClassDisposable());

    final instance1 = getIt.get<TestClassDisposable>();

    expect(instance1 is TestClassDisposable, true);

    expect(constructorCounter, 1);

    getIt.registerSingleton<TestClassDisposableWithDependency>(
      TestClassDisposableWithDependency(getIt.get<TestClassDisposable>()),
    );

    final instance2 = getIt.get<TestClassDisposableWithDependency>();
    expect(constructorCounter, 3);
    expect(instance1 == instance2.testClass, true);

    await getIt.reset();
    expect(
      disposeCounter,
      1,
      reason: "getIt.reset() did not dispose in reverse order",
    );
  });

  test('isRegistered queryable by type param', () {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass2>(TestClass2());

    final bool byGenerics = getIt.isRegistered<TestClass>();
    final bool byParam = getIt.isRegistered(type: TestClass);

    final bool byGenerics2 = getIt.isRegistered<TestClass2>();
    final bool byParam2 = getIt.isRegistered(type: TestClass2);

    expect(byParam, byGenerics);
    expect(byParam, false);
    expect(byParam2, byGenerics2);
    expect(byParam2, true);
  });
}

class SingletonInjector {
  static Injector configuration() {
    return Injector();
  }
}

class Injector {}
