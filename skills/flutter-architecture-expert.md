# flutter_it Architecture Expert - App Structure & Patterns

**What**: Architecture guidance for Flutter apps using the flutter_it construction set (get_it + watch_it + command_it + listen_it).

## App Startup

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();  // Register all services (sync)
  runApp(MyApp());
}

// Splash screen waits for async services
class SplashScreen extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    final ready = allReady(
      onReady: (context) => Navigator.pushReplacement(context, mainRoute),
    );
    if (!ready) return CircularProgressIndicator();
    return MainApp();
  }
}
```

## Pragmatic Flutter Architecture (PFA)

Three components: **Services** (external boundaries), **Managers** (business logic), **Views** (self-responsible UI).

- **Services**: Wrap ONE external aspect (REST API, database, OS service, hardware). Convert data from/to external formats (JSON). Do NOT change app state.
- **Managers**: Wrap semantically related business logic (UserManager, BookingManager). NOT ViewModels - don't map 1:1 to views. Provide Commands/ValueListenables for the UI. Use Services or other Managers.
- **Views**: Full pages or high-level widgets. Self-responsible - know what data they need. Read data from Managers via ValueListenables. Modify data through Managers, never directly through Services.

## Project Structure (by feature, NOT by layer)

```
lib/
  _shared/                   # Shared across features (prefix _ sorts to top)
    services/                # Cross-feature services
    widgets/                 # Reusable widgets
    models/                  # Shared domain objects
  features/
    auth/
      pages/                 # Full-screen views
      widgets/               # Feature-specific widgets
      manager/               # AuthManager, commands
      model/                 # User, UserProxy, DTOs
      services/              # AuthApiService
    chat/
      pages/
      widgets/
      manager/
      model/
      services/
  locator.dart               # DI configuration (get_it registrations)
```

**Key rules**:
- Organize by features, not by layers
- Only move a component to `_shared/` if multiple features need it
- No interface classes by default - only if you know you'll have multiple implementations

## Manager Pattern

Managers encapsulate semantically related business logic, registered in get_it. They provide Commands and ValueListenables for the UI:

```dart
class UserManager extends ChangeNotifier {
  final _userState = ValueNotifier<UserState>(UserState.loggedOut);
  ValueListenable<UserState> get userState => _userState;

  late final loginCommand = Command.createAsync<LoginRequest, User>(
    (request) async {
      final api = di<ApiClient>();
      return await api.login(request);
    },
    initialValue: User.empty(),
    errorFilter: const GlobalIfNoLocalErrorFilter(),
  );

  late final logoutCommand = Command.createAsyncNoParamNoResult(
    () async { await di<ApiClient>().logout(); },
  );

  void dispose() { /* cleanup */ }
}

// Register
di.registerLazySingleton<UserManager>(
  () => UserManager(),
  dispose: (m) => m.dispose(),
);

// Use in widget
class LoginWidget extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    final isRunning = watch(di<UserManager>().loginCommand.isRunning).value;
    registerHandler(
      select: (UserManager m) => m.loginCommand.errors,
      handler: (context, error, _) {
        showErrorSnackbar(context, error.error);
      },
    );
    return ElevatedButton(
      onPressed: isRunning ? null : () => di<UserManager>().loginCommand.run(request),
      child: isRunning ? CircularProgressIndicator() : Text('Login'),
    );
  }
}
```

## Scoped Services (User Sessions)

```dart
// Base services (survive errors)
void setupBaseServices() {
  di.registerSingleton<ApiClient>(createApiClient());
  di.registerSingleton<CacheManager>(WcImageCacheManager());
}

// Throwable scope (can be reset on errors)
void setupThrowableScope() {
  di.pushNewScope(scopeName: 'throwable');
  di.registerLazySingletonAsync<StoryManager>(
    () async => StoryManager().init(),
    dispose: (m) => m.dispose(),
    dependsOn: [UserManager],
  );
}

// User session scope (created at login, destroyed at logout)
void createUserSession(User user) {
  di.pushNewScope(
    scopeName: 'user-session',
    init: (getIt) {
      getIt.registerSingleton<User>(user);
      getIt.registerLazySingleton<UserPrefs>(() => UserPrefs(user.id));
    },
  );
}

