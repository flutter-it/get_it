// ignore_for_file: unused_local_variable, unnecessary_type_check, unreachable_from_main, require_trailing_commas

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

abstract class TestBaseClass {}

class TestClassParam {
  final String? param1;
  final int? param2;

  TestClassParam({this.param1, this.param2});
}

class TestClass extends TestBaseClass {
  GetIt? getIt;
  bool initCompleted = false;
  int initMsDelay;

  /// if we do the initialisation from inside the constructor the init function has to signal GetIt
  /// that it has finished. For that we need to pass in the completer that we got from the factory call
  /// that we set up in the registration.
  TestClass({
    required bool internalCompletion,
    this.initMsDelay = 10,
    this.getIt,
  }) {
    constructorCounter++;
    if (internalCompletion) {
      assert(getIt != null);
      initWithSignal();
    }
  }

  /// This one signals after a delay
  Future initWithSignal() {
    return Future.delayed(Duration(milliseconds: initMsDelay)).then((_) {
      getIt!.signalReady(this);
      initCompleted = true;
    });
  }

  // We use this as dummy init that will return a future
  Future<TestClass> init() async {
    await Future.delayed(Duration(milliseconds: initMsDelay));
    initCompleted = true;
    return this;
  }

  Future<TestClass> initWithExeption() async {
    await Future.delayed(Duration(milliseconds: initMsDelay));
    throw StateError('Intentional');
  }

  void dispose() {
    disposeCounter++;
  }
}

class TestClassWillSignalReady extends TestClass implements WillSignalReady {
  TestClassWillSignalReady({required super.internalCompletion, super.getIt});
}

class TestClassWillSignalReady2 extends TestClass implements WillSignalReady {
  TestClassWillSignalReady2({required super.internalCompletion, super.getIt});
}

class TestClass2 extends TestClass {
  TestClass2({
    required super.internalCompletion,
    super.initMsDelay = 10,
    super.getIt,
  });
}

class TestClass3 extends TestClass {
  TestClass3({required super.internalCompletion, super.getIt});
}

class TestClass4 extends TestClass {
  TestClass4({required super.internalCompletion, super.getIt});
}

