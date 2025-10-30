# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

**get_it** is a simple, fast (O(1)) Service Locator for Dart and Flutter projects. It provides dependency injection capabilities without code generation or reflection.

**Key characteristics:**
- Pure Dart package (no Flutter dependency required)
- No code generation or build_runner
- Extremely fast O(1) lookup using Dart Maps
- Type-safe with compile-time checking
- Supports multiple registration types: factories, singletons, lazy singletons

## Development Commands

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/get_it_test.dart
flutter test test/async_test.dart
flutter test test/scope_test.dart

# Run tests with verbose output
flutter test --verbose
```

### Code Quality

```bash
# Analyze code
flutter analyze

# Format code
dart format .

# Publish dry-run (check before publishing)
flutter pub publish --dry-run
```

### Example App

```bash
# Run the example app
cd example
flutter run

# Return to package root
cd ..
```

## Core Architecture

### Registration System

GetIt uses a **hierarchical scope system** with type-based registration:

1. **Base scope** - Default scope, always exists
2. **Pushed scopes** - Stack of scopes that can shadow lower scope registrations
3. **Type registration** - Each type can have multiple registrations (unnamed or named instances)

### Key Data Structures

- **`_GetItImplementation`** - Singleton implementation of the GetIt interface
- **`_Scope`** - Represents a registration scope with its own object registry
- **`_ObjectRegistration<T, P1, P2>`** - Holds registration metadata and instances
  - Stores creation functions (sync/async, with/without parameters)
  - Manages instance lifecycle (creation, disposal, ready state)
  - Tracks dependencies and ready signals
- **`_TypeRegistration`** - Maps types to their object registrations within a scope

### Registration Types

```dart
enum ObjectRegistrationType {
  alwaysNew,      // Factory - creates new instance on every get()
  constant,       // Singleton - single instance passed at registration
  lazy,           // Lazy singleton - created on first get()
  cachedFactory,  // Factory with weak reference caching
}
```

### Lookup Algorithm

When `get<T>()` is called:

1. Start from topmost scope
2. Look for type `T` with optional `instanceName`
3. If not found, move down to parent scope
4. Repeat until found or base scope exhausted
5. If still not found, throw error

This enables **shadowing**: registering the same type in a higher scope overrides lower scope registrations.

### Async Initialization

GetIt supports complex async initialization patterns:

- **`registerSingletonAsync`** - Async factory that runs immediately
- **`registerLazySingletonAsync`** - Async factory that runs on first access
- **`dependsOn`** - Declare initialization dependencies
- **`signalsReady`** - Manual ready signaling for complex initialization
- **`allReady()`** - Wait for all async singletons to complete
- **`isReady<T>()`** - Wait for specific singleton to be ready

### Scoping

Scopes enable managing different object lifetimes (e.g., app-level vs session-level):

```dart
// Push new scope (e.g., on user login)
GetIt.I.pushNewScope(scopeName: 'userSession');

// Register objects in this scope
GetIt.I.registerSingleton<UserService>(LoggedInUserService());

