<img align="left" src="https://github.com/flutter-it/get_it/blob/master/get_it.png?raw=true" alt="get_it logo" width="150" style="margin-left: -10px;"/>

<div align="right">
  <a href="https://www.buymeacoffee.com/escamoteur"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="28" width="120"/></a>
  <br/>
  <a href="https://github.com/sponsors/escamoteur"><img src="https://img.shields.io/badge/Sponsor-❤-ff69b4?style=for-the-badge" alt="Sponsor" height="28" width="120"/></a>
</div>

<br clear="both"/>

# get_it <a href="https://codecov.io/gh/flutter-it/get_it"><img align="right" src="https://codecov.io/gh/flutter-it/get_it/branch/master/graph/badge.svg?style=for-the-badge" alt="codecov" width="200"/></a>

> 📚 **[Complete documentation available at flutter-it.dev](https://flutter-it.dev)**
> Check out the comprehensive docs with detailed guides, examples, and best practices!

**A blazing-fast service locator for Dart and Flutter that makes dependency management simple.**

As your app grows, you need a way to access services, models, and business logic from anywhere without tightly coupling your code to widget trees. `get_it` is a simple, type-safe service locator that gives you O(1) access to your objects from anywhere in your app—no `BuildContext` required, no code generation, no magic.

Think of it as a smart container that holds your app's important objects. Register them once at startup, then access them from anywhere. Simple, fast, and testable.

> **flutter_it is a construction set** — get_it works perfectly standalone or combine it with other packages like [watch_it](https://pub.dev/packages/watch_it) (state management), [command_it](https://pub.dev/packages/command_it) (commands), or [listen_it](https://pub.dev/packages/listen_it) (reactive operators). Use what you need, when you need it.

## Why get_it?

- **⚡ Blazing Fast** — O(1) lookups using Dart's native Maps. No reflection, no slow searches.
- **🎯 Type Safe** — Full compile-time type checking with generics. Errors caught before runtime.
- **🧪 Test Friendly** — Easily swap real implementations for mocks. Reset and reconfigure between tests.
- **🌳 No BuildContext** — Access your objects from anywhere—business logic, utilities, even pure Dart packages.
- **📦 Framework Agnostic** — Works in Flutter, pure Dart, server-side, CLI apps. No Flutter dependencies required.
- **🔧 Zero Boilerplate** — No code generation, no build_runner, no annotations. Just register and use.

[Learn more about the philosophy behind get_it →](https://flutter-it.dev/documentation/get_it/getting_started)

> 💡 **New to service locators?** Read Martin Fowler's classic article on [Inversion of Control Containers and the Dependency Injection pattern](https://martinfowler.com/articles/injection.html) or check out this [detailed blog post on using service locators with Flutter](https://blog.burkharts.net/one-to-find-them-all-how-to-use-service-locators-with-flutter).

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  get_it: ^8.0.2
```

### Basic Usage

```dart
import 'package:get_it/get_it.dart';

// Create a global instance (or use GetIt.instance)
final getIt = GetIt.instance;

// 1. Define your services
class ApiClient {
  Future<void> fetchData() async { /* ... */ }
}

class UserRepository {
  final ApiClient apiClient;
  UserRepository(this.apiClient);
}

// 2. Register them at app startup
void configureDependencies() {
  getIt.registerSingleton<ApiClient>(ApiClient());
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepository(getIt<ApiClient>())
  );
}

// 3. Access from anywhere in your app
class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // No BuildContext passing needed!
        getIt<UserRepository>().apiClient.fetchData();
      },
      child: Text('Fetch Data'),
    );
  }
}
```

**That's it!** Three simple steps: define, register, access.

## Key Features

### Registration Types

Choose the lifetime that fits your needs:

- **Singleton** — Create once, share everywhere. Perfect for services that maintain state.
  [Read more →](https://flutter-it.dev/documentation/get_it/object_registration#singleton)

- **LazySingleton** — Create on first access. Delays initialization until needed.
  [Read more →](https://flutter-it.dev/documentation/get_it/object_registration#lazysingleton)

- **Factory** — New instance every time. Great for stateless services or objects with short lifetimes.
  [Read more →](https://flutter-it.dev/documentation/get_it/object_registration#factory)

> **Avoid untyped tear-offs as factories.** Registering `getIt.call` (or an untyped `getIt.get` tear-off) as `registerLazySingleton<Iface>(...)` re-enters `get<Iface>()` and used to overflow the stack. GetIt now throws a clear `StateError` for that circular self-resolution. Prefer `() => getIt<Impl>()` or a named function that keeps the concrete type argument.


### Advanced Features

- **Scopes** — Create hierarchical registration scopes for different app states (login/logout, sessions, feature flags).
  [Read more →](https://flutter-it.dev/documentation/get_it/scopes)

- **Async Objects** — Register objects that need async initialization with dependency ordering.
  [Read more →](https://flutter-it.dev/documentation/get_it/async_objects)

- **Startup Orchestration** — Easily orchestrate initialization of asynchronous objects during startup.
  [Read more →](https://flutter-it.dev/documentation/get_it/async_objects)

- **Named Instances** — Register multiple implementations of the same type with different names.
  [Read more →](https://flutter-it.dev/documentation/get_it/advanced#named-instances)

- **Multiple Registrations** — Register multiple implementations and retrieve them all as a collection.
  [Read more →](https://flutter-it.dev/documentation/get_it/multiple_registrations)

### Testing Support

get_it makes testing a breeze:

- **Easy Mocking** — Replace real implementations with mocks using `allowReassignment` or `reset()`
- **Test Isolation** — `reset()` clears all registrations between tests
- **Constructor Injection** — Use optional constructor parameters to inject mocks in tests

```dart
// In tests
setUp(() {
  getIt.registerSingleton<ApiClient>(MockApiClient());
});

