---
name: get-it-expert
description: Expert guidance on get_it service locator and dependency injection for Flutter/Dart. Covers registration (singleton, factory, lazy, async), scopes with shadowing, async initialization with init() pattern, retrieval, testing with scope-based mocking, and production patterns. Use when working with get_it, dependency injection, service registration, scopes, or async initialization.
metadata:
  author: flutter-it
  version: "1.0"
---

# get_it Expert - Service Locator & Dependency Injection

**What**: Type-safe service locator with O(1) lookup. Register services globally, retrieve anywhere without BuildContext. Pure Dart, no code generation.

## CRITICAL RULES

- Register all services BEFORE `runApp()`
- `pushNewScope()` is synchronous. Use `pushNewScopeAsync()` for async init
- `popScope()` IS async (returns `Future<void>`)
- `allReady()` returns `Future<void>` - await it or use FutureBuilder/watch_it
- Dispose callbacks are a parameter on registration methods, not separate methods
- Once async singletons are initialized (after `allReady()`), access them with normal `getIt<T>()` - no `getAsync` needed
- If using watch_it, a global `di` alias for `GetIt.I` is already provided - use `di<T>()` instead of `getIt<T>()`

## Registration

```dart
final getIt = GetIt.instance;

void configureDependencies() {
  // Singleton - created immediately
  getIt.registerSingleton<ApiClient>(ApiClient());

  // Singleton with dispose callback
  getIt.registerSingleton<StreamController>(
    StreamController(),
    dispose: (c) => c.close(),
  );

  // Lazy singleton - created on first access
  getIt.registerLazySingleton<Database>(() => Database());

  // Factory - new instance every call
  getIt.registerFactory<Logger>(() => Logger());

  // Factory with parameters
  getIt.registerFactoryParam<Logger, String, void>(
    (tag, _) => Logger(tag),
  );

  // Named instances - use when registering multiple instances of the same type
  getIt.registerSingleton<Config>(devConfig, instanceName: 'dev');
  getIt.registerSingleton<Config>(prodConfig, instanceName: 'prod');
}
```

## Async Initialization

**Preferred pattern**: Give services a `Future<T> init()` method that returns `this`. This keeps initialization logic inside the class and allows concise registration:

```dart
class DatabaseService {
  late final Database _db;

  Future<DatabaseService> init() async {
    _db = await Database.open('app.db');
    return this;  // Always return this
  }
}

void configureDependencies() {
  // init() pattern - concise, self-contained initialization
  getIt.registerSingletonAsync<DatabaseService>(
    () => DatabaseService().init(),
  );

  // With dependency ordering
  getIt.registerSingletonAsync<ApiClient>(
    () => ApiClient().init(),
    dependsOn: [DatabaseService],
  );

  // Sync factory that needs async dependencies
  getIt.registerSingletonWithDependencies<AppModel>(
    () => AppModel(getIt<ApiClient>()),
    dependsOn: [ApiClient],
  );
}
```

## Retrieval

```dart
final api = getIt<ApiClient>();                        // get<T>() - throws if missing
final api = getIt.maybeGet<ApiClient>();                // returns null if missing
final api = await getIt.getAsync<ApiClient>();          // waits for async registration
final all = getIt.getAll<PaymentProcessor>();           // all instances of type
final config = getIt<Config>(instanceName: 'dev');      // named instance
final logger = getIt<Logger>(param1: 'MyClass');        // factory with params
```

## Scopes

```dart
// Push scope (synchronous init)
getIt.pushNewScope(
  scopeName: 'user-session',
  init: (getIt) {
    getIt.registerSingleton<UserData>(currentUser);
    getIt.registerLazySingleton<UserPrefs>(() => UserPrefs(currentUser.id));
  },
);

// Push scope (async init)
await getIt.pushNewScopeAsync(
  scopeName: 'user-session',
  init: (getIt) async {
    final prefs = await UserPrefs.load(currentUser.id);
    getIt.registerSingleton<UserPrefs>(prefs);
  },
);

// Pop scope (always async - calls dispose callbacks)
await getIt.popScope();

// Pop multiple scopes
await getIt.popScopesTill('base-scope', inclusive: false);

// Drop specific scope by name
await getIt.dropScope('user-session');

// Query scopes
getIt.hasScope('user-session');    // bool
getIt.currentScopeName;            // String?
```

