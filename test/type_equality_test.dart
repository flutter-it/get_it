import 'package:test/test.dart';

abstract interface class IOutput {
  void write(String message);
}

class FileOutput implements IOutput {
  @override
  void write(String message) {}
}

class EnhancedFileOutput extends FileOutput {}

// Subtype check (what we tested before)
bool isSubtype<T, S>() {
  return <T>[] is List<S>;
}

// Exact type equality check
bool isSameType<T, S>() {
  return <T>[] is List<S> && <S>[] is List<T>;
}

void main() {
  group('Type equality vs subtype distinction', () {
    test('Subtype check returns true for both exact match and subtype', () {
      // Exact match
      expect(isSubtype<FileOutput, FileOutput>(), true);

      // Subtype relationship
      expect(isSubtype<FileOutput, IOutput>(), true);
      expect(isSubtype<FileOutput, Object>(), true);
      expect(isSubtype<EnhancedFileOutput, FileOutput>(), true);

      // All return true! Can't distinguish!
    });

    test('Same type check - bidirectional test', () {
      // Exact match - both directions true
      expect(isSameType<FileOutput, FileOutput>(), true);
      expect(isSameType<IOutput, IOutput>(), true);

      // Subtype relationship - only one direction true
      expect(isSameType<FileOutput, IOutput>(), false);
      expect(isSameType<FileOutput, Object>(), false);
      expect(isSameType<EnhancedFileOutput, FileOutput>(), false);
    });

    test('Verify the bidirectional logic', () {
      // FileOutput -> IOutput: true
      expect(isSubtype<FileOutput, IOutput>(), true);
      // IOutput -> FileOutput: false (interface can't be cast to implementation)
      expect(isSubtype<IOutput, FileOutput>(), false);
      // Therefore: NOT the same type
      expect(isSameType<FileOutput, IOutput>(), false);

      // FileOutput -> FileOutput: true
      expect(isSubtype<FileOutput, FileOutput>(), true);
      // FileOutput -> FileOutput: true (same direction)
      expect(isSubtype<FileOutput, FileOutput>(), true);
      // Therefore: Same type
      expect(isSameType<FileOutput, FileOutput>(), true);
    });

    test('Practical scenario for get_it', () {
      // User registers: getIt.registerSingleton<FileOutput>(FileOutput())
      final registeredType = FileOutput;

      // Checking if registered AS IOutput (should be false)
      expect(isSameType<FileOutput, IOutput>(), false);

      // Checking if it CAN BE retrieved as IOutput (should be true)
      expect(isSubtype<FileOutput, IOutput>(), true);

      print('Registered as: FileOutput');
      print('Is registered AS IOutput? ${isSameType<FileOutput, IOutput>()}');  // false
      print('Can be retrieved as IOutput? ${isSubtype<FileOutput, IOutput>()}'); // true
    });

    test('getAll vs findAll distinction', () {
      // Simulating: getIt.registerSingleton<FileOutput>(FileOutput())

      // getAll<FileOutput>() - needs exact match
      expect(isSameType<FileOutput, FileOutput>(), true);  // ✅ Should return it

      // getAll<IOutput>() - needs exact match
      expect(isSameType<FileOutput, IOutput>(), false);    // ❌ Should NOT return it

      // findAll<FileOutput>() - accepts subtypes
      expect(isSubtype<FileOutput, FileOutput>(), true);   // ✅ Should return it

      // findAll<IOutput>() - accepts subtypes
      expect(isSubtype<FileOutput, IOutput>(), true);      // ✅ Should return it
    });

    test('Edge cases', () {
      // Child class
      expect(isSameType<EnhancedFileOutput, FileOutput>(), false);  // Not same
      expect(isSubtype<EnhancedFileOutput, FileOutput>(), true);    // But is subtype

      // Object
      expect(isSameType<FileOutput, Object>(), false);   // Not same
      expect(isSubtype<FileOutput, Object>(), true);     // But is subtype

      // Interface
      expect(isSameType<IOutput, Object>(), false);
      expect(isSubtype<IOutput, Object>(), true);
    });
  });

  group('Simulated ObjectRegistration', () {
    test('Registration can distinguish exact vs subtype', () {
      final fileReg = SimulatedRegistration<FileOutput>();

      // Exact match
      expect(fileReg.isExactType<FileOutput>(), true);

      // Implements interface but not exact
      expect(fileReg.isExactType<IOutput>(), false);
      expect(fileReg.implementsType<IOutput>(), true);

      // Inherits from Object but not exact
      expect(fileReg.isExactType<Object>(), false);
      expect(fileReg.implementsType<Object>(), true);
    });
  });
}

class SimulatedRegistration<T> {
  // For getAll() - exact type match only
  bool isExactType<S>() {
    return <T>[] is List<S> && <S>[] is List<T>;
  }

  // For findAll() - subtype relationship
  bool implementsType<S>() {
    return <T>[] is List<S>;
  }
}