// Pop scope when done (e.g., on logout) - disposes all objects in scope
await GetIt.I.popScope();
```

### Disposal

Objects can be disposed when unregistered or when scopes are popped:

1. **Disposable interface** - Implement `Disposable.onDispose()` for automatic disposal
2. **Dispose function** - Pass `dispose` parameter during registration
3. **Scope dispose** - Pass `dispose` callback when pushing scope

## Implementation Details

### Instance Storage

- Regular instances stored in `_ObjectRegistration._instance`
- Weak references supported via `weakReferenceInstance` for cached factories and lazy singletons
- Instance retrieval checks weak reference first, then falls back to strong reference

### Ready State Management

- Each registration has a `_readyCompleter` that tracks initialization state
- `shouldSignalReady` flag determines if manual signaling is required
- `pendingResult` stores the Future for ongoing async creation
- `objectsWaiting` tracks which types depend on this registration

### Reference Counting

For recursive scenarios (e.g., pushing same page multiple times):

- `registerSingletonIfAbsent` increments reference count if already registered
- `releaseInstance` decrements count and only disposes when reaching zero
- Prevents premature disposal in nested navigation scenarios

## Testing Patterns

### Unit Tests

Each test file focuses on a specific feature area:

- `get_it_test.dart` - Core registration and retrieval
- `async_test.dart` - Async singletons and initialization
- `scope_test.dart` - Scope management and shadowing
- `skip_double_registration_test.dart` - Double registration behavior

### Test Setup

```dart
void main() {
  setUp(() async {
    // Reset GetIt before each test
    await GetIt.I.reset();
  });

  test('description', () {
    // Test code
  });
}
```

### Common Test Patterns

```dart
// Test factory registration
GetIt.I.registerFactory<MyClass>(() => MyClass());
expect(GetIt.I<MyClass>(), isA<MyClass>());
expect(GetIt.I<MyClass>(), isNot(same(GetIt.I<MyClass>()))); // Different instances

// Test singleton registration
final instance = MyClass();
GetIt.I.registerSingleton(instance);
expect(GetIt.I<MyClass>(), same(instance)); // Same instance

// Test async initialization
GetIt.I.registerSingletonAsync<MyService>(() async => MyService());
await GetIt.I.allReady();
expect(GetIt.I.isReadySync<MyService>(), true);
```

## Package Structure

```
lib/
  get_it.dart          # Public API and interfaces
  get_it_impl.dart     # Implementation (part of get_it.dart)
test/
  get_it_test.dart     # Core functionality tests
  async_test.dart      # Async initialization tests
  scope_test.dart      # Scope management tests
example/
  lib/main.dart        # Example Flutter app
```

## API Design Principles

1. **Type-based access** - Primary access via generics: `GetIt.I<MyType>()`
2. **Optional callable class** - Can call GetIt instance directly: `getIt<MyType>()`
3. **Named registrations** - Optional `instanceName` for multiple instances of same type
4. **Runtime type support** - Rare `type` parameter for dynamic type access
5. **No BuildContext required** - Unlike InheritedWidget/Provider, accessible from anywhere

## Common Patterns

### Basic Setup

```dart
final getIt = GetIt.instance;

void setupLocator() {
  // Register services
  getIt.registerLazySingleton<ApiService>(() => ApiService());
  getIt.registerSingleton<ConfigService>(ConfigService());

  // Register with dependencies
  getIt.registerSingletonWithDependencies<AppModel>(
    () => AppModel(getIt<ApiService>()),
    dependsOn: [ApiService],
  );
}
```

### Testing Mock Objects

```dart
// In production code
class UserManager {
  final ApiService api;
  UserManager({ApiService? api}) : api = api ?? GetIt.I<ApiService>();
}

// In tests - inject mock
final mockApi = MockApiService();
final userManager = UserManager(api: mockApi);
```

### Multiple Implementations

```dart
// Enable feature first
getIt.enableRegisteringMultipleInstancesOfOneType();

// Register multiple implementations
getIt.registerLazySingleton<PaymentProcessor>(() => StripeProcessor());
getIt.registerLazySingleton<PaymentProcessor>(() => PayPalProcessor());

// Get all implementations
final processors = getIt.getAll<PaymentProcessor>();
```

## Version Information

Current version: 8.2.0

See CHANGELOG.md for detailed version history and breaking changes.

## Related Packages

- **watch_it** - State management built on get_it (reactive observers)
- **command_it** - Command pattern with automatic loading/error states
- **listen_it** - ValueListenable operators for reactive programming

## Documentation

- README.md - Comprehensive usage documentation
- https://flutter-it.dev - Official documentation site
- https://www.burkharts.net/apps/blog/one-to-find-them-all-how-to-use-service-locators-with-flutter/ - Detailed blog post
- don't commit without first run dart analyse to make sure no warnings exist