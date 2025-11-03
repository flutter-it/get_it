## [9.0.3] - 2025-01-12

* Fixed logo display on pub.dev by using relative path

## [9.0.2] - 2025-01-12

* Fixed button sizing in README for pub.dev display

## [9.0.1]

* Fixed linter error (missing trailing comma in test file)

## [9.0.0] - BREAKING CHANGE

* **BREAKING**: Disposal order now always follows strict LIFO (Last-In-First-Out) based on registration order
  * Previously, disposal order was based on the order objects appeared in internal hash maps, which was unpredictable when mixing named and unnamed registrations
  * Now all disposals are sorted by `registrationNumber` (a sequential counter assigned during registration) ensuring true LIFO order
  * The `strictDisposalOrder` parameter has been removed from `reset()`, `resetScope()`, `popScope()`, `popScopesTill()`, and `dropScope()` methods
  * Performance impact is minimal: ~8% overhead for 10,000 registrations (approximately 2-3ms), negligible for typical applications
  * This change ensures correctness and predictability in dependency cleanup, which is more important than the minor performance cost
  * **Impact on existing apps**: If your app's behavior relies on the previous imperfect reverse disposal order, there is likely a design issue in your dependency structure that should be addressed
* Fixed bug in `registerCachedFactoryParamAsync` where calling `getAsync` would fail with null error because it was checking the wrong function parameter (sync `creationFunctionParam` instead of `asyncCreationFunctionParam`)

## [8.3.0]

* Added `findAll()` method for finding all registered instances by type with flexible matching options (subtypes, interfaces, scope filtering)
* Added `resetLazySingletons()` method to reset multiple lazy singletons at once with optional scope parameters
* Added `onCreated` callback parameter to `registerLazySingleton`, `registerLazySingletonAsync`, and `registerSingletonAsync` for lifecycle hooks
* Improved parameter validation error messages in debug mode - now provides clear, actionable feedback when wrong parameter types are passed to factories
* Fixed bug in cached factories where parameter validation could throw unhelpful errors

## [8.2.0]

Thanks to PR by @Hu-Wentao we now expose part of the internal state of get_it so tool authors have more options. While doing so internal renaming has happened, so where previously where the term "ServiceFactory" was uses we not use consistently `ObjectRegistration` and instead of variables with `factory` in the name we use `registration` this has not impact on the public API so it is not a breaking change.

## [8.1.0]

* adding documentation https://github.com/flutter-it/get_it/issues/411
* registerCachedFactoryAsync usded FactoryFunc instead of FactoryFuncAsync https://github.com/flutter-it/get_it/issues/410
* adding `getMaybe` which will return `null` instead of throwing an exception in case a type is not registered
* `dependsOn` of `registerSingletonWithDependencies` is now required. Although this could be seen as a breaking change, if you didn't pass `dependsOn` your code wouldn't have worked before so I won't define this as breaking change


## [8.0.3]

* fixing linter warning thanks to @PatrickChrestin

## [8.0.2]

* Fixes by @kuhnroyal and  @ArtAhmetajCR who spotted some flaws in my latest changes. Thanks a lot

## [8.0.1]

* Bugfixes and improvements for certain edge cases thanks to @KnightOfBlackLily and @kuhnroyal 

## [8.0.0]

* official new release with all the changes

## [8.0.0-pre-7] - 12.08.2024 

* adding cachedFatories and better scope protection against race conditions

## [8.0.0-pre-6] - 11.08.2024 

* testing weak references in lazySingeltons

## [8.0.0-pre-5] - 25.06.2024 

* adding `changeTypeInstanceName`

## [8.0.0-pre-4] - 03.06.2024 

* fixing bug in `unregister` that happened if you tried to unregister a named registration by providing an instance instead of the type and the instance name

## [8.0.0-pre-3] - 31.05.2024

* releaseInstance will now throw if the instance isn't registered

## [8.0.0-pre-2] - 29.05.2024 

* fixing negative reference count

## [8.0.0-pre-1] - 26.05.2024 

* `getAll()` and `getAllAsync()` now have a `fromAllScopes` parameter.
* adding safeguards according to https://github.com/fluttercommunity/get_it/issues/364 to make it impossible to call `push/popScope` while the `init()` function of another pushScope is running.
* fixed an unsafe type check when using a runtime type to access an object in get_it.

## [7.7.0] - 15.04.2024 

* thanks to the PR by @kasefuchs https://github.com/fluttercommunity/get_it/pull/361 `getAll` is now available in an async version too.

## [7.6.9] - 11.04.2024

* fig for bug that was introduced in 7.6.8 https://github.com/fluttercommunity/get_it/issues/358

## [7.6.8] - 03.04.2024

* merged PR by @venkata-reddy-dev https://github.com/fluttercommunity/get_it/pull/356 adding new `skipDoubleRegistration` flag for testing

## [7.6.7] - 18.01.2024

* merged PR by @subzero911  https://github.com/fluttercommunity/get_it/pull/330

## [7.6.6] - 04.01.2024

