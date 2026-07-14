import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

abstract class Iface {}

class Impl implements Iface {}

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
    'factory registered with getIt.call throws instead of StackOverflow',
    () {
      getIt.registerFactory<Iface>(getIt.call);

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
    'async factory that re-gets same type throws circular error',
    () async {
      getIt.registerFactoryAsync<Iface>(() => getIt.getAsync<Iface>());

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
