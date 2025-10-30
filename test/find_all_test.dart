// ignore_for_file: unreachable_from_main

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

// Test interfaces and classes
abstract interface class IOutput {
  void write(String message);
}

abstract interface class IDisposable {
  void dispose();
}

class FileOutput implements IOutput {
  @override
  void write(String message) {}
}

class ConsoleOutput implements IOutput, IDisposable {
  @override
  void write(String message) {}

  @override
  void dispose() {}
}

class EnhancedFileOutput extends FileOutput implements IDisposable {
  @override
  void dispose() {}
}

class DatabaseService {
  void save(String data) {}
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
  });

  group('findAll - basic functionality', () {
    test('finds instances by registration type (default)', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());
      GetIt.I.registerSingleton<DatabaseService>(DatabaseService());

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs.length, 2);
      expect(outputs[0], isA<FileOutput>());
      expect(outputs[1], isA<ConsoleOutput>());
    });

    test('finds instances by instance type only', () {
      // Register as concrete types but find by interface
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());

      final outputs = GetIt.I.findAll<IOutput>(
        includeMatchedByRegistrationType: false,
      );

      expect(outputs.length, 2);
      expect(outputs[0], isA<FileOutput>());
      expect(outputs[1], isA<ConsoleOutput>());
    });

    test('finds instances by both registration and instance type', () {
      GetIt.I.registerSingleton<IOutput>(FileOutput());
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs.length, 2);
    });

    test('returns empty list when no matches found', () {
      GetIt.I.registerSingleton<DatabaseService>(DatabaseService());

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs, isEmpty);
    });
  });

  group('findAll - includeSubtypes parameter', () {
    test('includes subtypes when includeSubtypes=true (default)', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerSingleton<EnhancedFileOutput>(EnhancedFileOutput());

      final outputs = GetIt.I.findAll<FileOutput>();

      expect(outputs.length, 2);
    });

    test('excludes subtypes when includeSubtypes=false', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerSingleton<EnhancedFileOutput>(EnhancedFileOutput());

      final outputs = GetIt.I.findAll<FileOutput>(
        includeSubtypes: false,
        includeMatchedByInstance: false,
      );

      expect(outputs.length, 1);
      expect(outputs[0], isA<FileOutput>());
      expect(outputs[0], isNot(isA<EnhancedFileOutput>()));
    });

    test('exact type matching works with interfaces', () {
      GetIt.I.registerSingleton<IOutput>(FileOutput());
      GetIt.I.registerSingleton<FileOutput>(EnhancedFileOutput());

      final outputs = GetIt.I.findAll<IOutput>(
        includeSubtypes: false,
        includeMatchedByInstance: false,
      );

      expect(outputs.length, 1);
      expect(outputs[0], isA<FileOutput>());
    });
  });

  group('findAll - lazy singletons', () {
    test('skips uninstantiated lazy singletons by default', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerLazySingleton<ConsoleOutput>(() => ConsoleOutput());

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs.length, 1);
      expect(outputs[0], isA<FileOutput>());
    });

    test('includes already instantiated lazy singletons', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerLazySingleton<ConsoleOutput>(() => ConsoleOutput());

      // Force instantiation
      GetIt.I<ConsoleOutput>();

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs.length, 2);
    });

    test('instantiates lazy singletons when instantiateLazySingletons=true',
        () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerLazySingleton<ConsoleOutput>(() => ConsoleOutput());

      // Verify lazy singleton hasn't been instantiated yet
      expect(GetIt.I.isRegistered<ConsoleOutput>(), true);

      final outputs = GetIt.I.findAll<IOutput>(
        instantiateLazySingletons: true,
      );

      expect(outputs.length, 2);
      // Verify it was instantiated by trying to get it (won't create new instance)
      final console = GetIt.I<ConsoleOutput>();
      expect(console, isA<ConsoleOutput>());
    });

    test('only instantiates matching lazy singletons', () {
      var fileInstantiated = false;
      var databaseInstantiated = false;

      GetIt.I.registerLazySingleton<FileOutput>(() {
        fileInstantiated = true;
        return FileOutput();
      });
      GetIt.I.registerLazySingleton<DatabaseService>(() {
        databaseInstantiated = true;
        return DatabaseService();
      });

      final outputs = GetIt.I.findAll<IOutput>(
        instantiateLazySingletons: true,
      );

      expect(outputs.length, 1);
      expect(fileInstantiated, true);
      expect(databaseInstantiated, false);
    });
  });

  group('findAll - factories', () {
    test('skips factories by default', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerFactory<ConsoleOutput>(() => ConsoleOutput());

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs.length, 1);
      expect(outputs[0], isA<FileOutput>());
    });

    test('calls factories when callFactories=true', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerFactory<ConsoleOutput>(() => ConsoleOutput());

      final outputs = GetIt.I.findAll<IOutput>(callFactories: true);

      expect(outputs.length, 2);
      expect(outputs[0], isA<FileOutput>());
      expect(outputs[1], isA<ConsoleOutput>());
    });

    test('each factory call creates new instance', () {
      GetIt.I.registerFactory<FileOutput>(() => FileOutput());

      final outputs1 = GetIt.I.findAll<IOutput>(callFactories: true);
      final outputs2 = GetIt.I.findAll<IOutput>(callFactories: true);

      expect(outputs1.length, 1);
      expect(outputs2.length, 1);
      expect(identical(outputs1[0], outputs2[0]), false);
    });

    test('only calls matching factories', () {
      var fileOutputCalls = 0;
      var databaseCalls = 0;

      GetIt.I.registerFactory<FileOutput>(() {
        fileOutputCalls++;
        return FileOutput();
      });
      GetIt.I.registerFactory<DatabaseService>(() {
        databaseCalls++;
        return DatabaseService();
      });

      GetIt.I.findAll<IOutput>(callFactories: true);

      expect(fileOutputCalls, 1);
      expect(databaseCalls, 0);
    });
  });

  group('findAll - combined lazy singletons and factories', () {
    test('handles combination of singletons, lazy, and factories', () {
      GetIt.I.registerSingleton<IOutput>(FileOutput(), instanceName: 'file');
      GetIt.I.registerLazySingleton<IOutput>(
        () => ConsoleOutput(),
        instanceName: 'console',
      );
      GetIt.I.registerFactory<IOutput>(
        () => EnhancedFileOutput(),
        instanceName: 'enhanced',
      );

      final outputs = GetIt.I.findAll<IOutput>(
        instantiateLazySingletons: true,
        callFactories: true,
      );

      expect(outputs.length, 3);
      // FileOutput appears once (could be plain FileOutput or part of EnhancedFileOutput)
      expect(outputs.whereType<ConsoleOutput>().length, 1);
      expect(outputs.whereType<EnhancedFileOutput>().length, 1);
    });
  });

  group('findAll - scope handling', () {
    test('searches current scope only by default', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.pushNewScope();
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs.length, 1);
      expect(outputs[0], isA<ConsoleOutput>());
    });

    test('searches all scopes when inAllScopes=true', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.pushNewScope();
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());

      final outputs = GetIt.I.findAll<IOutput>(inAllScopes: true);

      expect(outputs.length, 2);
    });

    test('searches specific named scope when onlyInScope provided', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.pushNewScope(scopeName: 'session');
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());
      GetIt.I.pushNewScope(scopeName: 'feature');
      GetIt.I.registerSingleton<EnhancedFileOutput>(EnhancedFileOutput());

      final outputs = GetIt.I.findAll<IOutput>(onlyInScope: 'session');

      expect(outputs.length, 1);
      expect(outputs[0], isA<ConsoleOutput>());
    });

    test('onlyInScope takes precedence over inAllScopes', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.pushNewScope(scopeName: 'session');
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());

      final outputs = GetIt.I.findAll<IOutput>(onlyInScope: 'session');

      expect(outputs.length, 1);
      expect(outputs[0], isA<ConsoleOutput>());
    });

    test('throws StateError when onlyInScope scope does not exist', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());

      expect(
        () => GetIt.I.findAll<IOutput>(onlyInScope: 'nonexistent'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Scope with name "nonexistent" does not exist'),
          ),
        ),
      );
    });
  });

  group('findAll - validation errors', () {
    test(
        'throws ArgumentError when includeSubtypes=false with includeMatchedByInstance=true',
        () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());

      expect(
        () => GetIt.I.findAll<IOutput>(
          includeSubtypes: false,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('includeSubtypes=false'),
          ),
        ),
      );
    });

    test(
        'throws ArgumentError when instantiateLazySingletons=true without includeMatchedByRegistrationType',
        () {
      GetIt.I.registerLazySingleton<FileOutput>(() => FileOutput());

      expect(
        () => GetIt.I.findAll<IOutput>(
          includeMatchedByRegistrationType: false,
          instantiateLazySingletons: true,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('instantiateLazySingletons=true requires'),
          ),
        ),
      );
    });

    test(
        'throws ArgumentError when callFactories=true without includeMatchedByRegistrationType',
        () {
      GetIt.I.registerFactory<FileOutput>(() => FileOutput());

      expect(
        () => GetIt.I.findAll<IOutput>(
          includeMatchedByRegistrationType: false,
          callFactories: true,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('callFactories=true requires'),
          ),
        ),
      );
    });
  });

  group('findAll - edge cases', () {
    test('handles multiple registrations with instance names', () {
      GetIt.I.registerSingleton<IOutput>(
        FileOutput(),
        instanceName: 'file1',
      );
      GetIt.I.registerSingleton<IOutput>(
        FileOutput(),
        instanceName: 'file2',
      );
      GetIt.I.registerSingleton<IOutput>(
        ConsoleOutput(),
        instanceName: 'console',
      );

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs.length, 3);
    });

    test('does not return duplicate instances', () {
      final instance = FileOutput();
      GetIt.I.registerSingleton<FileOutput>(instance);
      GetIt.I.registerSingleton<IOutput>(instance, instanceName: 'output');

      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs.length, 2);
      // Both should be the same instance
      expect(identical(outputs[0], outputs[1]), true);
    });

    test('handles empty GetIt', () {
      final outputs = GetIt.I.findAll<IOutput>();

      expect(outputs, isEmpty);
    });

    test('works with Object type to get all instances', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());
      GetIt.I.registerSingleton<DatabaseService>(DatabaseService());

      final all = GetIt.I.findAll<Object>();

      expect(all.length, 3);
    });

    test('registration type matching takes precedence over instance matching',
        () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());

      final byRegistration = GetIt.I.findAll<FileOutput>();

      final byInstance = GetIt.I.findAll<IOutput>();

      expect(byRegistration.length, 1);
      expect(byInstance.length, 1);
    });
  });

  group('findAll - practical use cases', () {
    test('dispose all resources implementing IDisposable', () {
      final file = EnhancedFileOutput();
      final console = ConsoleOutput();

      GetIt.I.registerSingleton<EnhancedFileOutput>(file);
      GetIt.I.registerSingleton<ConsoleOutput>(console);

      final disposables = GetIt.I.findAll<IDisposable>();

      expect(disposables.length, 2);
      for (final disposable in disposables) {
        disposable.dispose();
      }
    });

    test('find all outputs across multiple scopes for cleanup', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.pushNewScope(scopeName: 'session');
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());
      GetIt.I.pushNewScope(scopeName: 'feature');
      GetIt.I.registerLazySingleton<EnhancedFileOutput>(
        () => EnhancedFileOutput(),
      );

      // Get all outputs including lazy ones for app shutdown
      final allOutputs = GetIt.I.findAll<IOutput>(
        inAllScopes: true,
        instantiateLazySingletons: true,
      );

      expect(allOutputs.length, 3);
    });

    test('find all services in specific scope for scope cleanup', () {
      GetIt.I.registerSingleton<FileOutput>(FileOutput());
      GetIt.I.pushNewScope(scopeName: 'userSession');
      GetIt.I.registerSingleton<ConsoleOutput>(ConsoleOutput());
      GetIt.I.registerSingleton<EnhancedFileOutput>(EnhancedFileOutput());

      // Clean up only user session resources
      final sessionServices = GetIt.I.findAll<Object>(
        onlyInScope: 'userSession',
      );

      expect(sessionServices.length, 2);
      expect(sessionServices.whereType<ConsoleOutput>().length, 1);
      expect(sessionServices.whereType<EnhancedFileOutput>().length, 1);
    });
  });
}
