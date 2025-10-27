import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

abstract interface class IOutput {
  void write(String message);
}

class FileOutput implements IOutput {
  @override
  void write(String message) {
    print('File: $message');
  }
  
  void clearFile() {
    print('Clearing file');
  }
}

class ConsoleOutput implements IOutput {
  @override
  void write(String message) {
    print('Console: $message');
  }
}

class RemoteLoggingOutput implements IOutput {
  @override
  void write(String message) {
    print('Remote: $message');
  }
}

class DatabaseService {
  void save(String data) {
    print('Saving to DB: $data');
  }
}

void main() {
  setUp(() async {
    // make sure the instance is cleared before each test
    await GetIt.I.reset();
  });

  group('findAll method tests', () {
    test('findAll returns services registered as the exact type', () {
      final getIt = GetIt.instance;
      
      getIt
        ..registerSingleton<IOutput>(FileOutput(), instanceName: 'file')
        ..registerSingleton<IOutput>(ConsoleOutput(), instanceName: 'console');

      final outputs = getIt.getAll<IOutput>();
      
      expect(outputs.length, 2);
      expect(outputs.first, isA<FileOutput>());
      expect(outputs.last, isA<ConsoleOutput>());
    });

    test('findAll returns services that implement the type regardless of registration type', () {
      final getIt = GetIt.instance;
      
      getIt
        ..registerSingleton(FileOutput())
        ..registerSingleton(ConsoleOutput())
        ..registerSingleton(RemoteLoggingOutput())
        ..registerSingleton(DatabaseService()); // doesn't implement IOutput

      final outputs = getIt.findAll<IOutput>();
      
      expect(outputs.length, 3);
      expect(outputs, contains(isA<FileOutput>()));
      expect(outputs, contains(isA<ConsoleOutput>()));
      expect(outputs, contains(isA<RemoteLoggingOutput>()));
      
      // Should not contain DatabaseService
      expect(outputs.whereType<DatabaseService>(), isEmpty);
    });

    test('findAll works with lazy singletons', () {
      final getIt = GetIt.instance;
      
      getIt
        ..registerLazySingleton<FileOutput>(() => FileOutput())
        ..registerLazySingleton<ConsoleOutput>(() => ConsoleOutput())
        ..registerLazySingleton<DatabaseService>(() => DatabaseService());

      final outputs = getIt.findAll<IOutput>();
      
      // Lazy singletons that haven't been accessed yet won't have instances
      expect(outputs.length, 0);
      
      // Access instances to create them
      final fileOutput = getIt<FileOutput>();
      final consoleOutput = getIt<ConsoleOutput>();
      
      final outputsAfterAccess = getIt.findAll<IOutput>();
      expect(outputsAfterAccess.length, 2);
      expect(outputsAfterAccess, contains(fileOutput));
      expect(outputsAfterAccess, contains(consoleOutput));
    });

    test('findAll returns empty list when no matching services exist', () {
      final getIt = GetIt.instance;
      
      getIt.registerSingleton(DatabaseService());
      
      final outputs = getIt.findAll<IOutput>();
      
      expect(outputs.isEmpty, isTrue);
    });

    test('findAll works with factories', () {
      final getIt = GetIt.instance;
      getIt.enableRegisteringMultipleInstancesOfOneType();
      
      getIt
        ..registerFactory<IOutput>(() => FileOutput())
        ..registerFactory<IOutput>(() => ConsoleOutput())
        ..registerFactory<DatabaseService>(() => DatabaseService());

      final outputs = getIt.findAll<IOutput>();
      
      // Factories don't create instances until called, so they won't be in the list initially
      expect(outputs.isEmpty, isTrue);
      
      // Create instances by calling the factories
      final fileOutput = getIt<IOutput>();
      final consoleOutput = getIt<IOutput>();
      
      // In this case, factories create new instances each time, but these instances are not stored
      // in the registry as they are not singletons or lazy singletons
      final outputsAfterAccess = getIt.findAll<IOutput>();
      expect(outputsAfterAccess.isEmpty, isTrue);
    });

    test('findAll works with mixed registration types', () {
      final getIt = GetIt.instance;
      
      getIt
        ..registerSingleton<FileOutput>(FileOutput()) // Singleton of concrete type
        ..registerSingleton<IOutput>(ConsoleOutput()) // Singleton as interface
        ..registerLazySingleton<RemoteLoggingOutput>(() => RemoteLoggingOutput()) // Lazy as concrete
        ..registerSingleton(DatabaseService());

      // Access lazy singleton to create instance
      final remoteOutput = getIt<RemoteLoggingOutput>();
      
      final outputs = getIt.findAll<IOutput>();
      
      expect(outputs.length, 3);
      expect(outputs, contains(isA<FileOutput>()));
      expect(outputs, contains(isA<ConsoleOutput>()));
      expect(outputs, contains(isA<RemoteLoggingOutput>()));
    });

    test('findAll returns type-safe list', () {
      final getIt = GetIt.instance;
      
      getIt
        ..registerSingleton(FileOutput())
        ..registerSingleton(ConsoleOutput());

      final outputs = getIt.findAll<IOutput>();
      
      // Verify we can access specific methods safely
      for (final output in outputs) {
        output.write('test message');
      }
      
      // We should also be able to access specific implementations
      final fileOutput = getIt<FileOutput>();
      fileOutput.clearFile();
    });
  });
}