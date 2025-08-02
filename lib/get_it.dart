// ignore_for_file: avoid_print

library get_it;

import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:meta/meta.dart';

part 'get_it_impl.dart';

/// You will see a rather esoteric looking test `(const Object() is! T)` at several places.
/// It tests if [T] is a real type and not Object or dynamic.

/// For each registered factory/singleton a [_ServiceFactory<T>] is created
/// it holds either the instance of a Singleton or/and the creation functions
/// for creating an instance when [get] is called
///
/// There are three different types:
enum ServiceFactoryType {
  alwaysNew, // factory which means on every call of [get] a new instance is created
  constant, // normal singleton
  lazy, // lazy
  cachedFactory, // cached factory
}

/// If your singleton that you register wants to use the manually signalling
/// of its ready state, it can implement this interface class instead of using
/// the [signalsReady] parameter of the registration functions
/// (you don't really have to implement much ;-) )
abstract class WillSignalReady {}

/// If an object implements the [ShadowChangeHandler] if will get notified if
/// an Object with the same registration type and name is registered on a
/// higher scope which will shadow it.
/// It also will get notified if the shadowing object is removed from GetIt
///
/// This can be helpful to unsubscribe / resubscribe from Streams or Listenables
abstract mixin class ShadowChangeHandlers {
  void onGetShadowed(Object shadowing);
  void onLeaveShadow(Object shadowing);
}

/// If objects that are registered inside GetIt implements [Disposable] the
/// [onDispose] method will be called whenever that Object is unregistered,
/// reset or its enclosing Scope is popped
abstract mixin class Disposable {
  FutureOr onDispose();
}

/// Signature of the factory function used by non async factories
typedef FactoryFunc<T> = T Function();

/// For Factories that expect up to two parameters if you need only one use `void` for the one
/// you don't use
typedef FactoryFuncParam<T, P1, P2> = T Function(P1 param1, P2 param2);

/// Signature of the factory function used by async factories
typedef FactoryFuncAsync<T> = Future<T> Function();

/// Signature for disposing function
/// because closures like `(x){}` have a return type of Null we don't use `FutureOr<void>`
typedef DisposingFunc<T> = FutureOr Function(T param);

/// Signature for disposing function on scope level
typedef ScopeDisposeFunc = FutureOr Function();

/// For async Factories that expect up to two parameters if you need only one use `void` for the one
/// you don't use
typedef FactoryFuncParamAsync<T, P1, P2> = Future<T> Function(
  P1 param1,
  P2 param2,
);

/// Data structure used to identify a dependency by type and instanceName
class InitDependency implements Type {
  final Type type;
  final String? instanceName;

  InitDependency(this.type, {this.instanceName});

  @override
  String toString() => "InitDependency(type:$type, instanceName:$instanceName)";
}

class WaitingTimeOutException implements Exception {
  /// In case of a timeout while waiting for an instance to get ready
  /// This exception is thrown with information about who is still waiting.
  ///
  /// If you pass the [callee] parameter to [isReady], or define dependent Singletons
  /// this maps lists which callees are waiting for whom.
  final Map<String, List<String>> areWaitedBy;

  /// Lists with Types that are still not ready.
  final List<String> notReadyYet;

  /// Lists with Types that are already ready.
  final List<String> areReady;

  WaitingTimeOutException(this.areWaitedBy, this.notReadyYet, this.areReady);

  // todo : assert(areWaitedBy != null && notReadyYet != null && areReady != null);

  @override
  String toString() {
    print(
      'GetIt: There was a timeout while waiting for an instance to signal ready',
    );
    print('The following instance types where waiting for completion');
    for (final entry in areWaitedBy.entries) {
      print('${entry.value} is waiting for ${entry.key}');
    }
    print('The following instance types have NOT signalled ready yet');
    for (final entry in notReadyYet) {
      print(entry);
    }
    print('The following instance types HAVE signalled ready yet');
    for (final entry in areReady) {
      print(entry);
    }
    return super.toString();
  }
}

abstract class ServiceFactory<T extends Object> {
  ServiceFactoryType get factoryType;

  /// In case of a named registration the instance name is here stored for easy access
  String? get instanceName;

  /// true if one of the async registration functions have been used
  bool get isAsync;

  /// If an existing Object gets registered or an async/lazy Singleton has finished
  /// its creation, it is stored here
  Object? get instance;

  /// the type that was used when registering, used for runtime checks
  Type get registrationType;

  bool get isReady;

  bool get isNamedRegistration => instanceName != null;

