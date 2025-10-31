// ignore_for_file: unreachable_from_main

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

int constructorCounter = 0;
int onCreatedCounter = 0;
Object? lastCreatedInstance;

class TestService {
  final String id;

  TestService(this.id) {
    constructorCounter++;
  }
}

class AsyncTestService {
  final String id;

  AsyncTestService(this.id) {
    constructorCounter++;
  }
}

class AsyncTestServiceWithSignal extends AsyncTestService
    implements WillSignalReady {
  AsyncTestServiceWithSignal(super.id);

  Future<void> init() async {
    await Future.delayed(const Duration(milliseconds: 10));
    GetIt.I.signalReady(this);
  }
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    constructorCounter = 0;
    onCreatedCounter = 0;
    lastCreatedInstance = null;
  });

  group('onCreated callback for registerLazySingleton', () {
    test('callback is called when lazy singleton is first accessed', () {
      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('lazy1'),
        onCreated: (instance) {
          onCreatedCounter++;
          lastCreatedInstance = instance;
        },
      );

      expect(onCreatedCounter, 0); // Not called yet

      final service = GetIt.I<TestService>();

      expect(constructorCounter, 1);
      expect(onCreatedCounter, 1); // Called after first access
      expect(lastCreatedInstance, same(service));
    });

    test('callback is not called on subsequent accesses', () {
      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('lazy1'),
        onCreated: (instance) {
          onCreatedCounter++;
        },
      );

      final service1 = GetIt.I<TestService>();
      expect(onCreatedCounter, 1);

      final service2 = GetIt.I<TestService>();
      expect(onCreatedCounter, 1); // Still 1, not called again
      expect(identical(service1, service2), isTrue);
    });

    test('callback receives correct instance', () {
      TestService? receivedInstance;

      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('lazy1'),
        onCreated: (instance) {
          receivedInstance = instance;
        },
      );

      final service = GetIt.I<TestService>();

      expect(receivedInstance, isNotNull);
      expect(identical(receivedInstance, service), isTrue);
      expect(receivedInstance!.id, 'lazy1');
    });

    test('callback works with named instances', () {
      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('unnamed'),
        onCreated: (instance) {
          onCreatedCounter++;
        },
      );

      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('named1'),
        instanceName: 'name1',
        onCreated: (instance) {
          onCreatedCounter++;
        },
      );

      GetIt.I<TestService>();
      expect(onCreatedCounter, 1);

      GetIt.I<TestService>(instanceName: 'name1');
      expect(onCreatedCounter, 2);
    });

    test('error in callback propagates and prevents retrieval', () {
      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('lazy1'),
        onCreated: (instance) {
          onCreatedCounter++;
          throw Exception('Callback error!');
        },
      );

      // Should throw when trying to get the instance
      expect(
        () => GetIt.I<TestService>(),
        throwsA(isA<Exception>()),
      );

      expect(onCreatedCounter, 1); // Callback was called
      expect(
        constructorCounter,
        1,
      ); // Instance was created before callback threw
    });

    test('callback works when lazy singleton is reset and recreated', () async {
      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('lazy1'),
        onCreated: (instance) {
          onCreatedCounter++;
        },
      );

      GetIt.I<TestService>();
      expect(onCreatedCounter, 1);

      await GetIt.I.resetLazySingleton<TestService>();

      GetIt.I<TestService>();
      expect(onCreatedCounter, 2); // Called again after reset
    });

    test('callback works with weak references', () {
      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('weak'),
        useWeakReference: true,
        onCreated: (instance) {
          onCreatedCounter++;
          lastCreatedInstance = instance;
        },
      );

      final service = GetIt.I<TestService>();

      expect(onCreatedCounter, 1);
      expect(lastCreatedInstance, same(service));
    });
  });

  group('onCreated callback for registerLazySingletonAsync', () {
    test('callback is called when async lazy singleton is first accessed',
        () async {
      GetIt.I.registerLazySingletonAsync<AsyncTestService>(
        () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return AsyncTestService('async1');
        },
        onCreated: (instance) {
          onCreatedCounter++;
          lastCreatedInstance = instance;
        },
      );

      expect(onCreatedCounter, 0);

      final service = await GetIt.I.getAsync<AsyncTestService>();

      expect(constructorCounter, 1);
      expect(onCreatedCounter, 1);
      expect(lastCreatedInstance, same(service));
    });

    test('callback is not called on subsequent accesses', () async {
      GetIt.I.registerLazySingletonAsync<AsyncTestService>(
        () async => AsyncTestService('async1'),
        onCreated: (instance) {
          onCreatedCounter++;
        },
      );

      await GetIt.I.getAsync<AsyncTestService>();
      expect(onCreatedCounter, 1);

      await GetIt.I.getAsync<AsyncTestService>();
      expect(onCreatedCounter, 1); // Still 1
    });

    test('error in callback propagates and prevents retrieval', () async {
      GetIt.I.registerLazySingletonAsync<AsyncTestService>(
        () async => AsyncTestService('async1'),
        onCreated: (instance) {
          onCreatedCounter++;
          throw Exception('Async callback error!');
        },
      );

      await expectLater(
        GetIt.I.getAsync<AsyncTestService>(),
        throwsA(isA<Exception>()),
      );

      expect(onCreatedCounter, 1); // Callback was called
      expect(
        constructorCounter,
        1,
      ); // Instance was created before callback threw
    });
  });

  group('onCreated callback for registerSingletonAsync', () {
    test('callback is called after async singleton creation', () async {
      GetIt.I.registerSingletonAsync<AsyncTestService>(
        () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return AsyncTestService('singleton1');
        },
        onCreated: (instance) {
          onCreatedCounter++;
          lastCreatedInstance = instance;
        },
      );

      await GetIt.I.allReady();

      expect(constructorCounter, 1);
      expect(onCreatedCounter, 1);
      expect(lastCreatedInstance, isNotNull);

      final service = GetIt.I<AsyncTestService>();
      expect(lastCreatedInstance, same(service));
    });

    test('callback is called even with signalsReady', () async {
      GetIt.I.registerSingletonAsync<AsyncTestServiceWithSignal>(
        () async {
          final instance = AsyncTestServiceWithSignal('singleton1');
          // Instance will signal ready from its init method
          instance.init();
          return instance;
        },
        signalsReady: true,
        onCreated: (instance) {
          onCreatedCounter++;
        },
      );

      await GetIt.I.isReady<AsyncTestServiceWithSignal>();

      expect(onCreatedCounter, 1);
    });

    test('callback works with dependencies', () async {
      // Register first dependency
      GetIt.I.registerSingletonAsync<TestService>(
        () async => TestService('dep1'),
        onCreated: (instance) {
          onCreatedCounter++;
        },
      );

      // Register dependent service
      GetIt.I.registerSingletonAsync<AsyncTestService>(
        () async => AsyncTestService('dependent'),
        dependsOn: [TestService],
        onCreated: (instance) {
          onCreatedCounter++;
        },
      );

      await GetIt.I.allReady();

      expect(onCreatedCounter, 2); // Both callbacks called
    });

    test('error in callback propagates and prevents initialization', () async {
      GetIt.I.registerSingletonAsync<AsyncTestService>(
        () async => AsyncTestService('singleton1'),
        onCreated: (instance) {
          onCreatedCounter++;
          throw Exception('Singleton async callback error!');
        },
      );

      // allReady should throw when callback throws
      await expectLater(
        GetIt.I.allReady(),
        throwsA(isA<Exception>()),
      );

      expect(onCreatedCounter, 1); // Callback was called
      expect(
        constructorCounter,
        1,
      ); // Instance was created before callback threw
    });
  });

  group('onCreated callback combinations', () {
    test('multiple singletons can have different callbacks', () async {
      var service1Created = false;
      var service2Created = false;

      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('service1'),
        onCreated: (instance) {
          service1Created = true;
        },
      );

      GetIt.I.registerLazySingletonAsync<AsyncTestService>(
        () async => AsyncTestService('service2'),
        onCreated: (instance) {
          service2Created = true;
        },
      );

      GetIt.I<TestService>();
      expect(service1Created, isTrue);
      expect(service2Created, isFalse);

      await GetIt.I.getAsync<AsyncTestService>();
      expect(service2Created, isTrue);
    });

    test('onCreated can be null (optional)', () {
      GetIt.I.registerLazySingleton<TestService>(
        () => TestService('service1'),
        // onCreated not provided
      );

      final service = GetIt.I<TestService>();
      expect(service, isNotNull);
    });
  });
}