tearDown(() async {
  await getIt.reset();
});
```

[Read testing guide →](https://flutter-it.dev/documentation/get_it/testing)

### DevTools Extension

get_it includes a DevTools extension that lets you visualize and inspect all registered objects in your running app:

- **View all registrations** — See type, instance name, scope, registration mode, async status, ready state, and creation status
- **Instance details** — View the `toString()` output of created instances to inspect their state
- **Manual refresh** — Update the registration list anytime with the refresh button

#### Setup

1. **Enable debug events** in your app (typically in `main.dart`). This enables the extension to receive automatic updates when registrations change:
   ```dart
   void main() {
     GetIt.instance.debugEventsEnabled = true;
     // ... rest of your setup
     runApp(MyApp());
   }
   ```

2. **Run your app** in debug mode and open DevTools

3. **Open DevTools in the browser** — The extension currently only works in the browser-based DevTools, not in the IDE-embedded version.

4. **Enable the extension** — Click the **Extensions** button (puzzle piece icon) in the top right corner of DevTools and enable the `get_it` extension.

5. **Find the "get_it" tab** — The extension will appear as a new tab in DevTools

For more information on using DevTools extensions, see the [official Flutter DevTools documentation](https://docs.flutter.dev/tools/devtools/extensions).

> **💡 Tip:** Override `toString()` in your registered classes to see meaningful details in the DevTools extension. By default, Dart's `toString()` only shows the type name and instance ID.

```dart
class UserRepository {
  final String userId;
  