  String get debugName => '$instanceName : $registrationType';

  bool get canBeWaitedFor;
}

/// Very simple and easy to use service locator
/// You register your object creation factory or an instance of an object with [registerFactory],
/// [registerSingleton] or [registerLazySingleton]
/// And retrieve the desired object using [get] or call your locator as function as its a
/// callable class
/// Additionally GetIt offers asynchronous creation functions as well as functions to synchronize
/// the async initialization of multiple Singletons
abstract class GetIt {
  static final GetIt _instance = _GetItImplementation();

  /// Optional call-back that will get call whenever a change in the current scope happens
  /// This can be very helpful to update the UI in such a case to make sure it uses
  /// the correct Objects after a scope change
  /// The getit_mixin has a matching `rebuiltOnScopeChange` method
  void Function(bool pushed)? onScopeChanged;

  /// access to the Singleton instance of GetIt
  static GetIt get instance => _instance;

  /// Short form to access the instance of GetIt
  static GetIt get I => _instance;

  /// If you need more than one instance of GetIt you can use [asNewInstance()]
  /// You should prefer to use the `instance()` method to access the global instance of [GetIt].
  factory GetIt.asNewInstance() {
    return _GetItImplementation();
  }

  // If this is set to true do not print errors
  // By default in release mode we don't print errors
  static bool noDebugOutput = false;

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  bool allowReassignment = false;

  /// By default it's throws error when [allowReassignment]= false. and trying to register same type
  /// If you really need, you can disable the Asserts / Error by setting[skipDoubleRegistration]= true
  @visibleForTesting
  bool skipDoubleRegistration = false;

  /// Till V7.6.7 GetIt didn't allow to register multiple instances of the same type.
  /// if you want to register multiple instances of the same type you can enable this
  /// and use `getAll()` to retrieve all instances of that parent type
  void enableRegisteringMultipleInstancesOfOneType();

  @visibleForTesting
  bool allowRegisterMultipleImplementationsOfoneType = false;

  /// retrieves or creates an instance of a registered type [T] depending on the registration
  /// function used for this type or based on a name.
  /// for factories you can pass up to 2 parameters [param1,param2] they have to match the types
  /// given at registration with [registerFactoryParam()]
  /// [type] if you want to get an instance by a Type object instead of a generic parameter.This should
  /// rarely be needed but can be useful if you have a runtime type and want to get an instance
  T get<T extends Object>({
    dynamic param1,
    dynamic param2,
    String? instanceName,
    Type? type,
  });

  /// like [get] but returns null if the instance is not found
  T? maybeGet<T extends Object>({
    dynamic param1,
    dynamic param2,
    String? instanceName,
    Type? type,
  });