Future<void> logout() async {
  await di.popScope();  // Disposes user-session services
}
```

## Proxy Pattern

Proxies wrap DTO types with reactive behavior - computed properties, commands, and change notification. The DTO holds raw data, the proxy adds the "smart" layer on top.

```dart
// Simple proxy - wraps a DTO, adds behavior
class UserProxy extends ChangeNotifier {
  UserProxy(this._user);

  UserDto _user;
  UserDto get user => _user;

  // Update underlying data, notify watchers
  set user(UserDto value) {
    _user = value;
    notifyListeners();
  }

  // Computed properties over the DTO
  String get displayName => '${_user.firstName} ${_user.lastName}';
  bool get isVerified => _user.verificationStatus == 'verified';

  // Commands for operations on this entity
  late final toggleFollowCommand = Command.createAsyncNoParamNoResult(
    () async {
      await di<ApiClient>().toggleFollow(_user.id);
    },
    errorFilter: const GlobalIfNoLocalErrorFilter(),
  );

  late final updateAvatarCommand = Command.createAsyncNoResult<File>(
    (file) async {
      _user = await di<ApiClient>().uploadAvatar(_user.id, file);
      notifyListeners();
    },
  );
}

// Use in widget - watch the proxy for reactive updates
class UserCard extends WatchingWidget {
  final UserProxy user;
  @override
  Widget build(BuildContext context) {
    watch(user);  // Rebuild when proxy notifies
    final isFollowing = watch(user.toggleFollowCommand.isRunning).value;
    return Column(children: [
      Text(user.displayName),
      if (user.isVerified) Icon(Icons.verified),
    ]);
  }
}
```

**Optimistic UI updates with override pattern** - don't modify the DTO, use override fields that sit on top:
```dart
class PostProxy extends ChangeNotifier {
  PostProxy(this._target);
  PostDto _target;

  // Override field - nullable, sits on top of DTO value
  bool? _likeOverride;

  // Getter returns override if set, otherwise falls back to DTO
  bool get isLiked => _likeOverride ?? _target.isLiked;
  String get title => _target.title;

  // Update target from API clears all overrides
  set target(PostDto value) {
    _likeOverride = null;  // Clear override on fresh data
    _target = value;
    notifyListeners();
  }

  // Simple approach: set override, invert on error
  late final toggleLikeCommand = Command.createAsyncNoParamNoResult(
    () async {
      _likeOverride = !isLiked;  // Instant UI update
      notifyListeners();
      if (_likeOverride!) {
        await di<ApiClient>().likePost(_target.id);
      } else {
        await di<ApiClient>().unlikePost(_target.id);
      }
    },
    restriction: commandRestrictions,
    errorFilter: const LocalAndGlobalErrorFilter(),
  )..errors.listen((e, _) {
      _likeOverride = !_likeOverride!;  // Invert back on error
      notifyListeners();
    });

  // Or use UndoableCommand for automatic rollback
  late final toggleLikeUndoable = Command.createUndoableNoParamNoResult<bool>(
    (undoStack) async {
      undoStack.push(isLiked);  // Save current state
      _likeOverride = !isLiked;
      notifyListeners();
      if (_likeOverride!) {
        await di<ApiClient>().likePost(_target.id);
      } else {
        await di<ApiClient>().unlikePost(_target.id);
      }
    },
    undo: (undoStack, reason) {
      _likeOverride = undoStack.pop();  // Restore previous state
      notifyListeners();
    },
  );
}
```
**Key rules for optimistic updates in proxies**:
- NEVER use `copyWith` on DTOs - use nullable override fields instead
- Getter returns `_override ?? _target.field` (override wins, falls back to DTO)
- On API refresh: clear all overrides, update target
- On error: invert the override (simple) or pop from undo stack (UndoableCommand)

**Proxy with smart fallbacks** (loaded vs initial data):
```dart
class PodcastProxy extends ChangeNotifier {
  PodcastProxy({required this.item});
  final SearchItem item;  // Initial lightweight data

  Podcast? _podcast;  // Full data loaded later
  List<Episode>? _episodes;