* Thanks to PR by @bvoq `getIt.reset, getIt.popScope, getIt.dropScope` now dispose registered objects in the reverse order in which they were registered.

## [7.6.5] - 25.09.2023

* updated Discord link

## [7.6.4] - 04.09.2023

* fixed the throwing of a StateError that was previously thrown as String

## [7.6.3] - 04.09.2023

* push new version because pub didn't list this one

## [7.6.2] - 31.08.2023

* fix linter error

## [7.6.1] - 31.08.2023

* added `isFinal` scope parameter which fixes https://github.com/fluttercommunity/get_it/issues/326
* version bump of dependencies and updates readme

## [7.6.0] - 09.05.2023

* merged PR by lacopiroty https://github.com/fluttercommunity/get_it/pull/297 which now allows to access objects inside GetIt by runtime type too like
```Dart
    getIt.registerSingleton(TestClass());

    final instance1 = getIt.get(type: TestClass);

    expect(instance1 is TestClass, true);
```
* fix for https://github.com/fluttercommunity/get_it/issues/299 
* fix for https://github.com/fluttercommunity/get_it/issues/300    


## [7.5.0] - 07.05.2023

* new function `dropScope(scopeName)` which allows to remove and dispose any named scope even if it's not the top one. Great PR by @olexale https://github.com/fluttercommunity/get_it/pull/292 which fixes sort of race conditions if you create scopes just for the life time of a widget. 
## [7.4.1]
* PR from @dzziwny which fixed an edge case with LazySingletons https://github.com/fluttercommunity/get_it/pull/284
* Changed an assertion in case that an object is not registered to an Exception that also will throw in real time so that you get meaningful errors based on https://github.com/fluttercommunity/get_it/issues/312

## [7.4.0]
* `registerSingleton` now returns the passed instance as a return value thanks to the PR by @Rexios80 https://github.com/fluttercommunity/get_it/pull/242
* In some cases GetIt will print error messages to the debug output. Now this won't happen anymore in release mode and can be completely disabled by setting `GetIt.noDebugOutput=true` following the PR from @James1345 
## [7.3.0]

New features:
* `popScopeTil` got a new optional `inclusive` parameter so you can now decide if scope with the passed name should be popped too or only the ones above
* PR by @jtdLab that adds to reset a LazySingleton by providing an existing instance
* Fix for an internal state error by @ioantsaf 
* Fix for a rare edge case if you manually `signalReady`
* Many PRs with improvements to spelling and grammar of readme, source documentation and even one assert message by @selcukguvel @isinghmitesh @UsamaKarim @nilsreichardt and  Os-Prog
@Ae-Mc 


## [7.2.0] 

* fix for https://github.com/fluttercommunity/get_it/issues/210
* Parameters of factories are no longer needed to be casted because they are nullable
* downgraded the dependency on `async` to 2.6 again
* you couldn't push two Scopes without a name

## [7.1.4]

* fixed bug with manual synchronization of SingletonsWithDependencies 
https://github.com/fluttercommunity/get_it/issues/196

## [7.1.3] - 07.05.2021

* Fix for https://github.com/fluttercommunity/get_it/issues/186

## [7.1.2] - 06.05.2021

* Thanks to the clever PR https://github.com/fluttercommunity/get_it/pull/185 by @kmartins `unregister` and `resetLazySingleton` now only have to be awaited if you use an async disposal function.

## [7.1.1] - 05.05.2021

* `pushNewScope()` now got an optional `init` parameter where you can pass a function that registers new objects inside the newly pushed Scope. Doing the registration in this function ensures that the `onScopeChanged` call-back is called after the objects are registered.

## [7.1.0] - 05.05.2021

* The new `Disposable` interface had a typo that now got corrected. You could call this a breaking change but as the last version change is just three days old I guess not many people will be affected by this correction.

#### Getting notified when a scope change happens

When using scopes with objects that shadow other objects its important to give the UI a chance to rebuild and acquire references to the now active objects. For this you can register an call-back function in GetIt
The getit_mixin has a matching `rebuiltOnScopeChange` method.

```Dart
  /// Optional call-back that will get call whenever a change in the current scope happens
  /// This can be very helpful to update the UI in such a case to make sure it uses
  /// the correct Objects after a scope change
  void Function(bool pushed)? onScopeChanged;
```
## [7.0.0] - 02.05.2021

This is a breaking change because there were some inconsistencies in the handling of the disposal functions that you can pass when registering an Object, pop a Scope or use `unregister()`  `resetLazySingleton()`.  Some of accepted a `FutureOr` method type, others just a `void` which meant you couldn't use async functions consistently. With this release you can use async functions in all disposal functions which unfortunately also required to change the signatures of the following functions:

```dart
  Future<void> reset({bool dispose = true});

  Future<void> resetScope({bool dispose = true});

  Future<void> popScope();

  Future<bool> popScopesTill(String name);

  FutureOr resetLazySingleton<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  });

  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  });
```

Basically all functions that can possibly call a disposal functions should be awaited. 
#### Implementing the `Disposable` interface