  /// Returns a Future of an instance that is created by an async factory or a Singleton that is
  /// not ready with its initialization.
  /// for async factories you can pass up to 2 parameters [param1,param2] they have to match the
  /// types given at registration with [registerFactoryParamAsync()]
  /// [type] if you want to get an instance by a Type object instead of a generic parameter.This should
  /// rarely be needed but can be useful if you have a runtime type and want to get an instance
  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  });

  /// The returned `Iterable` will then contain all registered instances of the requested interface [T] with or without an instance name.
  /// if the registrations are factories they will each be called with the provided parameters [param1,param2] and
  /// the results will be returned in the Iterable.
  /// [fromAllScopes] if `true` it will return all instances from all scopes otherwise only from the current scope
  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
  });

  /// The returned `Future<Iterable>` will then contain all registered async registrations of the requested interface [T] with or without an instance name.
  /// if the registrations are factories they will each be called with the provided parameters [param1,param2] and
  /// the results will be returned in the Iterable.
  /// [fromAllScopes] if `true` it will return all instances from all scopes otherwise only from the current scope
  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
  });

  /// Callable class so that you can write `GetIt.instance<MyType>` instead of
  /// `GetIt.instance.get<MyType>`
  T call<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  });

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [factoryFunc] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  void registerFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  });

  /// Like registerFactory but holds a weak reference to the last created instance
  /// if the instance wasn't garbage collected yet it will return this instance instead of creating a new one
  void registerCachedFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  });

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// based on up to two parameters provided to [get()]
  /// [T] type to register
  /// [P1] type of param1
  /// [P2] type of param2
  /// if you use only one parameter pass void here
  /// [factoryFunc] factory function for this type that accepts two parameters
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
  void registerFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  });

  /// Like registerFactoryParam but holds a weak reference to the last created instance
  /// if the instance wasn't garbage collected yet, and if the passed parameter haven't changed,
  /// it will return this instance instead of creating a new one
  void registerCachedFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  });

  /// registers a type so that a new instance will be created on each call of [getAsync] on that type
  /// the creation function is executed asynchronously and has to be accessed with [getAsync]
  /// [T] type to register
  /// [factoryFunc] async factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  void registerFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  });

  /// Like registerFactoryAsync but holds a weak reference to the last created instance
  /// if the instance wasn't garbage collected yet it will return this instance instead of creating a new one
  void registerCachedFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  });

  /// registers a type so that a new instance will be created on each call of [getAsync]
  /// on that type based on up to two parameters provided to [getAsync()]
  /// the creation function is executed asynchronously and has to be accessed with [getAsync]
  /// [T] type to register
  /// [P1] type of param1
  /// [P2] type of param2
  /// if you use only one parameter pass void here
  /// [factoryFunc] factory function for this type that accepts two parameters
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  ///
  /// example:
  ///    getIt.registerFactoryParam<TestClassParam,String,int>((s,i) async
  ///        => TestClassParam(param1:s, param2: i));
  ///
  /// if you only use one parameter:
  ///
  ///    getIt.registerFactoryParam<TestClassParam,String,void>((s,_) async
  ///        => TestClassParam(param1:s);
  void registerFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  });

  /// Like registerFactoryParamAsync but holds a weak reference to the last created instance
  /// if the instance wasn't garbage collected yet, and if the passed parameter haven't changed,
  /// it will return this instance instead of creating a new one
  void registerCachedFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  });

  /// registers a type as Singleton by passing an [instance] of that type
  /// that will be returned on each call of [get] on that type
  /// [T] type to register
  /// The newly registered instance will also be returned.
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// If [signalsReady] is set to `true` it means that the future you can get from `allReady()`
  /// cannot complete until this instance was signalled ready by calling
  /// [signalsReady(instance)].
  T registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  });

  /// ---- With reference counting ----
  ///
  /// [registerSingletonIfAbsent] and [releaseInstance] are used to manage the lifecycle of
  /// a Singleton. This is useful if you register an object when you push a Page and this page can get
  /// pushed recursively. In that case you don't want to dispose the object when first of these pages is popped
  ///

  /// Only registers a type new as Singleton if it is not already registered. Otherwise it returns
  /// the existing instance and increments an internal reference counter to ensure that matching
  /// [unregister] or [releaseInstance] calls will decrement the reference counter an won't unregister
  /// and dispose the registration as long as the reference counter is > 0.
  /// [T] type/interface that is used for the registration and the access via [get]
  /// [factoryFunc] that is called to create the instance if it is not already registered
  /// [instanceName] optional key to register more than one instance of one type
  /// [dispose] disposing function that is automatically called before the object is removed from get_it
  T registerSingletonIfAbsent<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  });

  /// checks if a registered Singleton has an reference counter > 0
  /// if so it decrements the reference counter and if it reaches 0 it
  /// unregisters the Singleton
  /// if called on an object that's reference counter was never incremented
  /// it will immediately unregister and dispose the object
  void releaseInstance(Object instance);

  /// registers a type as Singleton by passing a factory function of that type
  /// that will be called when all dependent Singletons are ready
  /// [T] type to register
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [dependsOn] if this instance depends on other registered Singletons before it can be
  /// initialized you can either orchestrate this manually using [isReady()] or pass a list of
  /// the types that the instance depends on here. [factoryFunc] won't get executed till this
  /// types are ready. [func] is called if [signalsReady] is set to `true` it means that the
  /// future you can get from `allReady()` cannot complete until this instance was
  /// signalled ready by calling [signalsReady(instance)].
  void registerSingletonWithDependencies<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    required Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  });

  /// registers a type as Singleton by passing an asynchronous factory function which has to
  /// return the instance that will be returned on each call of [get] on that type. Therefore
  /// you have to ensure that the instance is ready before you use [get] on it or use [getAsync()]
  /// to wait for the completion.
  /// You can wait/check if the instance is ready by using [isReady()] and [isReadySync()].
  /// [factoryFunc] is executed immediately if there are no dependencies to other Singletons
  /// (see below). As soon as it returns, this instance is marked as ready unless you don't
  /// set [signalsReady==true] [instanceName] if you provide a value here your instance gets
  /// registered with that name instead of a type. This should only be necessary if you need to
  /// register more than one instance of one type.
  /// [dependsOn] if this instance depends on other registered Singletons before it can be
  /// initialized you can either orchestrate this manually using [isReady()] or pass a list of
  /// the types that the instance depends on here. [factoryFunc] won't get executed till this
  /// types are ready. If [signalsReady] is set to `true` it means that the future you can get
  /// from `allReady()` cannot complete until this instance was signalled ready by calling
  /// [signalsReady(instance)]. In that case no automatic ready signal is made after
  /// completion of [factoryFunc]
  void registerSingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  });

  /// registers a type as Singleton by passing a factory function that will be called
  /// on the first call of [get] on that type
  /// [T] type to register
  /// [factoryFunc] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [registerLazySingleton] does not influence [allReady] however you can wait
  /// for and be dependent on a LazySingleton.
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    bool useWeakReference = false,
  });

  /// registers a type as Singleton by passing an async factory function that will be called
  /// on the first call of [getAsync] on that type
  /// This is a rather esoteric requirement so you should seldom have the need to use it.
  /// This factory function [factoryFunc] isn't called immediately but wait till the first call by
  /// [getAsync()] or [isReady()] is made
  /// To control if an async Singleton has completed its [factoryFunc] gets a `Completer` passed
  /// as parameter that has to be completed to signal that this instance is ready.
  /// Therefore you have to ensure that the instance is ready before you use [get] on it or use
  /// [getAsync()] to wait for the completion.
  /// You can wait/check if the instance is ready by using [isReady()] and [isReadySync()].
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [registerLazySingletonAsync] does not influence [allReady] however you can wait
  /// for and be dependent on a LazySingleton.
  void registerLazySingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    bool useWeakReference = false,
  });

  /// find the first factory that matches the type [T]/[instanceName] or the [instance]
  ServiceFactory? findFirstFactory<T extends Object>(
      {Object? instance, String? instanceName});

  /// Tests if an [instance] of an object or a Type ([T] or [type]) or a name [instanceName]
  /// is registered inside GetIt
  bool isRegistered<T extends Object>({
    Object? instance,
    String? instanceName,
    Type? type,
  });

  /// In some cases it can be necessary to change the name of a registered instance
  /// This avoids to unregister and reregister the instance which might cause trouble
  /// with disposing functions.
  /// IMPORTANT: This will only change the the first instance that is found while
  /// searching the scopes.
  /// If the new name is already in use in the current scope it will throw a
  /// StateError
  /// [instanceName] the current name of the instance
  /// [newInstanceName] the new name of the instance
  /// [instance] the instance itself that can be used instead of
  /// providing the type and the name. If [instance] is null the type and the name
  /// have to be provided
  void changeTypeInstanceName<T extends Object>({
    String? instanceName,
    required String newInstanceName,
    T? instance,
  });

  /// Clears all registered types in the reverse order in which they were registered.
  /// Handy when writing unit tests or when disposing services that depend on each other.
  /// If you provided dispose function when registering they will be called
  /// [dispose] if `false` it only resets without calling any dispose
  /// functions
  /// As dispose functions can be async, you should await this function.
  Future<void> reset({bool dispose = true});

  /// Clears all registered types for the current scope in the reverse order of registering them.
  /// If you provided dispose function when registering they will be called
  /// [dispose] if `false` it only resets without calling any dispose
  /// functions
  /// As dispose functions can be async, you should await this function.
  Future<void> resetScope({bool dispose = true});

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
  void pushNewScope({
    void Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal,
  });

  /// Creates a new registration scope. If you register types after creating
  /// a new scope they will hide any previous registration of the same type.
  /// Scopes allow you to manage different live times of your Objects.
  /// [scopeName] if you name a scope you can pop all scopes above the named one
  /// by using the name.
  /// [dispose] function that will be called when you pop this scope. The scope
  /// is still valid while it is executed
  /// [init] optional asynchronous  function to register Objects immediately after the new scope is
  /// pushed. This ensures that [onScopeChanged] will be called after their registration
  Future<void> pushNewScopeAsync({
    Future<void> Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
  });

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

  /// Disposes all registered factories and singletons in the provided scope
  /// (in the reverse order in which they were registered),
  /// then destroys (drops) the scope. If the dropped scope was the last one,
  /// the previous scope becomes active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is dropped.
  /// As dispose functions can be async, you should await this function.
  Future<void> dropScope(String scopeName);

  /// Tests if the scope by name [scopeName] is registered in GetIt
  bool hasScope(String scopeName);

  /// Returns the name of the current scope if it has one otherwise null
  /// if you are already on the baseScope it returns 'baseScope'
  String? get currentScopeName;

  /// Clears the instance of a lazy singleton,
  /// being able to call the factory function on the next call
  /// of [get] on that type again.
  /// you select the lazy Singleton you want to reset by either providing
  /// an [instance], its registered type [T] or its registration name.
  /// if you need to dispose some resources before the reset, you can
  /// provide a [disposingFunction]. This function overrides the disposing
  /// you might have provided when registering.
  FutureOr resetLazySingleton<T extends Object>({
    T? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  });

  /// Checks if a lazy singleton instance has been created and exists.
  ///
  /// This method verifies whether a lazy singleton of type [T] (optionally identified by [instanceName])
  /// has been instantiated. Lazy singletons are only created when first accessed via [get].
  ///
  /// Returns `true` if the instance has been created and exists, `false` if it hasn't been created yet.
  ///
  /// Throws a [StateError] if the type [T] is not registered as a lazy singleton in GetIt.
  ///
  /// Example:
  /// ```dart
  /// // Register a lazy singleton
  /// getIt.registerLazySingleton<MyService>(() => MyService());
  ///
  /// // Check if instance exists (will return false initially)
  /// bool exists = getIt.checkLazySingletonInstanceExists<MyService>();
  ///
  /// // Access the instance (creates it)
  /// MyService service = getIt<MyService>();
  ///
  /// // Check again (will return true now)
  /// exists = getIt.checkLazySingletonInstanceExists<MyService>();
  /// ```
  bool checkLazySingletonInstanceExists<T extends Object>({
    String? instanceName,
  });

  /// Unregister an [instance] of an object or a factory/singleton by Type [T] or by name
  /// [instanceName] if you need to dispose any resources you can do it using
  /// [disposingFunction] function that provides an instance of your class to be disposed.
  /// This function overrides the disposing you might have provided when registering.
  /// If you have enabled reference counting when registering, [unregister] will only unregister and dispose the object
  /// if referenceCount is 0
  /// [ignoreReferenceCount] if `true` it will ignore the reference count and unregister the object
  /// only use this if you know what you are doing
  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
    bool ignoreReferenceCount = false,
  });

  /// returns a Future that completes if all asynchronously created Singletons and any
  /// Singleton that had [signalsReady==true] are ready.
  /// This can be used inside a FutureBuilder to change the UI as soon as all initialization
  /// is done
  /// If you pass a [timeout], a [WaitingTimeOutException] will be thrown if not all Singletons
  /// were ready in the given time. The Exception contains details on which Singletons are not
  /// ready yet. if [allReady] should not wait for the completion of async Singletons set
  /// [ignorePendingAsyncCreation==true]
  Future<void> allReady({
    Duration? timeout,
    bool ignorePendingAsyncCreation = false,
  });

  /// Returns a Future that completes if the instance of a Singleton, defined by Type [T] or
  /// by name [instanceName] or by passing an existing [instance], is ready
  /// If you pass a [timeout], a [WaitingTimeOutException] will be thrown if the instance
  /// is not ready in the given time. The Exception contains details on which Singletons are
  /// not ready at that time.
  /// [callee] optional parameter which makes debugging easier. Pass `this` in here.
  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  });

  /// Checks if an async Singleton defined by an [instance], a type [T] or an [instanceName]
  /// is ready without waiting
  bool isReadySync<T extends Object>({Object? instance, String? instanceName});

  /// Returns if all async Singletons are ready without waiting
  /// if [allReady] should not wait for the completion of async Singletons set
  /// [ignorePendingAsyncCreation==true]
  // ignore: avoid_positional_boolean_parameters
  bool allReadySync([bool ignorePendingAsyncCreation = false]);

  /// Used to manually signal the ready state of a Singleton.
  /// If you want to use this mechanism you have to pass [signalsReady==true] when registering
  /// the Singleton.
  /// If [instance] has a value GetIt will search for the responsible Singleton
  /// and completes all futures that might be waited for by [isReady]
  /// If all waiting singletons have signalled ready the future you can get
  /// from [allReady] is automatically completed
  ///
  /// Typically this is used in this way inside the registered objects init
  /// method `GetIt.instance.signalReady(this);`
  ///
  /// if [instance] is `null` and no factory/singleton is waiting to be signalled this
  /// will complete the future you got from [allReady], so it can be used to globally
  /// giving a ready Signal
  ///
  /// Both ways are mutually exclusive, meaning either only use the global `signalReady()` and
  /// don't register a singleton to signal ready or use any async registrations
  ///
  /// Or use async registrations methods or let individual instances signal their ready
  /// state on their own.
  void signalReady(Object? instance);
}
