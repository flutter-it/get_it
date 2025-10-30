[![Flutter Community: get_it](https://fluttercommunity.dev/_github/header/get_it)](https://github.com/fluttercommunity/community)
[![codecov](https://codecov.io/gh/flutter-it/get_it/branch/master/graph/badge.svg)](https://codecov.io/gh/flutter-it/get_it)

[:heart: Sponsor](https://github.com/sponsors/escamoteur) <a href="https://www.buymeacoffee.com/escamoteur" target="_blank"><img align="right" src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

# get_it

>Check out my new package [watch_it](https://github.com/escamoteur/watch_it) the state management addon to get_it
>There is now a discord support channel for my packages https://discord.gg/ZHYHYCM38h

This is a simple **Service Locator** for Dart and Flutter projects with some additional goodies highly inspired by [Splat](https://github.com/reactiveui/splat). It can be used instead of `InheritedWidget` or `Provider` to access objects e.g. from your UI.

Typical usage:

- Accessing service objects like REST API clients or databases so that they easily can be mocked.
- Accessing View/AppModels/Managers/BLoCs from Flutter Views



## Why GetIt

As your App grows, at some point you will need to put your app's logic in classes that are separated from your Widgets. Keeping your widgets from having direct dependencies makes your code better organized and easier to test and maintain.
But now you need a way to access these objects from your UI code. When I came to Flutter from the .Net world, the only way to do this was the use of InheritedWidgets. I found the way to use them by wrapping them in a StatefulWidget; quite cumbersome and have problems working consistently. Also:

- I missed the ability to easily switch the implementation for a mocked version without changing the UI.
- The fact that you need a `BuildContext` to access your objects made it inaccessible from the Business layer.

Accessing an object from anywhere in an App can be done in other ways, but:

- If you use a Singleton you can't easily switch the implementation out for a mock version in tests
- IoC containers for Dependency Injections offer similar functionality, but with the cost of slow start-up time and less readability because you don't know where the magically injected object comes from. Most IoC libs rely on reflection they cannot be ported to Flutter.

As I was used to using the Service Locator _Splat_ from .Net, I decided to port it to Dart. Since then, more features have been added.

> If you are not familiar with the concept of Service Locators, it's a way to decouple the interface (abstract base class) from a concrete implementation, and at the same time allows to access the concrete implementation from everywhere in your App over the interface.
> I can only highly recommend reading this classic article by Martin Fowler [Inversion of Control Containers and the Dependency Injection pattern](https://martinfowler.com/articles/injection.html).

GetIt is:

- Extremely fast (O(1))
- Easy to learn/use
- Doesn't clutter your UI tree with special Widgets to access your data like, Provider or Redux does.

### watch_it

GetIt isn't a state management solution! It's a locator for your objects so you need some other way to notify your UI about changes like `Streams` or `ValueNotifiers`. But together with my package [watch_it](https://pub.dev/packages/watch_it), it gets a full-featured easy to use state management solution that integrates with the Objects registered in get_it.


## Getting Started

At your start-up you register all the objects you want to access later like this:

```Dart
final getIt = GetIt.instance;

void setup() {
  getIt.registerSingleton<AppModel>(AppModel());

// Alternatively you could write it if you don't like global variables
  GetIt.I.registerSingleton<AppModel>(AppModel());
}
```

After that you can access your `AppModel` class from anywhere like this:

```Dart
MaterialButton(
  child: Text("Update"),
  onPressed: getIt<AppModel>().update   // given that your AppModel has a method update
),
```

You can find here a [detailed blog post on how to use GetIt](https://www.burkharts.net/apps/blog/one-to-find-them-all-how-to-use-service-locators-with-flutter/)

## GetIt in Detail

As Dart supports global (or euphemistic ambient) variables I often assign my GetIt instance to a global variable to make access to it as easy as possible.

Although the approach with a global variable worked well, it has its limitations if you want to use `GetIt` across multiple packages. Therefore GetIt itself is a singleton and the default way to access an instance of `GetIt` is to call:

```Dart
GetIt getIt = GetIt.instance;

//There is also a shortcut (if you don't like it just ignore it):
GetIt getIt = GetIt.I;
```

Through this, any call to `instance` in any package of a project will get the same instance of `GetIt`. I still recommend just assigning the instance to a global variable in your project as it is more convenient and doesn't harm (Also it allows you to give your service locator your own name).

```Dart
GetIt getIt = GetIt.instance;
```

> You can use any name you want which makes Brian :smiley: happy like (`sl, backend, services...`) ;-)

Before you can access your objects you have to register them within `GetIt` typically direct in your start-up code.

```Dart
getIt.registerSingleton<AppModel>(AppModelImplementation());
getIt.registerLazySingleton<RESTAPI>(() => RestAPIImplementation());

// if you want to work just with the singleton:
GetIt.instance.registerSingleton<AppModel>(AppModelImplementation());
GetIt.I.registerLazySingleton<RESTAPI>(() => RestAPIImplementation());

/// `AppModel` and `RESTAPI` are both abstract base classes in this example
```

To access the registered objects call `get<Type>()` on your `GetIt` instance

```Dart
var myAppModel = getIt.get<AppModel>();
```

Alternatively, as `GetIt` is a [callable class](https://www.w3adda.com/dart-tutorial/dart-callable-classes) depending on the name you choose for your `GetIt` instance you can use the shorter version:

```Dart
var myAppModel = getIt<AppModel>();

// as Singleton:
var myAppModel = GetIt.instance<AppModel>();
var myAppModel = GetIt.I<AppModel>();
```

## Different ways of registration

`GetIt` offers different ways how objects are registered that affect the lifetime of these objects.

#### Factory

```Dart
void registerFactory<T>(FactoryFunc<T> func)
```

You have to pass a factory function `func` that returns a NEW instance of an implementation of `T`. Each time you call `get<T>()` you will get a new instance returned. How to pass parameters to a factory you can find [here](#passing-parameters-to-factories).

#### Singleton & LazySingleton

> Although I always would recommend using an abstract base class as a registration type so that you can vary the implementations you don't have to do this. You can also register concrete types.

```Dart
T registerSingleton<T>(T instance)
```

You have to pass an instance of `T` or a derived class of `T` that you will always get returned on a call to `get<T>()`. The newly registered instance is also returned which can be sometimes convenient.

As creating this instance can be time-consuming at app start-up you can shift the creation to the time the object is the first time requested with:

```Dart
void registerLazySingleton<T>(FactoryFunc<T> func)
```

You have to pass a factory function `func` that returns an instance of an implementation of `T`. Only the first time you call `get<T>()` this factory function will be called to create a new instance. After that, you will always get the same instance returned.

### Registering multiple implementations

There are certain circumstances where you might wish to register multiple implementations of the same interface and then get a list of all of the relevant implementations later on. For instance, you might have a modular design where each module registers an interface defining a page and then all of these get injected into your navigation bar in your main layout without your layout needing to know about each module.

> [!NOTE]  
> To avoid this being a breaking change and to prevent you from erroneously re-registering a type without expecting this behaviour, to enable this you need to call:
>
>```dart
>getIt.enableRegisteringMultipleInstancesOfOneType();
>```

Then, you just register your classes as you normally would:

```dart
getIt.registerLazySingleton<MyBase>(
  () => ImplA(),
);
getIt.registerLazySingleton<MyBase>(
  () => ImplB(),
);
```

Then, later on you can fetch all instances of this interface by calling:

```dart
final Iterable<MyBase> instances = getIt.getAll<MyBase>();
```
The returned `Iterable` will then contain all registered instances of the requested interface with or without an instance name.
There is also an `async` implementation available for this:

```dart
final Iterable<MyBase> instances = await getIt.getAllAsync<MyBase>();
```

### Overwriting registrations

If you try to register a type more than once you will fail with an assertion in debug mode because normally this is not needed and probably a bug.
If you really have to overwrite a registration, then you can by setting the property `allowReassignment = true`.

### Skip Double registrations while testing

If you try to register a type more than once and when `allowReassignment = false`  you will fail with an assertion in debug mode.
If you want to just skip this double registration silently without an error, then you can by setting the property `skipDoubleRegistration = true`.
This is only available inside tests where is can be handy.

### Testing if a Singleton is already registered

You can check if a certain Type or instance is already registered in GetIt with:

```Dart
 /// Tests if an [instance] of an object or aType [T] or a name [instanceName]
 /// is registered inside GetIt
 bool isRegistered<T>({Object instance, String instanceName});
```

### Unregistering Singletons or Factories

If you need to you can also unregister your registered singletons and factories and pass an optional `disposingFunction` for clean-up.

```Dart
/// Unregister an [instance] of an object or a factory/singleton by Type [T] or by name [instanceName]
/// if you need to dispose some resources before the reset, you can
/// provide a [disposingFunction]. This function overrides the disposing
/// you might have provided when registering.
void unregister<T>({Object instance,String instanceName, void Function(T) disposingFunction})
```

### Resetting LazySingletons

In some cases, you might not want to unregister a LazySingleton but instead, reset its instance so that it gets newly created on the next access to it.

```Dart
  /// Clears the instance of a lazy singleton,
  /// being able to call the factory function on the next call
  /// of [get] on that type again.
  /// you select the lazy Singleton you want to reset by either providing
  /// an [instance], its registered type [T] or its registration name.
  /// if you need to dispose some resources before the reset, you can
  /// provide a [disposingFunction]. This function overrides the disposing
  /// you might have provided when registering.
void resetLazySingleton<T>({Object instance,
                            String instanceName,
                            void Function(T) disposingFunction})
```

### Resetting GetIt completely

```Dart
/// Clears all registered types in the reverse order in which they were registered.
/// Handy when writing unit tests or before quitting your application.
/// If you provided dispose function when registering they will be called
/// [dispose] if `false` it only resets without calling any dispose
/// functions
/// As dispose funcions can be async, you should await this function.
Future<void> reset({bool dispose = true});
```

## Scopes

With V5.0 of GetIt, it now supports hierarchical scoping of registration. What does this mean?
You can push a new registration scope like you push a new page on the Navigator. Any registration after that will be registered in this new scope. When accessing an object with `get` GetIt first checks the topmost scope for registration and then the ones below. This means you can register the same type that was already registered in a lower scope again in the scope above and you will always get the latest registered object.

Imagine an app that can be used with or without a login. On App start-up, a `DefaultUser` object is registered with the abstract type `User` as a singleton. As soon as the user logs in, a new scope is pushed and a new `LoggedInUser` object again with the `User` type is registered that allows more functions. For the rest of the App, nothing has changed as it still accesses `User` objects through GetIt.
As soon as the user Logs off all you have to do is pop the Scope and automatically the `DefaultUser` is used again.

Another example could be a shopping basket where you want to ensure that not a cart from a previous session is used again. So at the beginning of a new session, you push a new scope and register a new cart object. At the end of the session, you pop this scope again.

### Scope functions

```Dart
  /// Creates a new registration scope. If you register types after creating
  /// a new scope they will hide any previous registration of the same type.
  /// Scopes allow you to manage different live times of your Objects.
  /// [scopeName] if you name a scope you can pop all scopes above the named one
  /// by using the name.
  /// [dispose] function that will be called when you pop this scope. The scope
  /// is still valid while it is executed
  /// [init] optional function to register Objects immediately after the new scope is
  /// pushed. This ensures that [onScopeChanged] will be called after their registration
  /// if [isFinal] is set to true, you can't register any new objects in this scope after
  /// this call. In Other words you have to register the objects for this scope inside
  /// [init] if you set [isFinal] to true. This is useful if you want to ensure that
  /// no new objects are registered in this scope by accident which could lead to race conditions
  void pushNewScope({void Function(GetIt getIt)? init,String scopeName, ScopeDisposeFunc dispose});

  /// Disposes all factories/Singletons that have been registered in this scope
  /// and pops (destroys) the scope so that the previous scope gets active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is popped.
  /// As dispose functions can be async, you should await this function.
  Future<void> popScope();

  /// if you have a lot of scopes with names you can pop (see [popScope]) all
  /// scopes above the scope with [name] including that scope unless [inclusive]= false
  /// Scopes are popped in order from the top
  /// As dispose functions can be async, you should await this function.
  /// If no scope with [name] exists, nothing is popped and `false` is returned
  Future<bool> popScopesTill(String name, {bool inclusive = true});

  /// Clears all registered factories and singletons in the provided scope,
  /// then destroys (drops) the scope. If the dropped scope was the last one,
  /// the previous scope becomes active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is dropped.
  /// As dispose functions can be async, you should await this function.
  Future<void> dropScope(String scopeName);

  /// Tests if the scope by name [scopeName] is registered in GetIt
  bool hasScope(String scopeName);

  /// Clears all registered types for the current scope in the reverse order in which they were registered.
  /// If you provided dispose function when registering they will be called
  /// [dispose] if `false` it only resets without calling any dispose
  /// functions
  /// As dispose funcions can be async, you should await this function.
  Future<void> resetScope({bool dispose = true});
```

#### Getting notified about the shadowing state of an object

In some cases, it might be helpful to know if an Object gets shadowed by another one e.g. if it has some Stream subscriptions that it wants to cancel before the shadowing object creates a new subscription. Also, the other way round so that a shadowed Object gets notified when it's "active" again meaning when a shadowing object is removed.

For this a class had to implement the `ShadowChangeHandlers` interface:

```Dart
abstract class ShadowChangeHandlers {
  void onGetShadowed(Object shadowing);
  void onLeaveShadow(Object shadowing);
}
```

When the Object is shadowed its `onGetShadowed()` method is called with the object that is shadowing it. When this object is removed from GetIt `onLeaveShadow()` will be called.

#### Getting notified when a scope change happens

When using scopes with objects that shadow other objects it's important to give the UI a chance to rebuild and acquire references to the now active objects. For this, you can register a call-back function in GetIt.
The getit_mixin has a matching `rebuiltOnScopeChange` method.

```Dart
  /// Optional call-back that will get called whenever a change in the current scope happens
  /// This can be very helpful to update the UI in such a case to make sure it uses
  /// the correct Objects after a scope change
  void Function(bool pushed)? onScopeChanged;
```

### Disposing Singletons and Scopes

From V5.0 on you can pass a `dispose` function when registering any Singletons. For this the registration functions have an optional parameter:

```Dart
DisposingFunc<T> dispose
```

where `DisposingFunc` is defined as

```Dart
typedef DisposingFunc<T> = FutureOr Function(T param);
```

So you can pass simple or async functions as this parameter. This function is called when you pop or reset the scope or when you reset GetIt completely.

When you push a new scope you can also pass a `dispose` function that is called when a scope is popped or reset but before the dispose functions of the registered objects is called which means it can still access the objects that were registered in that scope.

#### Implementing the `Disposable` interface

Instead of passing a disposing function on registration or when pushing a Scope from V7.0 on your objects `onDispose()` method will be called
if the object that you register implements the `Disposable` interface:

```Dart
abstract class Disposable {
  FutureOr onDispose();
}
```

## Asynchronous Factories

If a factory needs to call an async function you can use `registerFactoryAsync()`

```Dart
/// [T] type to register
/// [func] factory function for this type
/// [instanceName] if you provide a value here your factory gets registered with that
/// name instead of a type. This should only be necessary if you need to register more
/// than one instance of one type.
void registerFactoryAsync<T>(FactoryFuncAsync<T> func, {String instanceName});
```

To access instances created by such a factory you can't use `get()` but you have to use `getAsync()` so that
you can await the creation of the requested new instance.

```Dart
/// Returns a Future of an instance that is created by an async factory or a Singleton that is
/// not ready with its initialization.
Future<T> getAsync<T>([String instanceName]);
```

## Asynchronous Singletons

Additionally, you can register asynchronous Singletons which means Singletons that have an initialization that requires async function calls. To be able to control such asynchronous start-up behaviour GetIt supports mechanisms to ensure the correct initialization sequence.

You create a Singleton with an asynchronous creation function

```Dart
  void registerSingletonAsync<T>(FactoryFuncAsync<T> factoryfunc,
      {String instanceName,
      Iterable<Type> dependsOn,
      bool signalsReady = false});
```

The difference to a normal Singleton is that you don't pass an existing instance but provide a factory function
that returns a `Future` that completes at the end of `factoryFunc` and signals that the Singleton is ready to use unless `true` is passed for `signalsReady`. (see next chapter)
To synchronize with other "async Singletons" you can pass a list of `Type`s in `dependsOn` that have to be ready before the passed factory is executed.

There are two ways to signal the system that an instance is ready.

## Synchronizing asynchronous initializations of Singletons

Often your registered services need to do asynchronous initialization work before they can be used from the rest of the app. As this is such a common task, and it's closely related to registration/initialization GetIt supports you here too.

`GetIt` has the function `allReady` which returns `Future<void>` that can be used e.g. with a Flutter FutureBuilder to await that all asynchronous initialization is finished.

```Dart
  Future<void> allReady({Duration timeout, bool ignorePendingAsyncCreation = false});
```

There are different approaches to how the returned Future can be completed:

### Using async Singletons

If you register any async Singletons `allReady` will complete only after all of them have completed their factory functions. Like:

```Dart
  class RestService {
    Future<RestService> init() async {
      Future.delayed(Duration(seconds: 1));
      return this;
    }
  }

  final getIt = GetIt.instance;

  /// in your setup function:
  getIt.registerSingletonAsync<ConfigService>(() async {
    final configService = ConfigService();
    await configService.init();
    return configService;
  });

  getIt.registerSingletonAsync<RestService>(() async => RestService().init());
  // here we asume an async factory function `createDbServiceAsync`
  getIt.registerSingletonAsync<DbService>(createDbServiceAsync);


  /// ... in your startup page:
  return FutureBuilder(
      future: getIt.allReady(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text('The first real Page of your App'),
            ),
          );
        } else {
          return CircularProgressIndicator();
        }
      });
```

The above example shows you different ways to register async Singletons. The start-up page will display a `CircularProgressIndicator` until all services have been created.

### Solving dependencies

### Automatic using `dependsOn`

In a case, these services have to be initialized in a certain order because they depend on that other services are already ready to be used you can use the `dependsOn` parameter of `registerFactoryAsync`. If you have a non-async Singleton that depends on other Singletons, there is `registerSingletonWithDependencies`. In the following example, `DbService` depends on `ConfigService`, and `AppModel` depends on `ConfigService` and `RestService`

```Dart
  getIt.registerSingletonAsync<ConfigService>(() async {
    final configService = ConfigService();
    await configService.init();
    return configService;
  });

  getIt.registerSingletonAsync<RestService>(() async => RestService().init());

  getIt.registerSingletonAsync<DbService>(createDbServiceAsync,
      dependsOn: [ConfigService]);

  getIt.registerSingletonWithDependencies<AppModel>(
      () => AppModelImplmentation(),
      dependsOn: [ConfigService, DbService, RestService]);
```

When using `dependsOn` you ensure that the registration waits with creating its singleton on the completion of the type defined in `dependsOn`.

The `dependsOn` field also accepts `InitDependency` classes that allow specifying the dependency by type and `instanceName`.

```Dart
  getIt.registerSingletonAsync<RestService>(() async => RestService().init(), instanceName:"rest1");

  getIt.registerSingletonWithDependencies<AppModel>(
      () => AppModelImplmentation(),
      dependsOn: [InitDependency(RestService, instanceName:"rest1")]);
```

### Manually signaling the ready state of a Singleton

Sometimes the mechanism of `dependsOn` might not give you enough control. For this case you can use `isReady` to wait for a certain singleton:

```Dart
  /// Returns a Future that completes if the instance of a Singleton, defined by Type [T] or
  /// by name [instanceName] or passing the an existing [instance], is ready
  /// If you pass a [timeout], a [WaitingTimeOutException] will be thrown if the instance
  /// is not ready in the given time. The Exception contains details on which Singletons are
  /// not ready at that time.
  /// [callee] optional parameter which makes debugging easier. Pass `this` in here.
  Future<void> isReady<T>({
    Object instance,
    String instanceName,
    Duration timeout,
    Object callee,
  });
```

To signal that a singleton is ready it can use `signalReady`, provided you have set the optional `signalsReady` parameter when registering it OR make your registration type implement the empty abstract class `WillSignalReady`. Otherwise, `allReady` will wait on a call to signalsReady. No automatic signaling will happen in that case.

```Dart
/// Typically this is used in this way inside the registered objects init
/// method `GetIt.instance.signalReady(this);`
void signalReady(Object instance);
```

You can use this to initialize your Singletons without async registration by using fire and forget async function from your constructors like so:

```Dart
class ConfigService {
  ConfigService()
  {
    init();
  }
  Future init() async {
    // do your async initialisation...

    GetIt.instance.signalReady(this);
  }
}
```

### Using `allReady` repeatedly

Even if you already have awaited `allReady`, the moment you register new async singletons or singletons with dependencies you can use `allReady` again. This makes especially sense if you use scopes where every scope needs to get initialized.

### Manual triggering **allReady** (almost deprecated)

By calling `signalReady(null)` on your `GetIt` instance the `Future` you can get from `allReady` will be completed.
This is the most basic way to synchronize your start-up. If you want to do that **don't use `signalsReady` or async Singletons**!!!
I recommend using one of the other ways because they are more flexible and express your intention more clear.

You can find here a [detailed blog post on async factories and startup synchronization](https://www.burkharts.net/apps/blog/one-to-find-them-all-how-to-use-service-locators-with-flutter/)

## Passing Parameters to factories

In some cases, it's handy if you could pass changing values to factories when calling `get()`. For that there are two variants for registering factories:

```dart
/// registers a type so that a new instance will be created on each call of [get] on that type based on
/// up to two parameters provided to [get()]
/// [T] type to register
/// [P1] type of param1
/// [P2] type of param2
/// if you use only one parameter pass void here
/// [factoryfunc] factory function for this type that accepts two parameters
/// [instanceName] if you provide a value here your factory gets registered with that
/// name instead of a type. This should only be necessary if you need to register more
/// than one instance of one type.
///
/// example:
///    getIt.registerFactoryParam<TestClassParam,String,int>((s,i)
///        => TestClassParam(param1:s, param2: i));
///
/// if you only use one parameter:
///
///    getIt.registerFactoryParam<TestClassParam,String,void>((s,_)
///        => TestClassParam(param1:s);
void registerFactoryParam<T,P1,P2>(FactoryFuncParam<T,P1,P2> factoryfunc, {String instanceName});

```

and

```Dart
  void registerFactoryParamAsync<T,P1,P2>(FactoryFuncParamAsync<T,P1,P2> factoryfunc, {String instanceName});
```

The reason why I settled to use two parameters is that I can imagine some scenarios where you might want to register a builder function for Flutter Widgets that need to get a `BuildContext` and some data object.

When accessing these factories you pass the parameters a optional arguments to `get()`:

```Dart
  var instance = getIt<TestClassParam>(param1: 'abc',param2:3);
```

These parameters are passed as `dynamics` (otherwise I would have had to add more generic parameters to `get()`), but they are checked at runtime to be the correct types.

## Testing with GetIt

### Unit Tests

When you are writing unit tests with GetIt in your App you have two possibilities:

- Register all the Objects you need inside your unit Tests so that GetIt can provide its objects to the objects that you are testing.
- Pass your dependent objects into the constructor of your test objects like:

```Dart
GetIt getIt = GetIt.instance;

class UserManager {
  AppModel appModel;
  DbService dbService;

  UserManager({AppModel? appModel, DbService? dbService}) {
    this.appModel = appModel ?? getIt.get<AppModel>();
    this.dbService = dbService ?? getIt.get<DbService>();
  }
}
```

This way you don't need to pass them in the `AppModel` and `dbService` inside your App but you can pass them (or a mocked version) in your Unit tests.

### Integration Tests

If you have a mocked version of a Service, you can easily switch between that and the real one based on a flag:

```Dart
  if (testing) {
    getIt.registerSingleton<AppModel>(AppModelMock());
  } else {
    getIt.registerSingleton<AppModel>(AppModelImplementation());
  }
```

## Experts region

### Named registration

Ok, you have been warned! All registration functions have an optional named parameter `instanceName`. Providing a name with factory/singleton here registers that instance with that name and a type. Consequently `get()` has also an optional parameter `instanceName` to access
factories/singletons that were registered by name.

**IMPORTANT:** Each name must be unique per type.

```Dart
  abstract class RestService {}
  class RestService1 implements RestService{
    Future<RestService1> init() async {
      Future.delayed(Duration(seconds: 1));
      return this;
    }
  }
  class RestService2 implements RestService{
    Future<RestService2> init() async {
      Future.delayed(Duration(seconds: 1));
      return this;
    }
  }

  getIt.registerSingletonAsync<RestService>(() async => RestService1().init(), instanceName : "restService1");
  getIt.registerSingletonAsync<RestService>(() async => RestService2().init(), instanceName : "restService2");

  getIt.registerSingletonWithDependencies<AppModel>(
      () {
          RestService restService1 = GetIt.I.get<RestService>(instanceName: "restService1");
          return AppModelImplmentation(restService1);
      },
      dependsOn: [InitDependency(RestService, instanceName:"restService1")],
  );
```

### Accessing an object inside GetIt by a runtime type

In rare occasions you might be faced with the problem that you don't know the type that you want to retrieve from GetIt at compile time which means you can't pass it as a generic parameter. For this the `get` functions have an optional `type` parameter

```Dart
    getIt.registerSingleton(TestClass());

    final instance1 = getIt.get(type: TestClass);

    expect(instance1 is TestClass, true);
```

Be careful that the receiving variable has the correct type and don't pass `type` and a generic parameter.

### More than one instance of GetIt

While not recommended, you can create your own independent instance of `GetIt` if you don't want to share your locator with some
other package or because the physics of your planet demands it :-)

```Dart
/// To make sure you really know what you are doing
/// you have to first enable this feature:
GetIt myOwnInstance = GetIt.asNewInstance();
```

This new instance does not share any registrations with the singleton instance.

## Acknowledgements

Many thanks to the insightful discussions on the API with [Brian Egan](https://github.com/brianegan) and [Simon Lightfoot](https://github.com/slightfoot)
