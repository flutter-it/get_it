// ignore_for_file: unreachable_from_main

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
  void write(String message) {
    // ignore: avoid_print
    print('File: $message');
  }
}

class ConsoleOutput implements IOutput, IDisposable {
  @override
  void write(String message) {
    // ignore: avoid_print
    print('Console: $message');
  }

  @override
  void dispose() {
    // ignore: avoid_print
    print('Disposing console');
  }
}

class DatabaseService {
  void save(String data) {
    // ignore: avoid_print
    print('Saving: $data');
  }
}

class EnhancedFileOutput extends FileOutput implements IDisposable {
  @override
  void dispose() {
    // ignore: avoid_print
    print('Disposing file');
  }
}

// The trick!
bool isSubtype<T, S>() {
  return <T>[] is List<S>;
}

void main() {
  group('Type checking trick tests', () {
    test('Basic interface implementation check', () {
      expect(isSubtype<FileOutput, IOutput>(), true);
      expect(isSubtype<ConsoleOutput, IOutput>(), true);
      expect(isSubtype<DatabaseService, IOutput>(), false);
    });

    test('Multiple interface implementation', () {
      expect(isSubtype<ConsoleOutput, IOutput>(), true);
      expect(isSubtype<ConsoleOutput, IDisposable>(), true);
      expect(isSubtype<FileOutput, IDisposable>(), false);
    });

    test('Inheritance check', () {
      expect(isSubtype<EnhancedFileOutput, FileOutput>(), true);
      expect(isSubtype<EnhancedFileOutput, IOutput>(), true);
      expect(isSubtype<EnhancedFileOutput, IDisposable>(), true);
      expect(isSubtype<FileOutput, EnhancedFileOutput>(), false);
    });

    test('Object supertype check', () {
      expect(isSubtype<FileOutput, Object>(), true);
      expect(isSubtype<ConsoleOutput, Object>(), true);
      expect(isSubtype<DatabaseService, Object>(), true);
      expect(isSubtype<Object, FileOutput>(), false);
    });

    test('Same type check', () {
      expect(isSubtype<FileOutput, FileOutput>(), true);
      expect(isSubtype<IOutput, IOutput>(), true);
    });

    test('Unrelated types', () {
      expect(isSubtype<FileOutput, DatabaseService>(), false);
      expect(isSubtype<DatabaseService, FileOutput>(), false);
      expect(isSubtype<String, int>(), false);
    });

    test('Built-in types', () {
      expect(isSubtype<String, Object>(), true);
      expect(isSubtype<int, num>(), true);
      expect(isSubtype<double, num>(), true);
      expect(isSubtype<num, int>(), false);
      expect(isSubtype<String, Comparable>(), true);
    });

    test('Works with generics in real scenario', () {
      // Simulating what we'd do in _ObjectRegistration<T>
      bool checkIfTypeImplements<T, S>() {
        return <T>[] is List<S>;
      }

      // Simulating registrations
      expect(checkIfTypeImplements<FileOutput, IOutput>(), true);
      expect(checkIfTypeImplements<ConsoleOutput, IOutput>(), true);
      expect(checkIfTypeImplements<DatabaseService, IOutput>(), false);
      expect(checkIfTypeImplements<ConsoleOutput, IDisposable>(), true);
    });
  });

  group('Practical application test', () {
    test('Filter types by interface', () {
      final registeredTypes = [
        FileOutput,
        ConsoleOutput,
        DatabaseService,
        EnhancedFileOutput,
      ];

      // Find all types that implement IOutput
      final outputTypes = registeredTypes.where((type) {
        // We can't directly check Type objects, so we need a helper
        // In real code, the _ObjectRegistration would be generic <T>
        // and could use the trick internally
        return type == FileOutput && isSubtype<FileOutput, IOutput>() ||
            type == ConsoleOutput && isSubtype<ConsoleOutput, IOutput>() ||
            type == DatabaseService && isSubtype<DatabaseService, IOutput>() ||
            type == EnhancedFileOutput &&
                isSubtype<EnhancedFileOutput, IOutput>();
      }).toList();

      expect(outputTypes.length, 3);
      expect(outputTypes.contains(FileOutput), true);
      expect(outputTypes.contains(ConsoleOutput), true);
      expect(outputTypes.contains(EnhancedFileOutput), true);
      expect(outputTypes.contains(DatabaseService), false);
    });

    test('Simulated ObjectRegistration with type checking', () {
      // Simulating how _ObjectRegistration could use this
      final fileReg = SimulatedRegistration<FileOutput>();
      final consoleReg = SimulatedRegistration<ConsoleOutput>();
      final dbReg = SimulatedRegistration<DatabaseService>();

      expect(fileReg.implementsType<IOutput>(), true);
      expect(consoleReg.implementsType<IOutput>(), true);
      expect(dbReg.implementsType<IOutput>(), false);

      expect(consoleReg.implementsType<IDisposable>(), true);
      expect(fileReg.implementsType<IDisposable>(), false);
    });
  });
}

// Simulating _ObjectRegistration to show how it would work
class SimulatedRegistration<T> {
  bool implementsType<S>() {
    return <T>[] is List<S>;
  }

  Type get registeredType => T;
}