void main() {
  setUp(() async {
    // make sure the instance is cleared before each test
    await GetIt.I.reset();
  });

  /// This is the most basic sync functionality. Not sure if we should keep it.
  test('manual ready future test', () async {
    final getIt = GetIt.instance;

    getIt.registerFactory<TestClass>(
      () => TestClass(internalCompletion: false),
    );
    getIt.registerFactory<TestClass2>(
      () => TestClass2(internalCompletion: false),
    );
    getIt.registerFactory<TestClass3>(
      () => TestClass3(internalCompletion: false),
    );
    getIt.registerFactory(
      () => TestClass(internalCompletion: false),
      instanceName: 'TestNamesInstance',
    );

    expect(getIt.allReady(), completes);

    getIt.signalReady(null);

    // make sure to allow future to complete
    await Future.delayed(const Duration(seconds: 1));
  });

  test(
    'signalReady will throw if any async Singletons have not signaled completion',
    () async {
      final getIt = GetIt.instance;
      await getIt.reset();

      getIt.registerSingletonAsync<TestClass>(
        () => Future.delayed(
          const Duration(milliseconds: 1),
        ).then((_) => TestClass(internalCompletion: false, getIt: getIt)),
      );
      getIt.registerSingletonAsync<TestClass2>(
        () => Future.delayed(
          const Duration(milliseconds: 2),
        ).then((_) => TestClass2(internalCompletion: false, getIt: getIt)),
      );
      getIt.registerSingletonAsync<TestClass3>(
        () => Future.delayed(
          const Duration(milliseconds: 50),
        ).then((_) => TestClass3(internalCompletion: false, getIt: getIt)),
      );

      /// this here should signal call [signalReady()] but doesn't do it.
      getIt.registerSingletonAsync(
        () => Future.delayed(
          const Duration(milliseconds: 50),
        ).then((_) => TestClass(internalCompletion: false, getIt: getIt)),
        instanceName: 'TestNamesInstance',
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(getIt.isReadySync<TestClass>(), true);
      expect(getIt.isReadySync<TestClass3>(), false);
      expect(
        getIt.isReadySync<TestClass>(instanceName: 'TestNamesInstance'),
        false,
      );
      expect(getIt.allReadySync(), false);

      /// We call [signalReady] before the last has completed
      expect(() => getIt.signalReady(null), throwsStateError);
    },
  );

  test('get all registered instances of the same type', () async {
    final getIt = GetIt.instance;
    getIt.enableRegisteringMultipleInstancesOfOneType();
    constructorCounter = 0;

    getIt.registerLazySingleton<TestBaseClass>(
      () => TestClass2(internalCompletion: false, getIt: getIt),
    );
    getIt.registerLazySingletonAsync<TestBaseClass>(
      () async => TestClass3(internalCompletion: false, getIt: getIt),
    );

    expect(constructorCounter, 0);

    final Iterable<TestBaseClass> instances =
        await getIt.getAllAsync<TestBaseClass>();

    expect(instances.length, 2);
    expect(instances.first is TestClass, true);
    expect(instances.last is TestClass, true);
    expect(constructorCounter, 2);

    GetIt.I.reset();
    getIt.allowRegisterMultipleImplementationsOfoneType = false;
  });

  test(
      'signalReady will throw if any Singletons that has signalsReady==true '
      'have not signaled completion', () async {
    final getIt = GetIt.instance;

    getIt.registerSingletonAsync<TestClass>(
      () => Future.delayed(
        const Duration(milliseconds: 1),
      ).then((_) => TestClass(internalCompletion: true, getIt: getIt)),
      signalsReady: true,
    );
    getIt.registerSingletonAsync<TestClass2>(
      () => Future.delayed(
        const Duration(milliseconds: 2),
      ).then((_) => TestClass2(internalCompletion: false, getIt: getIt)),
    );
    getIt.registerSingleton<TestClass3>(
      TestClass3(internalCompletion: true, getIt: getIt),
      signalsReady: true,
    );

    /// this here should signal call [signalReady()] but doesn't do it.
    getIt.registerSingleton(
      TestClass(internalCompletion: false, getIt: getIt),
      instanceName: 'TestNamesInstance',
      signalsReady: true,
    );

    await Future.delayed(const Duration(milliseconds: 20));

    /// We call [signalReady] before the last has completed
    expect(() => getIt.signalReady(null), throwsStateError);
  });
  test('all ready ignoring pending async Singletons', () async {
    final getIt = GetIt.instance;

    getIt.registerSingletonAsync<TestClass>(
      () => Future.delayed(
        const Duration(milliseconds: 100),
      ).then((_) => TestClass(internalCompletion: false, getIt: getIt)),
    );
    getIt.registerSingletonAsync<TestClass2>(
      () => Future.delayed(
        const Duration(milliseconds: 100),
      ).then((_) => TestClass2(internalCompletion: false, getIt: getIt)),
    );
    getIt.registerSingleton<TestClass3>(
      TestClass3(internalCompletion: true, getIt: getIt),
      signalsReady: true,
    );

    await Future.delayed(const Duration(milliseconds: 15));

    expect(
      getIt.allReady(
        timeout: const Duration(milliseconds: 2),
        ignorePendingAsyncCreation: true,
      ),
      completes,
    );

    await Future.delayed(const Duration(milliseconds: 15));
  });

  test(
    'Normal Singletons, ready with internal signalling setting signalsReady parameter',
    () async {
      final getIt = GetIt.instance;
      errorCounter = 0;

      getIt.registerSingleton<TestClass>(
        TestClass(internalCompletion: true, getIt: getIt),
        signalsReady: true,
      );
      getIt.registerSingleton<TestClass2>(
        TestClass2(internalCompletion: true, getIt: getIt),
        signalsReady: true,
      );
      getIt.registerSingleton(
        TestClass2(internalCompletion: true, getIt: getIt),
        instanceName: 'Second Instance',
        signalsReady: true,
      );

      expect(getIt.isReadySync<TestClass>(), false);
      expect(getIt.isReadySync<TestClass2>(), false);
      expect(
        getIt.isReadySync<TestClass2>(instanceName: 'Second Instance'),
        false,
      );

      final timer = Stopwatch()..start();
      await getIt.allReady(timeout: const Duration(milliseconds: 20));
      final t = getIt<TestClass>();
      expect(timer.elapsedMilliseconds, greaterThan(5));
    },
  );

  test(
    'Normal Singletons,ready with internal signalling relying on implementing WillSignalReady interface',
    () async {
      final getIt = GetIt.instance;
      errorCounter = 0;

      getIt.registerSingleton<TestClassWillSignalReady>(
        TestClassWillSignalReady(internalCompletion: true, getIt: getIt),
      );
      getIt.registerSingleton<TestClassWillSignalReady2>(
        TestClassWillSignalReady2(internalCompletion: true, getIt: getIt),
      );
      getIt.registerSingleton(
        TestClass2(internalCompletion: true, getIt: getIt),
        instanceName: 'Second Instance',
        signalsReady: true,
      );

      expect(getIt.isReadySync<TestClassWillSignalReady>(), false);
      expect(getIt.isReadySync<TestClassWillSignalReady2>(), false);
      expect(
        getIt.isReadySync<TestClass2>(instanceName: 'Second Instance'),
        false,
      );

      final timer = Stopwatch()..start();
      await getIt.allReady(timeout: const Duration(milliseconds: 20));
      expect(timer.elapsedMilliseconds, greaterThan(5));
    },
  );

  test('ready external signalling', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(
      TestClass(internalCompletion: false, getIt: getIt),
      signalsReady: true,
    );
    getIt.registerSingleton<TestClass2>(
      TestClass2(internalCompletion: false, getIt: getIt),
      signalsReady: true,
    );
    getIt.registerSingleton(
      TestClass2(internalCompletion: false, getIt: getIt),
      instanceName: 'Second Instance',
      signalsReady: true,
    );

    expect(getIt.allReadySync(), false);
    // these are async calls fire and forget
    getIt<TestClass>().initWithSignal();
    getIt<TestClass2>().initWithSignal();
    final TestClass2 instance = getIt<TestClass2>(
      instanceName: 'Second Instance',
    );
    instance.initWithSignal();

    expect(getIt.allReady(), completes);
  });

  test('ready automatic signalling for async Singletons', () async {
    final getIt = GetIt.instance;
    await getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      () async => TestClass(internalCompletion: false).init(),
    );
    getIt.registerSingletonAsync<TestClass2>(() async {
      final instance = TestClass2(internalCompletion: false, initMsDelay: 50);
      await instance.init();
      return instance;
    });
    getIt.registerSingletonAsync<TestClass>(
      () async => TestClass2(internalCompletion: false).init(),
      instanceName: 'Second Instance',
    );

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(
      getIt.isReadySync<TestClass>(instanceName: 'Second Instance'),
      false,
    );

    await getIt.allReady();

    expect(getIt.isReadySync<TestClass>(), true);
    expect(getIt.isReadySync<TestClass2>(), true);
    expect(getIt.isReadySync<TestClass>(instanceName: 'Second Instance'), true);
  });

  test('isReady propagates Error', () async {
    final getIt = GetIt.instance;
    await getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      () async => TestClass(internalCompletion: false).initWithExeption(),
    );
    expect(getIt.isReady<TestClass>(), throwsStateError);
  });

  test(
    'allReady propagades Exceptions that occur in the factory functions',
    () async {
      final getIt = GetIt.instance;
      await getIt.reset();

      getIt.registerSingletonAsync<TestClass>(
        () async => TestClass(internalCompletion: false).init(),
      );
      getIt.registerSingletonAsync<TestClass2>(() async {
        final instance = TestClass2(internalCompletion: false);
        await Future.delayed(const Duration(milliseconds: 500));
        throw StateError('Intentional');
      });
      getIt.registerSingletonAsync(
        () async => TestClass2(internalCompletion: false)..init(),
        instanceName: 'Second Instance',
      );

      expect(getIt.allReady(), throwsStateError);
    },
  );
  test('ready manual synchronisation of sequence', () async {
    final getIt = GetIt.instance;
    await getIt.reset();
    errorCounter = 0;
    var flag1 = false;
    var flag2 = false;

    getIt.registerSingletonAsync<TestClass>(() async {
      final instance = TestClass(internalCompletion: false);
      while (!flag1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return instance;
    });

    getIt.registerSingletonAsync<TestClass2>(() async {
      await getIt.isReady<TestClass>();
      final instance = TestClass2(internalCompletion: false);
      while (!flag2) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return instance;
    });

    getIt.registerSingletonAsync<TestClass3>(() async {
      await getIt.isReady<TestClass2>();
      final instance = TestClass3(internalCompletion: false);
      await instance.init();
      return instance;
    });

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync(), false);

    flag2 = true;

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReady<TestClass2>(), completes);
    expect(getIt.isReady<TestClass3>(), completes);
    expect(getIt.allReady(), completes);
  });

  test('ready automatic synchronisation of sequence', () async {
    final getIt = GetIt.instance;
    errorCounter = 0;
    var flag1 = false;

    getIt.registerSingletonAsync<TestClass>(() async {
      final instance = TestClass(internalCompletion: false);
      while (!flag1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return instance;
    });

    getIt.registerSingletonWithDependencies<TestClass2>(() {
      return TestClass2(internalCompletion: false);
    }, dependsOn: [TestClass]);

    getIt.registerSingletonAsync<TestClass3>(() async {
      final instance = TestClass3(internalCompletion: false);
      await instance.init();
      return instance;
    }, dependsOn: [TestClass, TestClass2]);

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    // give the factory function a chance to run
    await Future.delayed(const Duration(microseconds: 1));

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReady<TestClass2>(), completes);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync(), false);

    expect(
      getIt.isReady<TestClass>(timeout: const Duration(seconds: 5)),
      completes,
    );
    expect(
      getIt.isReady<TestClass2>(timeout: const Duration(seconds: 10)),
      completes,
    );
    expect(
      getIt.isReady<TestClass3>(timeout: const Duration(seconds: 15)),
      completes,
    );
    expect(getIt.allReady(timeout: const Duration(seconds: 20)), completes);
  });
  test('ready automatic synchronisation of sequence', () async {
    final getIt = GetIt.instance;
    errorCounter = 0;
    var flag1 = false;

    getIt.registerSingletonAsync<TestClass>(() async {
      final instance = TestClass(internalCompletion: false);
      while (!flag1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return instance;
    });

    getIt.registerSingletonWithDependencies<TestClass2>(() {
      return TestClass2(internalCompletion: false);
    }, dependsOn: [TestClass]);

    getIt.registerSingletonAsync<TestClass3>(() async {
      final instance = TestClass3(internalCompletion: false);
      await instance.init();
      return instance;
    }, dependsOn: [TestClass, TestClass2]);

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    // give the factory function a chance to run
    await Future.delayed(const Duration(microseconds: 1));

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReady<TestClass2>(), completes);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync(), false);

    expect(
      getIt.isReady<TestClass>(timeout: const Duration(seconds: 5)),
      completes,
    );
    expect(
      getIt.isReady<TestClass2>(timeout: const Duration(seconds: 10)),
      completes,
    );
    expect(
      getIt.isReady<TestClass3>(timeout: const Duration(seconds: 15)),
      completes,
    );
    expect(getIt.allReady(timeout: const Duration(seconds: 20)), completes);
  });

  test('ready automatic synchronisation with signalReady', () async {
    final getIt = GetIt.instance;
    errorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(internalCompletion: false, getIt: getIt),
      signalsReady: true,
    );

    getIt.registerSingletonWithDependencies<TestClass3>(
      () => TestClass3(internalCompletion: true, getIt: getIt),
      dependsOn: [TestClass],
      signalsReady: true,
    );

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    await getIt<TestClass>().initWithSignal();
    await getIt.allReady();

    final o = getIt<TestClass3>();

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReadySync<TestClass3>(), true);
    expect(getIt.allReadySync(), true);
  });

  test('allReady will throw after timeout', () async {
    final getIt = GetIt.instance;

    getIt.registerSingletonAsync<TestClass>(
      () async => TestClass(internalCompletion: false, getIt: getIt),
      signalsReady: true,
    );
    getIt.registerSingletonAsync<TestClass>(
      () async => TestClass(internalCompletion: true, getIt: getIt),
      instanceName: "Second instance",
      signalsReady: true,
    );
    getIt.registerSingletonAsync<TestClass2>(
      () async => TestClass2(internalCompletion: false)..init(),
      dependsOn: [TestClass],
    );
    // this here should signal internally but doesn't do it.
    getIt.registerSingletonAsync<TestClass3>(
      () async => TestClass3(internalCompletion: false),
      signalsReady: true,
    );
    getIt.registerSingletonAsync<TestClass4>(
      () async => TestClass4(internalCompletion: false),
    );

    Future.delayed(
      const Duration(milliseconds: 1),
      () async => getIt.isReady<TestClass3>(callee: 'asyncTest'),
    );

    try {
      await getIt.allReady(timeout: const Duration(seconds: 1));
    } catch (ex) {
      expect(ex, isA<WaitingTimeOutException>());
      final timeOut = ex as WaitingTimeOutException;
      expect(timeOut.notReadyYet.contains('null : TestClass'), true);
      expect(timeOut.notReadyYet.contains('null : TestClass2'), true);
      expect(timeOut.notReadyYet.contains('null : TestClass3'), true);
      expect(timeOut.areReady.contains('null : TestClass4'), true);
      expect(timeOut.areReady.contains('Second instance : TestClass'), true);
      expect(
        timeOut.areWaitedBy['null : TestClass']!.contains('TestClass2'),
        true,
      );
      expect(
        timeOut.areWaitedBy['null : TestClass3']!.contains('String'),
        true,
      );
    }
  });

  test('asyncFactory called with getAsync', () async {
    final getIt = GetIt.instance;
    await getIt.reset();

    getIt.registerFactoryAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    final instance = await getIt.getAsync<TestClass>();
    expect(instance, isA<TestClass>());
  });

  test('register factory with one Param', () async {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParamAsync<TestClassParam, String, void>((s, _) async {
      await Future.delayed(const Duration(milliseconds: 1));
      return TestClassParam(param1: s);
    });

    //final instance1 = getIt.get<TestBaseClass>();

    final instance1 = await getIt.getAsync<TestClassParam>(param1: 'abc');
    final instance2 = await getIt.getAsync<TestClassParam>(param1: '123');

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, '123');
  });

  test('register factory with one nullable Param', () async {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParamAsync<TestClassParam, String?, void>((
      s,
      _,
    ) async {
      await Future.delayed(const Duration(milliseconds: 1));
      return TestClassParam(param1: s);
    });

    final instance1 = await getIt.getAsync<TestClassParam>(param1: 'abc');
    final instance2 = await getIt.getAsync<TestClassParam>();

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, null);
  });

  test('register factory with two Params', () async {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParamAsync<TestClassParam, String, int>((s, i) async {
      await Future.delayed(const Duration(milliseconds: 1));
      return TestClassParam(param1: s, param2: i);
    });

    //final instance1 = getIt.get<TestBaseClass>();

    final instance1 = await getIt.getAsync<TestClassParam>(
      param1: 'abc',
      param2: 3,
    );
    final instance2 = await getIt.getAsync<TestClassParam>(
      param1: '123',
      param2: 5,
    );

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1.param2, 3);
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, '123');
    expect(instance2.param2, 5);
  });

  test('register factory with two nullable Params', () async {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParamAsync<TestClassParam, String?, int?>((
      s,
      i,
    ) async {
      await Future.delayed(const Duration(milliseconds: 1));
      return TestClassParam(param1: s, param2: i);
    });

    final instance1 = await getIt.getAsync<TestClassParam>(
      param1: 'abc',
      param2: 3,
    );
    final instance2 = await getIt.getAsync<TestClassParam>();

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1.param2, 3);
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, null);
    expect(instance2.param2, null);
  });

  test('register factory with Params with wrong type', () async {
    final getIt = GetIt.instance;
    await getIt.reset();

    constructorCounter = 0;
    getIt.registerFactoryParamAsync<TestClassParam, String, int>(
      (s, i) async => TestClassParam(param1: s, param2: i),
    );

    expect(
      () => getIt.getAsync<TestClassParam>(param1: 'abc', param2: '3'),
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
    () async {
      final getIt = GetIt.instance;
      await getIt.reset();

      constructorCounter = 0;
      getIt.registerFactoryParamAsync<TestClassParam, String, void>(
        (s, i) async => TestClassParam(param1: s),
      );

      expect(
        () => getIt.getAsync<TestClassParam>(),
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

  test('asyncFactory called with get instead of getAsync', () async {
    final getIt = GetIt.instance;
    await getIt.reset();

    getIt.registerFactoryAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    expect(() => getIt.get<TestClass>(), throwsA(isA<AssertionError>()));
  });

  test('asyncLazySingleton called with get before it was ready', () async {
    final getIt = GetIt.instance;
    await getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    await Future.delayed(const Duration(microseconds: 1));
    expect(() => getIt.get<TestClass>(), throwsStateError);
  });

  test('asyncLazySingleton called with getAsync', () async {
    final getIt = GetIt.instance;
    await getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)..init()),
    );

    final instance = await getIt.getAsync<TestClass>();
    expect(instance, isA<TestClass>());
  });

  test('asyncLazySingleton called with get after wait for ready', () async {
    final getIt = GetIt.instance;

    getIt.registerLazySingletonAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    await getIt.getAsync<TestClass>();

    await getIt.isReady<TestClass>(timeout: const Duration(milliseconds: 20));

    final instance2 = getIt.get<TestClass>();
    expect(instance2, isA<TestClass>());
  });

  test('isReady called on asyncLazySingleton ', () async {
    final getIt = GetIt.instance;
    await getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    await getIt.isReady<TestClass>(timeout: const Duration(milliseconds: 20));

    final instance = getIt.get<TestClass>();
    expect(instance, isA<TestClass>());
  });

  group("dependency", () {
    test('Register singleton with dependency and instanceName', () async {
      final getIt = GetIt.instance;
      await getIt.reset();
      getIt.registerSingletonAsync<TestClass>(
        () async => TestClass(internalCompletion: false),
      );

      getIt.registerSingletonAsync<TestClass2>(
        () async => TestClass2(internalCompletion: false),
        instanceName: "test2InstanceName",
        dependsOn: [TestClass],
      );

      await getIt.allReady();
      expect(
        getIt.get<TestClass2>(instanceName: "test2InstanceName"),
        isA<TestClass2>(),
      );
    });

    test('Register two dependent singleton with instanceNames', () async {
      final getIt = GetIt.instance;
      await getIt.reset();
      getIt.registerSingletonAsync<TestClass>(
        () async => TestClass(internalCompletion: false),
        instanceName: "test1InstanceName",
      );

      getIt.registerSingletonAsync<TestClass2>(
        () async => TestClass2(internalCompletion: false),
        instanceName: "test2InstanceName",
        dependsOn: [
          InitDependency(TestClass, instanceName: "test1InstanceName"),
        ],
      );

      await getIt.allReady();
      expect(
        getIt.get<TestClass2>(instanceName: "test2InstanceName"),
        isA<TestClass2>(),
      );
    });
  });

  test('Code for ReadMe', () async {
    final sl = GetIt.instance;

    sl.registerSingletonAsync<Service1>(() async {
      final instance = Service1Implementation();
      await instance.init();
      return instance;
    });
  });

  group("registerSingletonAsync, calling signalReady", () {
    test('attempt to get instance with getIt.get', () async {
      final getIt = GetIt.instance;
      getIt.registerSingletonAsync<TestClass>(
        () => Future.delayed(
          const Duration(milliseconds: 1),
        ).then((_) => TestClass(internalCompletion: true, getIt: getIt)),
        signalsReady: true,
      );

      await getIt.allReady();
      await Future.delayed(const Duration(seconds: 1));

      final instance = getIt<TestClass>();

      expect(instance.initCompleted, isTrue);
    });

    test('attempt to get instance with getAsync', () async {
      final getIt = GetIt.instance;
      getIt.registerSingletonAsync<TestClass>(
        () => Future.delayed(
          const Duration(milliseconds: 1),
        ).then((_) => TestClass(internalCompletion: true, getIt: getIt)),
        signalsReady: true,
      );

      await getIt.allReady();

      final instance = await getIt.getAsync<TestClass>();

      expect(instance.initCompleted, isTrue);
    });
  });

  group('allReady caching', () {
    test('allReady returns same Future on repeated calls', () async {
      final getIt = GetIt.instance;
      await getIt.reset();

      getIt.registerSingletonAsync<TestClass>(
        () => Future.delayed(const Duration(milliseconds: 10))
            .then((_) => TestClass(internalCompletion: false)),
      );

      final future1 = getIt.allReady();
      final future2 = getIt.allReady();

      expect(identical(future1, future2), isTrue);

      await future1;
    });

    test('allReady returns new Future after registerSingletonAsync', () async {
      final getIt = GetIt.instance;
      await getIt.reset();

      getIt.registerSingletonAsync<TestClass>(
        () => Future.delayed(const Duration(milliseconds: 10))
            .then((_) => TestClass(internalCompletion: false)),
      );

      final future1 = getIt.allReady();
      await future1;

      // Register another async singleton
      getIt.registerSingletonAsync<TestClass2>(
        () => Future.delayed(const Duration(milliseconds: 10))
            .then((_) => TestClass2(internalCompletion: false)),
      );

      final future2 = getIt.allReady();

      // Should be a new future since we registered a new async singleton
      expect(identical(future1, future2), isFalse);

      await future2;
    });

    test(
        'allReady returns new Future after pushNewScope with async registration',
        () async {
      final getIt = GetIt.instance;
      await getIt.reset();

      getIt.registerSingletonAsync<TestClass>(
        () => Future.delayed(const Duration(milliseconds: 10))
            .then((_) => TestClass(internalCompletion: false)),
      );

      final future1 = getIt.allReady();
      await future1;

      // Push a new scope with an async registration
      getIt.pushNewScope(
        init: (getIt) {
          getIt.registerSingletonAsync<TestClass2>(
            () => Future.delayed(const Duration(milliseconds: 10))
                .then((_) => TestClass2(internalCompletion: false)),
          );
        },
      );

      final future2 = getIt.allReady();

      // Should be a new future since we registered a new async singleton in the scope
      expect(identical(future1, future2), isFalse);

      await future2;
      await getIt.popScope();
    });
  });
}

abstract class Service1 {}

// abstract class Service2 {}

class Service1Implementation implements Service1 {
  Future init() {
    // dummy async call
    return Future.delayed(const Duration(microseconds: 1));
  }
}

// class Service2Implementation implements Service2 {
//   Service2Implementation() {
//     _init(); // we call _init here without awaiting it.
//   }

//   Future _init() async {
//     // dummy async call
//     await Future.delayed(const Duration(microseconds: 1));
//     // From here on we are ready
//   }
// }
