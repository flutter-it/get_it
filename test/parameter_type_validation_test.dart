// ignore_for_file: unreachable_from_main

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

// Test class hierarchy
abstract class Animal {
  String get sound;
}

class Dog extends Animal {
  @override
  String get sound => 'woof';
}

class Cat extends Animal {
  @override
  String get sound => 'meow';
}

class Puppy extends Dog {
  @override
  String get sound => 'yip';
}

// Test interfaces
abstract interface class IOutput {
  void write(String data);
}

abstract interface class IDisposable {
  void dispose();
}

class FileOutput implements IOutput, IDisposable {
  @override
  void write(String data) {}

  @override
  void dispose() {}
}

class ConsoleOutput implements IOutput {
  @override
  void write(String data) {}
}

// Generic types
class Container<T> {
  final T value;
  Container(this.value);
}

// Result class for factory
class TestResult {
  final String description;
  TestResult(this.description);
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
  });

  group('Parameter validation - Subtype covariance', () {
    test('accepts subtype when expecting supertype (Dog → Animal)', () {
      GetIt.I.registerFactoryParam<TestResult, Animal, void>(
        (animal, _) => TestResult('Animal says: ${animal.sound}'),
      );

      final dog = Dog();
      final result = GetIt.I<TestResult>(param1: dog);

      expect(result.description, 'Animal says: woof');
    });

    test('accepts deep subtype (Puppy → Dog → Animal)', () {
      GetIt.I.registerFactoryParam<TestResult, Animal, void>(
        (animal, _) => TestResult('Animal says: ${animal.sound}'),
      );

      final puppy = Puppy();
      final result = GetIt.I<TestResult>(param1: puppy);

      expect(result.description, 'Animal says: yip');
    });

    test('accepts exact type match', () {
      GetIt.I.registerFactoryParam<TestResult, Dog, void>(
        (dog, _) => TestResult('Dog says: ${dog.sound}'),
      );

      final dog = Dog();
      final result = GetIt.I<TestResult>(param1: dog);

      expect(result.description, 'Dog says: woof');
    });
  });

  group('Parameter validation - Supertype rejection', () {
    test('rejects supertype when expecting subtype (Animal → Dog)', () {
      GetIt.I.registerFactoryParam<TestResult, Dog, void>(
        (dog, _) => TestResult('Dog says: ${dog.sound}'),
      );

      // Create Animal instance (not Dog)
      final Animal animal = Cat(); // Cat is sibling, not subtype of Dog

      expect(
        () => GetIt.I<TestResult>(param1: animal),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains("Cannot use parameter value of type 'Cat'"),
              contains("as type 'Dog'"),
            ),
          ),
        ),
      );
    });

    test('rejects sibling type (Cat when expecting Dog)', () {
      GetIt.I.registerFactoryParam<TestResult, Dog, void>(
        (dog, _) => TestResult('Dog says: ${dog.sound}'),
      );

      final cat = Cat();

      expect(
        () => GetIt.I<TestResult>(param1: cat),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Cannot use parameter value of type 'Cat'"),
          ),
        ),
      );
    });
  });

  group('Parameter validation - Interface implementation', () {
    test('accepts implementation when expecting interface', () {
      GetIt.I.registerFactoryParam<TestResult, IOutput, void>(
        (output, _) {
          output.write('test');
          return TestResult('Output created');
        },
      );

      final fileOutput = FileOutput();
      final result = GetIt.I<TestResult>(param1: fileOutput);

      expect(result.description, 'Output created');
    });

    test('accepts class implementing multiple interfaces', () {
      GetIt.I.registerFactoryParam<TestResult, IDisposable, void>(
        (disposable, _) {
          disposable.dispose();
          return TestResult('Disposable handled');
        },
      );

      final fileOutput =
          FileOutput(); // Implements both IOutput and IDisposable
      final result = GetIt.I<TestResult>(param1: fileOutput);

      expect(result.description, 'Disposable handled');
    });

    test('rejects class not implementing expected interface', () {
      GetIt.I.registerFactoryParam<TestResult, IDisposable, void>(
        (disposable, _) => TestResult('Disposable handled'),
      );

      final consoleOutput = ConsoleOutput(); // Only implements IOutput

      expect(
        () => GetIt.I<TestResult>(param1: consoleOutput),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains("Cannot use parameter value of type 'ConsoleOutput'"),
              contains("as type 'IDisposable'"),
            ),
          ),
        ),
      );
    });
  });

  group('Parameter validation - Generic types', () {
    test('accepts matching generic type', () {
      GetIt.I.registerFactoryParam<TestResult, Container<String>, void>(
        (container, _) => TestResult('Container holds: ${container.value}'),
      );

      final stringContainer = Container<String>('hello');
      final result = GetIt.I<TestResult>(param1: stringContainer);

      expect(result.description, 'Container holds: hello');
    });

    test('rejects different generic type parameter', () {
      GetIt.I.registerFactoryParam<TestResult, Container<String>, void>(
        (container, _) => TestResult('Container holds: ${container.value}'),
      );

      final intContainer = Container<int>(42);

      expect(
        () => GetIt.I<TestResult>(param1: intContainer),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains("Cannot use parameter value of type 'Container<int>'"),
              contains("as type 'Container<String>'"),
            ),
          ),
        ),
      );
    });

    test('accepts List with matching generic', () {
      GetIt.I.registerFactoryParam<TestResult, List<String>, void>(
        (list, _) => TestResult('List has ${list.length} items'),
      );

      final stringList = <String>['a', 'b', 'c'];
      final result = GetIt.I<TestResult>(param1: stringList);

      expect(result.description, 'List has 3 items');
    });

    test('rejects List with wrong generic type', () {
      GetIt.I.registerFactoryParam<TestResult, List<String>, void>(
        (list, _) => TestResult('List has ${list.length} items'),
      );

      final intList = <int>[1, 2, 3];

      expect(
        () => GetIt.I<TestResult>(param1: intList),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains("Cannot use parameter value of type 'List<int>'"),
              contains("as type 'List<String>'"),
            ),
          ),
        ),
      );
    });
  });

  group('Parameter validation - Both parameters', () {
    test('validates both param1 and param2 independently', () {
      GetIt.I.registerFactoryParam<TestResult, Dog, Cat>(
        (dog, cat) => TestResult('Dog: ${dog.sound}, Cat: ${cat.sound}'),
      );

      final dog = Dog();
      final cat = Cat();
      final result = GetIt.I<TestResult>(param1: dog, param2: cat);

      expect(result.description, 'Dog: woof, Cat: meow');
    });

    test('rejects wrong param1, ignores correct param2', () {
      GetIt.I.registerFactoryParam<TestResult, Dog, Cat>(
        (dog, cat) => TestResult('Should not reach here'),
      );

      final cat1 = Cat();
      final cat2 = Cat();

      expect(
        () => GetIt.I<TestResult>(param1: cat1, param2: cat2),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Cannot use parameter value of type 'Cat' as type 'Dog'"),
          ),
        ),
      );
    });

    test('rejects wrong param2, correct param1', () {
      GetIt.I.registerFactoryParam<TestResult, Dog, Cat>(
        (dog, cat) => TestResult('Should not reach here'),
      );

      final dog1 = Dog();
      final dog2 = Dog();

      expect(
        () => GetIt.I<TestResult>(param1: dog1, param2: dog2),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Cannot use parameter value of type 'Dog' as type 'Cat'"),
          ),
        ),
      );
    });

    test('accepts subtypes for both parameters', () {
      GetIt.I.registerFactoryParam<TestResult, Animal, Animal>(
        (animal1, animal2) =>
            TestResult('Animals: ${animal1.sound}, ${animal2.sound}'),
      );

      final dog = Dog();
      final cat = Cat();
      final result = GetIt.I<TestResult>(param1: dog, param2: cat);

      expect(result.description, 'Animals: woof, meow');
    });
  });

  group('Parameter validation - Async factories', () {
    test('validates subtype covariance in async factory', () async {
      GetIt.I.registerFactoryParamAsync<TestResult, Animal, void>(
        (animal, _) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return TestResult('Async Animal: ${animal!.sound}');
        },
      );

      final dog = Dog();
      final result = await GetIt.I.getAsync<TestResult>(param1: dog);

      expect(result.description, 'Async Animal: woof');
    });

    test('rejects supertype in async factory', () async {
      GetIt.I.registerFactoryParamAsync<TestResult, Dog, void>(
        (dog, _) async => TestResult('Async Dog: ${dog!.sound}'),
      );

      final cat = Cat();

      await expectLater(
        GetIt.I.getAsync<TestResult>(param1: cat),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Cannot use parameter value of type 'Cat' as type 'Dog'"),
          ),
        ),
      );
    });

    test('validates interface implementation in async factory', () async {
      GetIt.I.registerFactoryParamAsync<TestResult, IOutput, void>(
        (output, _) async {
          await Future.delayed(const Duration(milliseconds: 10));
          output!.write('async test');
          return TestResult('Async output created');
        },
      );

      final fileOutput = FileOutput();
      final result = await GetIt.I.getAsync<TestResult>(param1: fileOutput);

      expect(result.description, 'Async output created');
    });
  });

  group('Parameter validation - Cached factories', () {
    test('validates subtype in cached factory', () {
      GetIt.I.registerCachedFactoryParam<TestResult, Animal, void>(
        (animal, _) => TestResult('Cached Animal: ${animal.sound}'),
      );

      final dog = Dog();
      final result1 = GetIt.I<TestResult>(param1: dog);
      final result2 = GetIt.I<TestResult>(param1: dog); // Should return cached

      expect(result1.description, 'Cached Animal: woof');
      expect(result2, same(result1)); // Same cached instance
    });

    test('rejects wrong type in cached factory', () {
      GetIt.I.registerCachedFactoryParam<TestResult, Dog, void>(
        (dog, _) => TestResult('Cached Dog: ${dog.sound}'),
      );

      final cat = Cat();

      expect(
        () => GetIt.I<TestResult>(param1: cat),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Cannot use parameter value of type 'Cat' as type 'Dog'"),
          ),
        ),
      );
    });
  });

  group('Parameter validation - Edge cases', () {
    test('accepts null for nullable type param1', () {
      GetIt.I.registerFactoryParam<TestResult, Dog?, void>(
        (dog, _) => TestResult('Dog: ${dog?.sound ?? "null"}'),
      );

      final result = GetIt.I<TestResult>();

      expect(result.description, 'Dog: null');
    });

    test('accepts null for nullable type param2', () {
      GetIt.I.registerFactoryParam<TestResult, void, Cat?>(
        (_, cat) => TestResult('Cat: ${cat?.sound ?? "null"}'),
      );

      final result = GetIt.I<TestResult>();

      expect(result.description, 'Cat: null');
    });

    test('rejects null for non-nullable type', () {
      GetIt.I.registerFactoryParam<TestResult, Dog, void>(
        (dog, _) => TestResult('Dog: ${dog.sound}'),
      );

      expect(
        () => GetIt.I<TestResult>(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Param1 is required (non-nullable) but null was passed'),
          ),
        ),
      );
    });

    test('validates dynamic type accepts anything', () {
      GetIt.I.registerFactoryParam<TestResult, dynamic, void>(
        (param, _) => TestResult('Dynamic: ${param.runtimeType}'),
      );

      final result1 = GetIt.I<TestResult>(param1: 'string');
      final result2 = GetIt.I<TestResult>(param1: 42);
      final result3 = GetIt.I<TestResult>(param1: Dog());

      expect(result1.description, 'Dynamic: String');
      expect(result2.description, 'Dynamic: int');
      expect(result3.description, 'Dynamic: Dog');
    });

    test('validates Object type accepts any non-null object', () {
      GetIt.I.registerFactoryParam<TestResult, Object, void>(
        (obj, _) => TestResult('Object: ${obj.runtimeType}'),
      );

      final result1 = GetIt.I<TestResult>(param1: 'string');
      final result2 = GetIt.I<TestResult>(param1: Dog());
      final result3 = GetIt.I<TestResult>(param1: 123);

      expect(result1.description, 'Object: String');
      expect(result2.description, 'Object: Dog');
      expect(result3.description, 'Object: int');
    });
  });
}
