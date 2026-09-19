import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

abstract class Iface {}

class Impl implements Iface {}

class ServiceA {
  // ignore: avoid_unused_constructor_parameters
  ServiceA(ServiceB b);
}

class ServiceB {
  // ignore: avoid_unused_constructor_parameters
  ServiceB(ServiceA a);
}

class Node {
  Node(this.depth, this.child);
  final int depth;
  final Node? child;
}

void main() {
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
    GetIt.noDebugOutput = true;
  });

  tearDown(() async {
    await getIt.reset();
  });

  test(
    'lazy singleton registered with getIt.call throws instead of StackOverflow',
    () {
      getIt.registerLazySingleton<Iface>(getIt.call);

      expect(
        () => getIt<Iface>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Circular dependency detected'),
          ),
        ),
      );
    },
  );

  test(
    'lazy singleton factory that re-gets same type throws circular error',
    () {
      getIt.registerLazySingleton<Iface>(() => getIt<Iface>());

      expect(
        () => getIt<Iface>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Circular dependency detected'),
          ),
        ),
      );
    },
  );

  test(
    'lazy singleton alias to concrete impl resolves without circular error',
    () {
      getIt.registerLazySingleton<Impl>(Impl.new);
      getIt.registerLazySingleton<Iface>(() => getIt<Impl>());

      final Iface instance = getIt<Iface>();
      expect(instance, isA<Impl>());
      expect(identical(instance, getIt<Impl>()), isTrue);
    },
  );

  test(
    'A -> B -> A cycle between lazy singletons throws circular error',
    () {
      getIt.registerLazySingleton<ServiceA>(() => ServiceA(getIt<ServiceB>()));
      getIt.registerLazySingleton<ServiceB>(() => ServiceB(getIt<ServiceA>()));

      expect(
        () => getIt<ServiceA>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Circular dependency detected'),
          ),
        ),
      );
    },
  );

  test(
    'lazy singleton stays usable after a failed creation attempt',
    () {
      var shouldFail = true;
      getIt.registerLazySingleton<Iface>(() {
        if (shouldFail) throw Exception('boom');
        return Impl();
      });

      expect(() => getIt<Iface>(), throwsException);

      // The in-progress flag must have been reset by the failed attempt so
      // the next access can create the instance normally.
      shouldFail = false;
      expect(getIt<Iface>(), isA<Impl>());
    },
  );

  test(
    'cached factory registered with getIt.call throws instead of StackOverflow',
    () {
      getIt.registerCachedFactory<Iface>(getIt.call);

      expect(
        () => getIt<Iface>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Circular dependency detected'),
          ),
        ),
      );
    },
  );

  test(
    'cached factory that re-gets same type with params throws circular error',
    () {
      getIt.registerCachedFactoryParam<Iface, int, void>(
        (p1, _) => getIt<Iface>(param1: p1),
      );

      expect(
        () => getIt<Iface>(param1: 1),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Circular dependency detected'),
          ),
        ),
      );
    },
  );

  // Plain (always-new) factories are intentionally NOT guarded: a factory that
  // recursively resolves its own type is a legitimate pattern (e.g. building a
  // tree with a decreasing depth parameter), and the factory hot path should
  // stay free of any per-call overhead. A `registerFactory<Iface>(getIt.call)`
  // therefore still recurses until StackOverflowError, as before.
  test(
    'self-recursive registerFactoryParam builds a tree of the expected depth',
    () {
      getIt.registerFactoryParam<Node, int, void>(
        (depth, _) => Node(
          depth,
          depth == 0 ? null : getIt<Node>(param1: depth - 1),
        ),
      );

      final root = getIt<Node>(param1: 5);

      var current = root;
      var levels = 1;
      while (current.child != null) {
        current = current.child!;
        levels++;
      }
      expect(root.depth, 5);
      expect(current.depth, 0);
      expect(levels, 6);
    },
  );

  test(
    'self-recursive registerFactoryParamAsync resolves without circular error',
    () async {
      getIt.registerFactoryParamAsync<Node, int, void>((depth, _) async {
        // registerFactoryParamAsync passes params as nullable
        final d = depth!;
        if (d == 0) return Node(0, null);
        final child = await getIt.getAsync<Node>(param1: d - 1);
        return Node(d, child);
      });

      final root = await getIt.getAsync<Node>(param1: 3);

      expect(root.depth, 3);
      expect(root.child?.child?.child?.depth, 0);
    },
  );

  test(
    'overlapping getAsync on same async factory succeeds',
    () async {
      var creates = 0;
      getIt.registerFactoryAsync<Impl>(() async {
        creates++;
        await Future<void>.delayed(Duration.zero);
        return Impl();
      });

      final results = await Future.wait([
        getIt.getAsync<Impl>(),
        getIt.getAsync<Impl>(),
      ]);

      expect(results, hasLength(2));
      expect(results[0], isA<Impl>());
      expect(results[1], isA<Impl>());
      expect(creates, 2);
    },
  );

  test(
    'overlapping getAsync on same async lazy singleton succeeds',
    () async {
      var creates = 0;
      getIt.registerLazySingletonAsync<Impl>(() async {
        creates++;
        await Future<void>.delayed(Duration.zero);
        return Impl();
      });

      final results = await Future.wait([
        getIt.getAsync<Impl>(),
        getIt.getAsync<Impl>(),
      ]);

      expect(results, hasLength(2));
      expect(identical(results[0], results[1]), isTrue);
      expect(creates, 1);
    },
  );

  test(
    'overlapping getAsync on same async cached factory succeeds',
    () async {
      var creates = 0;
      getIt.registerCachedFactoryAsync<Impl>(() async {
        creates++;
        await Future<void>.delayed(Duration.zero);
        return Impl();
      });

      final results = await Future.wait([
        getIt.getAsync<Impl>(),
        getIt.getAsync<Impl>(),
      ]);

      expect(results, hasLength(2));
      expect(results[0], isA<Impl>());
      expect(results[1], isA<Impl>());
      // Both calls started before either finished, so both created an instance.
      expect(creates, 2);
    },
  );

  test(
    'async cached factory that re-gets same type throws circular error',
    () async {
      getIt.registerCachedFactoryAsync<Iface>(() => getIt.getAsync<Iface>());

      await expectLater(
        getIt.getAsync<Iface>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Circular dependency detected'),
          ),
        ),
      );
    },
  );

  test(
    'async lazy singleton registered with getIt.getAsync throws circular error',
    () async {
      getIt.registerLazySingletonAsync<Iface>(() => getIt.getAsync<Iface>());

      await expectLater(
        getIt.getAsync<Iface>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Circular dependency detected'),
          ),
        ),
      );
    },
  );
}