**Scope shadowing**: Scopes are a stack of registration layers. When you register a type in a new scope that already exists in a lower scope, the new registration **shadows** (hides) the original. `getIt<T>()` always searches **top-down**, returning the first match. Popping a scope removes its registrations and restores access to the shadowed ones below. This is what makes scopes useful for testing (push a scope with mocks, pop it in tearDown), for user sessions (push user-specific services that shadow defaults), and for grouping related objects that should be disposed together based on business logic (e.g., push a scope for a shopping cart - popping it disposes all cart-related services at once).

## Ready State

```dart
// Wait for ALL async registrations
await getIt.allReady(timeout: Duration(seconds: 10));

// Wait for specific type
await getIt.isReady<Database>(timeout: Duration(seconds: 5));

// Synchronous checks (no waiting)
getIt.allReadySync();              // bool
getIt.isReadySync<Database>();     // bool
```

**UI integration**: Use `FutureBuilder` with `getIt.allReady()` to show a splash screen while async services initialize. If using watch_it, prefer its `allReady()` function inside a `WatchingWidget` instead (see watch-it-expert skill).

## Reference Counting

For scenarios like recursive navigation (same page pushed multiple times):

```dart
// Registers only if not already registered, increments ref count
getIt.registerSingletonIfAbsent<PageData>(() => PageData(id));

// Decrements ref count, disposes only when count reaches 0
getIt.releaseInstance<PageData>(ignoreReferenceCount: false);
```

## Utility Methods

```dart
getIt.isRegistered<ApiClient>();                       // bool
getIt.unregister<ApiClient>();                         // remove registration
getIt.resetLazySingleton<Database>();                  // recreate on next access
getIt.resetLazySingletons(inAllScopes: true);          // bulk reset
getIt.checkLazySingletonInstanceExists<Database>();    // is it instantiated?
getIt.reset();                                         // clear everything (for tests)
getIt.allowReassignment = true;                        // allow overwriting registrations
getIt.enableRegisteringMultipleInstancesOfOneType();   // allow unnamed multiples
```

## Anti-Patterns

```dart
// ❌ Accessing async service before allReady()
configureDependencies();
final db = getIt<Database>();  // THROWS - not ready yet

// ✅ Wait first
await getIt.allReady();
final db = getIt<Database>();  // Safe

// ❌ await on pushNewScope (it's void, not Future)
await getIt.pushNewScope(scopeName: 'x');  // Won't compile

// ✅ Use pushNewScopeAsync for async init
await getIt.pushNewScopeAsync(
  scopeName: 'x',
  init: (getIt) async { ... },
);
// OR use synchronous pushNewScope without await
getIt.pushNewScope(scopeName: 'x', init: (getIt) { ... });
```

## Testing

```dart
// Option 1: Scope-based (preferred) - mocks shadow real registrations
setUp(() {
  GetIt.I.pushNewScope(
    init: (getIt) {
      getIt.registerSingleton<ApiClient>(MockApiClient());
    },
  );
});
tearDown(() async {
  await GetIt.I.popScope();
});

// Option 2: Hybrid constructor injection (optional convenience)
class MyService {
  final ApiClient api;
  MyService({ApiClient? api}) : api = api ?? getIt<ApiClient>();
}
// Test: MyService(api: MockApiClient())
```

## Production Patterns

**Two-phase DI** (base + throwable scope):
```dart
void setupBaseServices() {
  di.registerSingleton<ApiClient>(createApiClient());
  di.registerSingleton<CacheManager>(WcImageCacheManager());
}

Future<void> setupThrowableScope() async {
  di.pushNewScope(scopeName: 'throwableScope');
  di.registerLazySingletonAsync<StoryManager>(
    () async => StoryManager().init(),
    dispose: (m) => m.dispose(),
    dependsOn: [UserManager],
  );
}

// On error recovery: reset throwable scope
await di.popScopesTill('throwableScope', inclusive: true);
await setupThrowableScope();
```