  // Getters fall back to initial data if full data not yet loaded
  String? get title => _podcast?.title ?? item.collectionName;
  String? get image => _podcast?.image ?? item.bestArtworkUrl;

  late final fetchCommand = Command.createAsyncNoParam<List<Episode>>(
    () async {
      if (_episodes != null) return _episodes!;  // Cache
      final result = await di<PodcastService>().findEpisodes(item: item);
      _podcast = result.podcast;
      _episodes = result.episodes;
      return _episodes!;
    },
    initialValue: [],
  );
}
```

### Advanced: DataRepository with Reference Counting

When the same entity appears in multiple places (feeds, detail pages, search results), use a repository to deduplicate proxies and manage their lifecycle via reference counting:

```dart
abstract class DataProxy<T> extends ChangeNotifier {
  DataProxy(this._target);
  T _target;
  int _referenceCount = 0;

  T get target => _target;
  set target(T value) { _target = value; notifyListeners(); }

  @override
  void dispose() {
    assert(_referenceCount == 0);
    super.dispose();
  }
}

abstract class DataRepository<T, TProxy extends DataProxy<T>, TId> {
  final _proxies = <TId, TProxy>{};

  TId identify(T item);
  TProxy makeProxy(T entry);

  // Returns existing proxy (updated) or creates new one
  TProxy createProxy(T item) {
    final id = identify(item);
    if (!_proxies.containsKey(id)) {
      _proxies[id] = makeProxy(item);
    } else {
      _proxies[id]!.target = item;  // Update with fresh data
    }
    _proxies[id]!._referenceCount++;
    return _proxies[id]!;
  }

  void releaseProxy(TProxy proxy) {
    proxy._referenceCount--;
    if (proxy._referenceCount == 0) {
      proxy.dispose();
      _proxies.remove(identify(proxy.target));
    }
  }
}
```

**Reference counting flow**:
```
Feed creates ChatProxy(id=1) → refCount=1
Page opens same proxy         → refCount=2
Page closes, releases         → refCount=1 (proxy stays for feed)
Feed refreshes, releases      → refCount=0 (proxy disposed)
```

## Feed/DataSource Pattern

For paginated lists and infinite scroll, see the dedicated `/skills/feed-datasource-expert.md` skill. Key concepts: `FeedDataSource<TItem>` (non-paged) and `PagedFeedDataSource<TItem>` (cursor-based pagination) with separate Commands for initial load vs pagination, auto-pagination at `items.length - 3`, and proxy reference counting on refresh.

## Widget Granularity

A widget watching multiple objects is perfectly fine. Only split into smaller WatchingWidgets when watched values change at **different frequencies** and the rebuild is costly. Keep a balance - don't over-split. Only widgets that watch values should be WatchingWidgets:

```dart
// ✅ Parent doesn't watch - plain StatelessWidget
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [_Header(), _Counter()]);
  }
}

// Each child watches only what IT needs
class _Header extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    final user = watchValue((Auth x) => x.currentUser);
    return Text(user.name);
  }
}
class _Counter extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    final count = watchValue((Counter x) => x.count);
    return Text('$count');
  }
}
// Result: user change only rebuilds _Header, count change only rebuilds _Counter
```

**Note**: When working with Listenable, ValueListenable, ChangeNotifier, or ValueNotifier, check the listen_it skill for `listen()` and reactive operators (map, debounce, where, etc.).

## Testing

```dart
// Option 1: get_it scopes for mocking
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
  MyService({ApiClient? api}) : api = api ?? di<ApiClient>();
}
// Test: MyService(api: MockApiClient())
```

## Best Practices

- Register all services before `runApp()`
- Use `allReady()` with watch_it or FutureBuilder for async services
- Break UI into small WatchingWidgets (only watch what you need)
- Use managers (ChangeNotifier/ValueNotifier subclasses) for state
- Use commands for async operations with loading/error states
- Use scopes for user sessions and resettable services
- Use `createOnce()` for widget-local disposable objects
- Use `registerHandler()` for side effects (dialogs, navigation, snackbars)
- Use `run()` not `execute()` on commands
- Use proxies to wrap DTOs with reactive behavior (commands, computed properties, change notification)
- Use DataRepository with reference counting when same entity appears in multiple places