Instead of passing a disposing function on registration or when pushing a Scope from V7.0 on your objects `onDispose()` method will be called
if the object that you register implements the `Disposable`´interface:

```Dart
abstract class Disposable {
  FutureOr onDispose();
}
```
#### Getting notified about the shadowing state of an object
In some cases it might be helpful to know if an Object gets shadowed by another one e.g. if it has some Stream subscriptions that it want to cancel before the shadowing object creates a new subscription. Also the other way round so that a shadowed Object gets notified when it's "active" again meaning when a shadowing object is removed.

For this a class had to implement the `ShadowChangeHandlers` interface:

```Dart
abstract class ShadowChangeHandlers {
  void onGetShadowed(Object shadowing);
  void onLeaveShadow(Object shadowing);
}
```
When the Object is shadowed its `onGetShadowed()` method is called with the object that is shadowing it. When this object is removed from GetIt `onLeaveShadow()` will be called. 


 * Thanks to this PR https://github.com/fluttercommunity/get_it/pull/181 by @n3wtron you can now also make objects depend on other objects not only by type but also by type and name if you used a named registration

## [6.1.1] - 13.04.2021

* small fix in getAsync with parameters

## [6.1.0] - 12.04.2021

* Exceptions that occur during an async initialisation are now forwarded to the future that `allReady()` returns instead to get swallowed https://github.com/fluttercommunity/get_it/issues/148
* Added a property `currentScopeName` to query the name of the currently active scope https://github.com/fluttercommunity/get_it/issues/153
* `popScope` will know throw an Exception instead just an assert if you are already on the `baseScope` and you try to pop it. 

## [6.0.0] - 15.02.2021

* Official null safety release

## [5.0.2] - 08.12.2020

* fixed https://github.com/fluttercommunity/get_it/issues/138 when calling `unRegister` the dispose function
that can be passed when registering wasn't called. 

## [5.0.1] - 23.09.2020

* fixed formatting in readme

## [5.0.0-mixin-version] - 17.09.2020

* experimental

## [5.0.0] - 15.09.2020

* New scope support for registration
* optional dispose functions for registered objects
* **Breaking change:** `reset()` now is async and returns a `Future` because it will call the new optional disposal functions that can be async
* **Breaking change:** If you use names to register your objects you now have to provide a type too or at least make sure the compiler can infer the type. With this change it is now possible to use the same name for different types.

## [5.0.0-alpha] - 11.09.2020

* alpha version of V5.0 

## [4.0.4] - 22.07.2020

* fixed linter errors

## [4.0.3] - 22.07.2020

* fixes of several typos thanks to PRs from @Bryanx, @sspatari 
* fixed error https://github.com/fluttercommunity/get_it/issues/92

## [4.0.2] - 26.04.2020

* removed too strong type check for passed factory parameter
* fixed error message https://github.com/fluttercommunity/get_it/issues/69


## [4.0.1] - 19.03.2020

* overhauled readme
* removed unnecessary print statement

## [4.0.0] - 26.02.2020

* Added abstract `WillSignalReady` class

## [4.0.0-release-candidate] - 14.02.2020

* Breaking changes in API!!!
* Release candidate
* New Async functions
* Factories with parameters
* Improved startup synchronisation

## [3.0.2] - 23.10.2019

* Bugfix when using named instances

## [3.0.1] - 24.09.2019

* Bugfix with https://github.com/fluttercommunity/get_it/pull/21

## [3.0.0+1] - 07.09.2019

* Small fix to make the analyser happy

## [3.0.0] - 07.09.2019

* Overhauled the signalling API because the way it was was not optimal. Now you can either signal globally or by passing the instance of the registered object that shall signal. This way it's ensured that you have to have access to the instance to signal, typically from within the instance with a `GetIt.instance.signalReady(this)` 
individual signalling from other places but the instance itself is probably an error.
* Unregister of singletons /lazysingletons now possible also over a registered instance.
* Most asserts have bin replaced with throwing `Error`objects.
* The example now shows the ready signalling.

## [2.1.0] - 26.08.2019

* Added handy ready signal to make start-up logic a bit easier
* Unregister of Objects now possible with optional disposing function

## [2.0.3] - 26.08.2019

* Small fix

## [2.0.2] - 19.08.2019

* Small fix

## [2.0.1] - 19.08.2019

* Small fix

## [2.0.0] - 18.08.2019

* **Breaking Change with V2.0.0** 
you no longer can directly create instances of the type `GetIt` because `GetIt` is now a singleton please see [README](README.md)

## [1.1.0] - 18.08.2019

* added named registration

## [1.0.3+2] - 26.06.2019

* updated logo in readme

## [1.0.3+1] - 22.05.2019

* updated authors

## [1.0.3] - 01.03.2019

* Small fix so that intellisense works now if you use the short calling form without using `.get()` 

## [1.0.2] - 22.06.2018

* Moved package to [Flutter Community](https://github.com/fluttercommunity) 

## [1.0.1] - 20.06.2018

* Added `reset()`method 

## [1.0.0] - 22.05.2018

* Initial release 