  @override
  String toString() => 'UserRepository(userId: $userId)';
}
```

### Flutter Widget Previews

`get_it` works seamlessly with Flutter's widget previewer. Since previews run in isolation, you need to initialize `get_it` within the preview itself:

```dart
@Preview()
Widget myPreview() {
  if (!getIt.isRegistered<MyService>()) {
    getIt.registerSingleton<MyService>(MockService());
  }
  return const MyWidget();
}
```

Or use a reusable wrapper for automatic cleanup:

```dart
@Preview(name: 'My Widget', wrapper: myWrapper)
Widget myPreview() => const MyWidget();
```

[Read Flutter previews guide →](https://flutter-it.dev/documentation/get_it/flutter_previews)

## Ecosystem Integration

**get_it works independently** — use it standalone for dependency injection in any Dart or Flutter project.

**Want more?** Combine with other packages from the flutter_it ecosystem:

- **Optional: [watch_it](https://pub.dev/packages/watch_it)** — Reactive state management built on get_it. Watch registered objects and rebuild widgets automatically.

- **Optional: [command_it](https://pub.dev/packages/command_it)** — Command pattern with loading/error states. Integrates seamlessly with get_it services.

- **Optional: [listen_it](https://pub.dev/packages/listen_it)** — ValueListenable operators (map, where, debounce). Use with objects registered in get_it.

**Remember:** flutter_it is a construction set. Each package works independently. Pick what you need, combine as you grow.

[Learn about the ecosystem →](https://flutter-it.dev)

## AI-Assisted Development

This package includes **AI skill files** in the `skills/` directory that help AI coding assistants
(Claude Code, Cursor, GitHub Copilot, and others) generate correct code using get_it.

The skill files teach AI tools critical rules, common patterns, and anti-patterns specific to get_it.
Included skills: `get-it-expert`, `flutter-architecture-expert`.

They follow the [Agent Skills](https://github.com/agentskills) open standard.

[Learn more about AI skills →](https://flutter-it.dev/misc/ai_skills)

## Learn More

### Documentation

- **[Getting Started](https://flutter-it.dev/documentation/get_it/getting_started)** — Installation, basic concepts, when to use what
- **[Object Registration](https://flutter-it.dev/documentation/get_it/object_registration)** — All registration types, parameters, disposing
- **[Scopes](https://flutter-it.dev/documentation/get_it/scopes)** — Hierarchical scopes, shadowing, scope management
- **[Async Objects](https://flutter-it.dev/documentation/get_it/async_objects)** — Async initialization, dependencies, `allReady()`
- **[Testing](https://flutter-it.dev/documentation/get_it/testing)** — Unit tests, integration tests, mocking strategies
- **[Advanced Topics](https://flutter-it.dev/documentation/get_it/advanced)** — Named instances, multiple GetIt instances, runtime types
- **[FAQ](https://flutter-it.dev/documentation/get_it/faq)** — Common questions and troubleshooting

### Community & Support

- **[Discord](https://discord.gg/ZHYHYCM38h)** — Get help, share ideas, connect with other developers
- **[GitHub Issues](https://github.com/flutter-it/get_it/issues)** — Report bugs, request features
- **[GitHub Discussions](https://github.com/flutter-it/get_it/discussions)** — Ask questions, share patterns

### Articles & Resources

- **[One to find them all: How to use Service Locators with Flutter](https://blog.burkharts.net/one-to-find-them-all-how-to-use-service-locators-with-flutter)** — Comprehensive blog post on using get_it
- **[Let's get this party started: Startup orchestration with GetIt](https://blog.burkharts.net/lets-get-this-party-started-startup-orchestration-with-getit)** — Deep dive into async initialization and startup orchestration
- **[Martin Fowler on Service Locator Pattern](https://martinfowler.com/articles/injection.html)** — Classic article on IoC and DI patterns

## Contributing

Contributions are welcome! Please read the [contributing guidelines](CONTRIBUTING.md) before submitting PRs.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgements

Many thanks to [Brian Egan](https://github.com/brianegan) and [Simon Lightfoot](https://github.com/slightfoot) for the insightful discussions on the API design.

---

**Part of the [flutter_it ecosystem](https://flutter-it.dev)** — Build reactive Flutter apps the easy way. No codegen, no boilerplate, just code.
