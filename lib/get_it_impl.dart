// ignore_for_file: require_trailing_commas

part of 'get_it.dart';

/// Two handy functions that help me to express my intention clearer and shorter to check for runtime
/// errors
// ignore: avoid_positional_boolean_parameters
void throwIf(bool condition, Object error) {
  if (condition) throw error;
}

// ignore: avoid_positional_boolean_parameters
void throwIfNot(bool condition, Object error) {
  if (!condition) throw error;
}

const _isDebugMode = !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile');

void _debugOutput(Object message) {
  if (_isDebugMode) {
    if (!GetIt.noDebugOutput) {
      // ignore: avoid_print
      print(message);
    }
  }
}

/// If I use `Singleton` without specifier in the comments I mean normal and lazy
class _ServiceFactory<T extends Object, P1, P2> extends ServiceFactory<T> {
  @override
  final ServiceFactoryType factoryType;

  final _GetItImplementation _getItInstance;
  final _TypeRegistration registeredIn;
  final _Scope registrationScope;

  late final Type param1Type;
  late final Type param2Type;

  P1? lastParam1;
  P2? lastParam2;

  /// Because of the different creation methods we need alternative factory functions
  /// only one of them is always set.
  final FactoryFunc<T>? creationFunction;
  final FactoryFuncAsync<T>? asyncCreationFunction;
  final FactoryFuncParam<T, P1, P2>? creationFunctionParam;
  final FactoryFuncParamAsync<T, P1, P2>? asyncCreationFunctionParam;

  ///  Dispose function that is used when a scope is popped
  final DisposingFunc<T>? disposeFunction;

  /// In case of a named registration the instance name is here stored for easy access
  @override
  String? instanceName;

  /// true if one of the async registration functions have been used
  @override
  final bool isAsync;

  /// If an existing Object gets registered or an async/lazy Singleton has finished
  /// its creation, it is stored here
  T? _instance;
  WeakReference<T>? weakReferenceInstance;
  final bool useWeakReference;

  @override
  T? get instance =>
      weakReferenceInstance != null && weakReferenceInstance!.target != null
          ? weakReferenceInstance!.target
          : _instance;

  void resetInstance() {
    if (useWeakReference) {
      weakReferenceInstance = null;
    } else {
      _instance = null;
    }
  }

  /// the type that was used when registering, used for runtime checks
  @override
  late final Type registrationType;

  /// to enable Singletons to signal that they are ready (their initialization is finished)
  late Completer _readyCompleter;

  /// the returned future of pending async factory calls or factory call with dependencies
  Future<T>? pendingResult;

  /// If other objects are waiting for this one
  /// they are stored here
  final List<Type> objectsWaiting = [];

  @override
  bool get isReady => _readyCompleter.isCompleted;

  @override
  bool get isNamedRegistration => instanceName != null;

  @override
  String get debugName => '$instanceName : $registrationType';

  @override
  bool get canBeWaitedFor =>
      shouldSignalReady || pendingResult != null || isAsync;

  final bool shouldSignalReady;

  int _referenceCount = 0;

  _ServiceFactory(
    this._getItInstance,
    this.factoryType, {
    this.creationFunction,
    this.asyncCreationFunction,
    this.creationFunctionParam,
    this.asyncCreationFunctionParam,
    T? instance,
    this.isAsync = false,
    this.instanceName,
    this.useWeakReference = false,
    required this.shouldSignalReady,
    required this.registrationScope,
    required this.registeredIn,
    this.disposeFunction,
  })  : _instance = instance,
        assert(
          !(disposeFunction != null &&
              instance != null &&
              instance is Disposable),
          ' You are trying to register type ${instance.runtimeType} '
          'that implements "Disposable" but you also provide a disposing function',
        ) {
    registrationType = T;
    param1Type = P1;
    param2Type = P2;
    _readyCompleter = Completer();
  }

  FutureOr dispose() {
    /// check if we are shadowing an existing Object
    final factoryThatWouldbeShadowed =
        _getItInstance._findFirstFactoryByNameAndTypeOrNull(
      instanceName,
      type: T,
      lookInScopeBelow: true,
    );

    final objectThatWouldbeShadowed = factoryThatWouldbeShadowed?.instance;
    if (objectThatWouldbeShadowed != null &&
        objectThatWouldbeShadowed is ShadowChangeHandlers) {
      objectThatWouldbeShadowed.onLeaveShadow(instance!);
    }

    if (instance is Disposable) {
      return (instance! as Disposable).onDispose();
    }
    //if a  LazySingletons was never accessed instance is null
    if (instance != null) {
      return disposeFunction?.call(instance!);
    }
  }

  /// returns an instance depending on the type of the registration if [async==false]
  T getObject(dynamic param1, dynamic param2) {
    assert(
      !(![
            ServiceFactoryType.alwaysNew,
            ServiceFactoryType.cachedFactory,
          ].contains(factoryType) &&
          (param1 != null || param2 != null)),
      'You can only pass parameters to factories!',
    );

    try {
      switch (factoryType) {
        case ServiceFactoryType.alwaysNew:
          if (creationFunctionParam != null) {
            // param1.runtimeType == param1Type should use 'is' but Dart does
            // not support this comparison. For the time being it is therefore
            // disabled
            // assert(
            //     param1 == null || param1.runtimeType == param1Type,
            //     'Incompatible Type passed as param1\n'
            //     'expected: $param1Type actual: ${param1.runtimeType}');
            // assert(
            //     param2 == null || param2.runtimeType == param2Type,
            //     'Incompatible Type passed as param2\n'
            //     'expected: $param2Type actual: ${param2.runtimeType}');
            return creationFunctionParam!(param1 as P1, param2 as P2);
          } else {
            return creationFunction!();
          }
        case ServiceFactoryType.cachedFactory:
          if (weakReferenceInstance?.target != null &&
              param1 == lastParam1 &&
              param2 == lastParam2) {
            return weakReferenceInstance!.target!;
          } else {
            lastParam1 = param1 as P1?;
            lastParam2 = param2 as P2?;
            T newInstance;
            if (creationFunctionParam != null) {
              newInstance = creationFunctionParam!(param1 as P1, param2 as P2);
            } else {
              newInstance = creationFunction!();
            }
            weakReferenceInstance = WeakReference(newInstance);
            return newInstance;
          }
        case ServiceFactoryType.constant:
          return instance!;
        case ServiceFactoryType.lazy:
          if (instance == null) {
            if (useWeakReference) {
              if (weakReferenceInstance != null) {
                /// this means that the instance was already created and disposed
                _readyCompleter = Completer();
              }
              weakReferenceInstance = WeakReference(creationFunction!());
            } else {
              _instance = creationFunction!();
            }
            objectsWaiting.clear();
            _readyCompleter.complete();

            /// check if we are shadowing an existing Object
            final factoryThatWouldbeShadowed =
                _getItInstance._findFirstFactoryByNameAndTypeOrNull(
              instanceName,
              type: T,
              lookInScopeBelow: true,
            );

            final objectThatWouldbeShadowed =
                factoryThatWouldbeShadowed?.instance;
            if (objectThatWouldbeShadowed != null &&
                objectThatWouldbeShadowed is ShadowChangeHandlers) {
              objectThatWouldbeShadowed.onGetShadowed(instance!);
            }
          }
          return instance!;
      }
    } catch (e, s) {
      _debugOutput('Error while creating $T');
      _debugOutput('Stack trace:\n $s');
      rethrow;
    }
  }

  /// returns an async instance depending on the type of the registration if [async==true] or
  /// if [dependsOn.isNotEmpty].
  Future<R> getObjectAsync<R>(dynamic param1, dynamic param2) async {
    assert(
      !(![
            ServiceFactoryType.alwaysNew,
            ServiceFactoryType.cachedFactory,
          ].contains(factoryType) &&
          (param1 != null || param2 != null)),
      'You can only pass parameters to factories!',
    );

    throwIfNot(
      isAsync || pendingResult != null,
      StateError(
        'You can only access registered factories/objects '
        'this way if they are created asynchronously',
      ),
    );
    try {
      switch (factoryType) {
        case ServiceFactoryType.alwaysNew:
          if (asyncCreationFunctionParam != null) {
            // param1.runtimeType == param1Type should use 'is' but Dart does
            // not support this comparison. For the time being it is therefore
            // disabled
            // assert(
            //     param1 == null || param1.runtimeType == param1Type,
            //     'Incompatible Type passed a param1\n'
            //     'expected: $param1Type actual: ${param1.runtimeType}');
            // assert(
            //     param2 == null || param2.runtimeType == param2Type,
            //     'Incompatible Type passed a param2\n'
            //     'expected: $param2Type actual: ${param2.runtimeType}');
            return asyncCreationFunctionParam!(param1 as P1, param2 as P2)
                as Future<R>;
          } else {
            return asyncCreationFunction!() as Future<R>;
          }
        case ServiceFactoryType.cachedFactory:
          if (weakReferenceInstance?.target != null &&
              param1 == lastParam1 &&
              param2 == lastParam2) {
            return Future<R>.value(weakReferenceInstance!.target! as R);
          } else {
            if (creationFunctionParam != null) {
              lastParam1 = param1 as P1?;
              lastParam2 = param2 as P2?;
              return asyncCreationFunctionParam!(
                param1 as P1,
                param2 as P2,
              ).then((value) {
                weakReferenceInstance = WeakReference(value);
                return value;
              }) as Future<R>;
            } else {
              return asyncCreationFunction!().then((value) {
                weakReferenceInstance = WeakReference(value);
                return value;
              }) as Future<R>;
            }
          }
        case ServiceFactoryType.constant:
          if (instance != null) {
            return Future<R>.value(instance as R);
          } else {
            assert(pendingResult != null);
            return pendingResult! as Future<R>;
          }
        case ServiceFactoryType.lazy:
          if (instance != null) {
            // We already have a finished instance
            return Future<R>.value(instance as R);
          } else {
            if (pendingResult !=
                null) // an async creation is already in progress
            {
              return pendingResult! as Future<R>;
            }

            /// Seems this is really the first access to this async Singleton
            final asyncResult = asyncCreationFunction!();

            pendingResult = asyncResult.then((newInstance) {
              if (!shouldSignalReady) {
                /// only complete automatically if the registration wasn't marked with
                /// [signalsReady==true]
                _readyCompleter.complete();
                objectsWaiting.clear();
              }
              if (useWeakReference) {
                weakReferenceInstance = WeakReference(newInstance);
              } else {
                _instance = newInstance;
              }

              /// check if we are shadowing an existing Object
              final factoryThatWouldbeShadowed =
                  _getItInstance._findFirstFactoryByNameAndTypeOrNull(
                instanceName,
                type: T,
                lookInScopeBelow: true,
              );

              final objectThatWouldbeShadowed =
                  factoryThatWouldbeShadowed?.instance;
              if (objectThatWouldbeShadowed != null &&
                  objectThatWouldbeShadowed is ShadowChangeHandlers) {
                objectThatWouldbeShadowed.onGetShadowed(instance!);
              }
              return newInstance;
            });
            return pendingResult! as Future<R>;
          }
      }
    } catch (e, s) {
      _debugOutput('Error while creating $T}');
      _debugOutput('Stack trace:\n $s');
      rethrow;
    }
  }
}

class _TypeRegistration<T extends Object> {
  final namedFactories =
      // ignore: prefer_collection_literals
      LinkedHashMap<String, _ServiceFactory<T, dynamic, dynamic>>();
  final factories = <_ServiceFactory<T, dynamic, dynamic>>[];

  void dispose() {
    for (final factory in factories.reversed) {
      factory.dispose();
    }
    factories.clear();
    for (final factory in namedFactories.values.toList().reversed) {
      factory.dispose();
    }
    namedFactories.clear();
  }

  bool get isEmpty => factories.isEmpty && namedFactories.isEmpty;

  _ServiceFactory<T, dynamic, dynamic>? getFactory(String? name) {
    return name != null ? namedFactories[name] : factories.firstOrNull;
  }
}

class _Scope {
  final String? name;
  final ScopeDisposeFunc? disposeFunc;
  bool isFinal = false;
  bool isPopping = false;
  // ignore: prefer_collection_literals
  final typeRegistrations =
      // ignore: prefer_collection_literals
      LinkedHashMap<Type, _TypeRegistration>();

  _Scope({this.name, this.disposeFunc});

  Future<void> reset({required bool dispose}) async {
    if (dispose) {
      for (final factory in allFactories.reversed) {
        await factory.dispose();
      }
    }
    typeRegistrations.clear();
  }

  List<_ServiceFactory> get allFactories =>
      typeRegistrations.values.fold<List<_ServiceFactory>>(
        [],
        (sum, x) => sum..addAll([...x.factories, ...x.namedFactories.values]),
      );

  Future<void> dispose() async {
    await disposeFunc?.call();
  }

  Iterable<T> getAll<T extends Object>({dynamic param1, dynamic param2}) {
    final _TypeRegistration<T>? typeRegistration =
        typeRegistrations[T] as _TypeRegistration<T>?;

    if (typeRegistration == null) {
      return [];
    }

    final factories = [
      ...typeRegistration.factories,
      ...typeRegistration.namedFactories.values,
    ];
    final instances = <T>[];
    for (final instanceFactory in factories) {
      final T instance;
      if (instanceFactory.isAsync || instanceFactory.pendingResult != null) {
        /// We use an assert here instead of an `if..throw` for performance reasons
        assert(
          instanceFactory.factoryType == ServiceFactoryType.constant ||
              instanceFactory.factoryType == ServiceFactoryType.lazy,
          "You can't use getAll with an async Factory of $T.",
        );
        throwIfNot(
          instanceFactory.isReady,
          StateError(
            'You tried to access an instance of $T that is not ready yet',
          ),
        );
        instance = instanceFactory.instance!;
      } else {
        instance = instanceFactory.getObject(param1, param2);
      }

      instances.add(instance);
    }
    return instances;
  }

  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
  }) async {
    final _TypeRegistration<T>? typeRegistration =
        typeRegistrations[T] as _TypeRegistration<T>?;

    if (typeRegistration == null) {
      return [];
    }

    final factories = [
      ...typeRegistration.factories,
      ...typeRegistration.namedFactories.values,
    ];
    final instances = <T>[];
    for (final instanceFactory in factories) {
      final T instance;
      if (instanceFactory.isAsync || instanceFactory.pendingResult != null) {
        instance = await instanceFactory.getObjectAsync(param1, param2);
      } else {
        instance = instanceFactory.getObject(param1, param2);
      }
      instances.add(instance);
    }
    return instances;
  }
}

class _GetItImplementation implements GetIt {
  static const _baseScopeName = 'baseScope';
  final _scopes = [_Scope(name: _baseScopeName)];

  _Scope get _currentScope => _scopes.last;

  _GetItImplementation();

  @override
  void Function(bool pushed)? onScopeChanged;

  /// We still support a global ready signal mechanism for that we use this
  /// Completer.
  final _globalReadyCompleter = Completer();

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  @override
  bool allowReassignment = false;

  /// By default it's throws error when [allowReassignment]= false. and trying to register same type
  /// If you really need, you can disable the Asserts / Error by setting[skipDoubleRegistration]= true
  @visibleForTesting
  @override
  bool skipDoubleRegistration = false;
  @override
  void enableRegisteringMultipleInstancesOfOneType() {
    allowRegisterMultipleImplementationsOfoneType = true;
  }

  @override
  bool allowRegisterMultipleImplementationsOfoneType = false;

  /// Is used by several other functions to retrieve the correct [_ServiceFactory]
  _ServiceFactory<T, dynamic, dynamic>?
      _findFirstFactoryByNameAndTypeOrNull<T extends Object>(
          String? instanceName,
          {Type? type,
          bool lookInScopeBelow = false}) {
    /// We use an assert here instead of an `if..throw` because it gets called on every call
    /// of [get]
    /// `(const Object() is! T)` tests if [T] is a real type and not Object or dynamic
    assert(
      type != null || const Object() is! T,
      'GetIt: The compiler could not infer the type. You have to provide a type '
      'and optionally a name. Did you accidentally do `var sl=GetIt.instance();` '
      'instead of var sl=GetIt.instance;',
    );

    _ServiceFactory<T, dynamic, dynamic>? instanceFactory;

    int scopeLevel = _scopes.length - (lookInScopeBelow ? 2 : 1);

    final lookUpType = type ?? T;
    while (instanceFactory == null && scopeLevel >= 0) {
      final _TypeRegistration? typeRegistration =
          _scopes[scopeLevel].typeRegistrations[lookUpType];

      final foundFactory = typeRegistration?.getFactory(instanceName);
      assert(
        foundFactory is _ServiceFactory<T, dynamic, dynamic>?,
        'It looks like you have passed your lookup type via the `type` but '
        'but the receiving variable is not a compatible type.',
      );

      instanceFactory = foundFactory as _ServiceFactory<T, dynamic, dynamic>?;
      scopeLevel--;
    }

    return instanceFactory;
  }

  /// Is used by several other functions to retrieve the correct [_ServiceFactory]
  _ServiceFactory _findFactoryByNameAndType<T extends Object>(
    String? instanceName, [
    Type? type,
  ]) {
    final instanceFactory = _findFirstFactoryByNameAndTypeOrNull<T>(
      instanceName,
      type: type,
    );

    throwIfNot(
      instanceFactory != null,
      // ignore: missing_whitespace_between_adjacent_strings
      StateError(
        'GetIt: Object/factory with ${instanceName != null ? 'with name $instanceName and ' : ''}'
        'type $T is not registered inside GetIt. '
        '\n(Did you accidentally do GetIt sl=GetIt.instance(); instead of GetIt sl=GetIt.instance;'
        '\nDid you forget to register it?)',
      ),
    );

    return instanceFactory!;
  }

  /// retrieves or creates an instance of a registered type [T] depending on the registration
  /// function used for this type or based on a name.
  /// for factories you can pass up to 2 parameters [param1,param2] they have to match the types
  /// given at registration with [registerFactoryParam()]
  @override
  T get<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    return _get<T>(
      instanceName: instanceName,
      param1: param1,
      param2: param2,
      type: type,
    )!;
  }

  @override
  T? maybeGet<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    return _get<T>(
        instanceName: instanceName,
        param1: param1,
        param2: param2,
        type: type,
        throwIfNotFound: false);
  }

  T? _get<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
    bool throwIfNotFound = true,
  }) {
    final _ServiceFactory<Object, dynamic, dynamic>? instanceFactory;
    if (throwIfNotFound) {
      instanceFactory = _findFactoryByNameAndType<T>(instanceName, type);
    } else {
      instanceFactory =
          _findFirstFactoryByNameAndTypeOrNull<T>(instanceName, type: type);
      if (instanceFactory == null) {
        return null;
      }
    }

    final Object instance;
    if (instanceFactory.isAsync || instanceFactory.pendingResult != null) {
      /// We use an assert here instead of an `if..throw` for performance reasons
      assert(
        instanceFactory.factoryType == ServiceFactoryType.constant ||
            instanceFactory.factoryType == ServiceFactoryType.lazy,
        "You can't use get with an async Factory of ${instanceName ?? T.toString()}.",
      );
      throwIfNot(
        instanceFactory.isReady,
        StateError(
          'You tried to access an instance of ${instanceName ?? T.toString()} that is not ready yet',
        ),
      );
      instance = instanceFactory.instance!;
    } else {
      instance = instanceFactory.getObject(param1, param2);
    }

    assert(
      instance is T,
      'Object with name $instanceName has a different type '
      '(${instanceFactory.registrationType}) than the one that is inferred '
      '($T) where you call it',
    );

    return instance as T;
  }

  @override
  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
  }) {
    final Iterable<T> instances;
    if (!fromAllScopes) {
      instances = _currentScope.getAll<T>(param1: param1, param2: param2);
    } else {
      instances = [
        for (final scope in _scopes)
          ...scope.getAll<T>(param1: param1, param2: param2),
      ];
    }

    throwIf(
      instances.isEmpty,
      StateError(
        'GetIt: No Objects/factories with '
        'type $T are not registered inside GetIt. '
        '\n(Did you accidentally do GetIt sl=GetIt.instance(); instead of GetIt sl=GetIt.instance;'
        '\nDid you forget to register it?)',
      ),
    );

    return instances;
  }

  /// Callable class so that you can write `GetIt.instance<MyType>` instead of
  /// `GetIt.instance.get<MyType>`
  @override
  T call<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    return get<T>(
      instanceName: instanceName,
      param1: param1,
      param2: param2,
      type: type,
    );
  }

  /// Returns a Future of an instance that is created by an async factory or a Singleton that is
  /// not ready with its initialization.
  /// for async factories you can pass up to 2 parameters [param1,param2] they have to match
  /// the types given at registration with [registerFactoryParamAsync()]
  @override
  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    final factoryToGet = _findFactoryByNameAndType<T>(instanceName, type);
    return factoryToGet.getObjectAsync<T>(param1, param2);
  }

  @override
  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
  }) async {
    final Iterable<T> instances;
    if (!fromAllScopes) {
      instances = await _currentScope.getAllAsync<T>(
        param1: param1,
        param2: param2,
      );
    } else {
      instances = [
        for (final scope in _scopes)
          ...await scope.getAllAsync<T>(param1: param1, param2: param2),
      ];
    }

    throwIf(
      instances.isEmpty,
      StateError(
        'GetIt: No Objects/factories with '
        'type $T are not registered inside GetIt. '
        '\n(Did you accidentally do GetIt sl=GetIt.instance(); instead of GetIt sl=GetIt.instance;'
        '\nDid you forget to register it?)',
      ),
    );

    return instances;
  }

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [factoryFunc] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  @override
  void registerFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, void, void>(
      type: ServiceFactoryType.alwaysNew,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
    );
  }

  @override
  void registerCachedFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, void, void>(
      type: ServiceFactoryType.cachedFactory,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
      useWeakReference: true,
    );
  }

  @override
  void registerCachedFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, P1, P2>(
      type: ServiceFactoryType.cachedFactory,
      instanceName: instanceName,
      factoryFuncParam: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
      useWeakReference: true,
    );
  }

  @override
  void registerCachedFactoryAsync<T extends Object>(
      FactoryFuncAsync<T> factoryFunc,
      {String? instanceName}) {
    _register<T, void, void>(
      type: ServiceFactoryType.cachedFactory,
      instanceName: instanceName,
      factoryFuncAsync: factoryFunc,
      isAsync: true,
      shouldSignalReady: false,
      useWeakReference: true,
    );
  }

  @override
  void registerCachedFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, P1, P2>(
      type: ServiceFactoryType.cachedFactory,
      instanceName: instanceName,
      factoryFuncParamAsync: factoryFunc,
      isAsync: true,
      shouldSignalReady: false,
      useWeakReference: true,
    );
  }

  /// registers a type so that a new instance will be created on each call of [get] on that
  /// type based on up to two parameters provided to [get()]
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
  @override
  void registerFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, P1, P2>(
      type: ServiceFactoryType.alwaysNew,
      instanceName: instanceName,
      factoryFuncParam: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
    );
  }

  /// We use a separate function for the async registration instead of just a new parameter
  /// so make the intention explicit
  @override
  void registerFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, void, void>(
      type: ServiceFactoryType.alwaysNew,
      instanceName: instanceName,
      factoryFuncAsync: factoryFunc,
      isAsync: true,
      shouldSignalReady: false,
    );
  }

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
  @override
  void registerFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, P1, P2>(
      type: ServiceFactoryType.alwaysNew,
      instanceName: instanceName,
      factoryFuncParamAsync: factoryFunc,
      isAsync: true,
      shouldSignalReady: false,
    );
  }

  /// registers a type as Singleton by passing a factory function that will be called
  /// on the first call of [get] on that type
  /// [T] type to register
  /// [factoryFunc] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [registerLazySingleton] does not influence [allReady] however you can wait
  /// for and be dependent on a LazySingleton.
  @override
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    bool useWeakReference = false,
  }) {
    _register<T, void, void>(
      type: ServiceFactoryType.lazy,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
      disposeFunc: dispose,
      useWeakReference: useWeakReference,
    );
  }

  /// registers a type as Singleton by passing an [instance] of that type
  ///  that will be returned on each call of [get] on that type
  /// [T] type to register
  /// If [signalsReady] is set to `true` it means that the future you can get from `allReady()`
  /// cannot complete until this registration was signalled ready by calling
  /// [signalsReady(instance)] [instanceName] if you provide a value here your instance gets
  /// registered with that name instead of a type. This should only be necessary if you need
  /// to register more than one instance of one type.
  @override
  T registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      type: ServiceFactoryType.constant,
      instanceName: instanceName,
      instance: instance,
      isAsync: false,
      shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
      disposeFunc: dispose,
    );
    return instance;
  }

  /// Only registers a type new as Singleton if it is not already registered. Otherwise it returns
  /// the existing instance and increments an internal reference counter to ensure that matching
  /// [unregister] or [releaseInstance] calls will decrement the reference counter an won't unregister
  /// and dispose the registration as long as the reference counter is > 0.
  /// [T] type/interface that is used for the registration and the access via [get]
  /// [factoryFunc] that is called to create the instance if it is not already registered
  /// [instanceName] optional key to register more than one instance of one type
  /// [dispose] disposing function that is automatically called before the object is removed from get_it
  @override
  T registerSingletonIfAbsent<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  }) {
    final existingFactory = _findFirstFactoryByNameAndTypeOrNull<T>(
      instanceName,
    );
    if (existingFactory != null) {
      throwIfNot(
        existingFactory.factoryType == ServiceFactoryType.constant &&
            !existingFactory.isAsync,
        StateError(
          'registerSingletonIfAbsent can only be called for a type that is already registered as Singleton and not for factories or async/lazy Singletons',
        ),
      );
      existingFactory._referenceCount++;
      return existingFactory.instance!;
    }

    final instance = factoryFunc();
    _register<T, void, void>(
      type: ServiceFactoryType.constant,
      instance: instance,
      instanceName: instanceName,
      isAsync: false,
      shouldSignalReady: false,
      disposeFunc: dispose,
    );
    return instance;
  }

  /// checks if a registered Singleton has an reference counter > 0
  /// if so it decrements the reference counter and if it reaches 0 it
  /// unregisters the Singleton
  /// if called on an object that's reference counter was never incremented
  /// it will immediately unregister and dispose the object
  @override
  void releaseInstance(Object instance) {
    final registeredFactory = _findFactoryByInstance(instance);
    if (registeredFactory._referenceCount < 1) {
      assert(
        registeredFactory._referenceCount == 0,
        'GetIt: releaseInstance was called on an object that was already released',
      );
      unregister(instance: instance);
    } else {
      registeredFactory._referenceCount--;
    }
  }

  /// registers a type as Singleton by passing an factory function of that type
  /// that will be called on each call of [get] on that type
  /// [T] type to register
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [dependsOn] if this instance depends on other registered Singletons before it can be initialized
  /// you can either orchestrate this manually using [isReady()] or pass a list of the types that the
  /// instance depends on here. [factoryFunc] won't get executed till these types are ready.
  /// [func] is called
  /// If [signalsReady] is set to `true` it means that the future you can get from `allReady()`
  /// cannot complete until this instance was signalled ready by calling [signalsReady(instance)].
  @override
  void registerSingletonWithDependencies<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    required Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      type: ServiceFactoryType.constant,
      instanceName: instanceName,
      isAsync: false,
      factoryFunc: factoryFunc,
      dependsOn: dependsOn,
      shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
      disposeFunc: dispose,
    );
  }

  /// registers a type as Singleton by passing an asynchronous factory function which has to
  /// return the instance that will be returned on each call of [get] on that type.
  /// Therefore you have to ensure that the instance is ready before you use [get] on it or use
  /// [getAsync()] to wait for the completion.
  /// You can wait/check if the instance is ready by using [isReady()] and [isReadySync()].
  /// [factoryFunc] is executed immediately if there are no dependencies to other Singletons
  /// (see below). As soon as it returns, this instance is marked as ready unless you don't set
  /// [signalsReady==true] [instanceName] if you provide a value here your instance gets
  /// registered with that name instead of a type. This should only be necessary if you need
  /// to register more than one instance of one type.
  /// [dependsOn] if this instance depends on other registered Singletons before it can be
  /// initialized you can either orchestrate this manually using [isReady()] or pass a list of
  /// the types that the instance depends on here. [factoryFunc] won't get executed till this
  /// types are ready. If [signalsReady] is set to `true` it means that the future you can get
  /// from `allReady()` cannot complete until this instance was signalled ready by calling
  /// [signalsReady(instance)]. In that case no automatic ready signal is made after
  /// completion of [factoryFunc]
  @override
  void registerSingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      type: ServiceFactoryType.constant,
      instanceName: instanceName,
      isAsync: true,
      factoryFuncAsync: factoryFunc,
      dependsOn: dependsOn,
      shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
      disposeFunc: dispose,
    );
  }

  /// registers a type as Singleton by passing an async factory function that will be called
  /// on the first call of [getAsync] on that type
  /// This is a rather esoteric requirement so you should seldom have the need to use it.
  /// This factory function [providerFunc] isn't called immediately but wait till the first call by
  /// [getAsync()] or [isReady()] is made
  /// To control if an async Singleton has completed its [providerFunc] gets a `Completer` passed
  /// as parameter that has to be completed to signal that this instance is ready.
  /// Therefore you have to ensure that the instance is ready before you use [get] on it or
  /// use [getAsync()] to wait for the completion.
  /// You can wait/check if the instance is ready by using [isReady()] and [isReadySync()].
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [registerLazySingletonAsync] does not influence [allReady] however you can wait
  /// for and be dependent on a LazySingleton.
  @override
  void registerLazySingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    bool useWeakReference = false,
  }) {
    _register<T, void, void>(
      isAsync: true,
      type: ServiceFactoryType.lazy,
      instanceName: instanceName,
      factoryFuncAsync: factoryFunc,
      shouldSignalReady: false,
      disposeFunc: dispose,
      useWeakReference: useWeakReference,
    );
  }

  @override
  ServiceFactory? findFirstFactory<T extends Object>(
      {Object? instance, String? instanceName}) {
    if (instance != null) {
      return _findFirstFactoryByInstanceOrNull(instance);
    } else {
      return _findFirstFactoryByNameAndTypeOrNull<T>(instanceName);
    }
  }

  /// Tests if an [instance] of an object or aType [T] or a name [instanceName]
  /// is registered inside GetIt
  @override
  bool isRegistered<T extends Object>({
    Object? instance,
    String? instanceName,
    Type? type,
  }) {
    if (instance != null) {
      return _findFirstFactoryByInstanceOrNull(instance) != null;
    } else {
      return _findFirstFactoryByNameAndTypeOrNull<T>(
            instanceName,
            type: type,
          ) !=
          null;
    }
  }

  /// Unregister an instance of an object or a factory/singleton by Type [T] or by name [instanceName]
  /// if you need to dispose any resources you can pass in a [disposingFunction] function
  /// that provides an instance of your class to be disposed
  /// If you have provided an disposing function when you registered the object that one will be called automatically
  /// If you have enabled reference counting when registering, [unregister] will only unregister and dispose the object
  /// if referenceCount is 0
  ///
  @override
  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
    bool ignoreReferenceCount = false,
  }) async {
    final factoryToRemove = instance != null
        ? _findFactoryByInstance(instance)
        : _findFactoryByNameAndType<T>(instanceName);

    throwIf(
      factoryToRemove.objectsWaiting.isNotEmpty,
      StateError(
        'There are still other objects waiting for this instance so signal ready',
      ),
    );

    if (factoryToRemove._referenceCount > 0 && !ignoreReferenceCount) {
      factoryToRemove._referenceCount--;
      return;
    }
    final typeRegistration = factoryToRemove.registeredIn;

    if (factoryToRemove.isNamedRegistration) {
      typeRegistration.namedFactories.remove(factoryToRemove.instanceName);
    } else {
      typeRegistration.factories.remove(factoryToRemove);
    }
    if (typeRegistration.isEmpty) {
      factoryToRemove.registrationScope.typeRegistrations.remove(T);
    }

    if (factoryToRemove.instance != null) {
      if (disposingFunction != null) {
        final dispose = disposingFunction.call(factoryToRemove.instance! as T);
        if (dispose is Future) {
          await dispose;
        }
      } else {
        final dispose = factoryToRemove.dispose();
        if (dispose is Future) {
          await dispose;
        }
      }
    }
  }

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
  @override
  void changeTypeInstanceName<T extends Object>({
    String? instanceName,
    required String newInstanceName,
    T? instance,
  }) {
    assert(
      instance != null || instanceName != null,
      'You have to provide either an instance or an instanceName',
    );

    final factoryToRename = instance != null
        ? _findFactoryByInstance(instance)
        : _findFactoryByNameAndType<T>(instanceName);

    if (instance != null) {
      instanceName = factoryToRename.instanceName;
    }

    throwIfNot(
      factoryToRename.isNamedRegistration,
      StateError('This instance $instance is not registered with a name'),
    );

    final typeRegistration = factoryToRename.registeredIn;
    throwIf(
      typeRegistration.namedFactories.containsKey(newInstanceName),
      StateError(
        'There is already an instance of type ${factoryToRename.registrationType} registered with the name $newInstanceName',
      ),
    );

    typeRegistration.namedFactories[newInstanceName] = factoryToRename;
    typeRegistration.namedFactories.remove(instanceName);
    factoryToRename.instanceName = newInstanceName;
  }

  /// Clears the instance of a lazy singleton,
  /// being able to call the factory function on the next call
  /// of [get] on that type again.
  /// you select the lazy Singleton you want to reset by either providing
  /// an [instance], its registered type [T] or its registration name.
  /// if you need to dispose some resources before the reset, you can
  /// provide a [disposingFunction]
  @override
  FutureOr resetLazySingleton<T extends Object>({
    T? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  }) async {
    _ServiceFactory instanceFactory;

    if (instance != null) {
      instanceFactory = _findFactoryByInstance(instance);
    } else {
      instanceFactory = _findFactoryByNameAndType<T>(instanceName);
    }
    throwIfNot(
      instanceFactory.factoryType == ServiceFactoryType.lazy,
      StateError(
        'There is no type ${instance.runtimeType} registered as LazySingleton in GetIt',
      ),
    );

    dynamic disposeReturn;
    if (instanceFactory.instance != null) {
      if (disposingFunction != null) {
        disposeReturn = disposingFunction.call(instanceFactory.instance! as T);
      } else {
        disposeReturn = instanceFactory.dispose();
      }
    }

    instanceFactory.resetInstance();
    instanceFactory.pendingResult = null;
    instanceFactory._readyCompleter = Completer();
    if (disposeReturn is Future) {
      await disposeReturn;
    }
  }

  @override
  bool checkLazySingletonInstanceExists<T extends Object>({
    String? instanceName,
  }) {
    final instanceFactory = _findFactoryByNameAndType<T>(instanceName);
    throwIfNot(
      instanceFactory.factoryType == ServiceFactoryType.lazy,
      StateError(
        'There is no type $T  with name $instanceName registered as LazySingleton in GetIt',
      ),
    );

    return instanceFactory.instance != null;
  }

  List<_ServiceFactory> get _allFactories => _scopes
      .fold<List<_ServiceFactory>>([], (sum, x) => sum..addAll(x.allFactories));

  _ServiceFactory? _findFirstFactoryByInstanceOrNull(Object instance) {
    return _allFactories.firstWhereOrNull(
      (x) => identical(x.instance, instance),
    );
  }

  _ServiceFactory _findFactoryByInstance(Object instance) {
    final registeredFactory = _findFirstFactoryByInstanceOrNull(instance);

    throwIf(
      registeredFactory == null,
      StateError(
        'This instance of the type ${instance.runtimeType} is not available in GetIt '
        'If you have registered it as LazySingleton, are you sure you have used '
        'it at least once?',
      ),
    );

    return registeredFactory!;
  }

  /// Clears all registered types. Handy when writing unit tests.
  @override
  Future<void> reset({bool dispose = true}) async {
    if (dispose) {
      for (int level = _scopes.length - 1; level >= 0; level--) {
        await _scopes[level].dispose();
        await _scopes[level].reset(dispose: dispose);
      }
    }
    _scopes.removeRange(1, _scopes.length);
    await resetScope(dispose: dispose);
  }

  /// Clears all registered types of the current scope in the reverse order in which they were registered.
  @override
  Future<void> resetScope({bool dispose = true}) async {
    if (dispose) {
      await _currentScope.dispose();
    }
    await _currentScope.reset(dispose: dispose);
  }

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
  @override
  void pushNewScope({
    void Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal = false,
  }) {
    throwIf(
      _pushScopeInProgress,
      StateError(
        'you can not push a new scope '
        'inside the init function of another scope',
      ),
    );
    assert(
      scopeName != _baseScopeName,
      'This name is reserved for the real base scope.',
    );
    assert(
      scopeName == null ||
          _scopes.firstWhereOrNull((x) => x.name == scopeName) == null,
      'You already have used the scope name $scopeName',
    );
    _pushScopeInProgress = true;
    _scopes.add(_Scope(name: scopeName, disposeFunc: dispose));
    try {
      init?.call(this);
      if (isFinal) {
        _scopes.last.isFinal = true;
      }
      onScopeChanged?.call(true);
    } catch (e) {
      final failedScope = _scopes.last;

      /// prevent any new registrations in this scope
      failedScope.isFinal = true;
      failedScope.reset(dispose: true);
      _scopes.removeLast();
      rethrow;
    } finally {
      _pushScopeInProgress = false;
    }
  }

  bool _pushScopeInProgress = false;

  /// Creates a new registration scope. If you register types after creating
  /// a new scope they will hide any previous registration of the same type.
  /// Scopes allow you to manage different live times of your Objects.
  /// [scopeName] if you name a scope you can pop all scopes above the named one
  /// by using the name.
  /// [dispose] function that will be called when you pop this scope. The scope
  /// is still valid while it is executed
  /// [init] optional asynchronous function to register Objects immediately after the new scope is
  /// pushed. This ensures that [onScopeChanged] will be called after their registration
  /// if [isFinal] is set to true, you can't register any new objects in this scope after
  /// this call. In Other words you have to register the objects for this scope inside
  @override
  Future<void> pushNewScopeAsync({
    Future<void> Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal = false,
  }) async {
    throwIf(
      _pushScopeInProgress,
      StateError(
        'you can not push a new scope '
        'inside the init function of another scope',
      ),
    );
    assert(
      scopeName != _baseScopeName,
      'This name is reserved for the real base scope.',
    );
    assert(
      scopeName == null ||
          _scopes.firstWhereOrNull((x) => x.name == scopeName) == null,
      'You already have used the scope name $scopeName',
    );
    _pushScopeInProgress = true;
    _scopes.add(_Scope(name: scopeName, disposeFunc: dispose));
    try {
      await init?.call(this);

      if (isFinal) {
        _scopes.last.isFinal = true;
      }
      onScopeChanged?.call(true);
    } catch (e) {
      final failedScope = _scopes.last;

      /// prevent any new registrations in this scope
      failedScope.isFinal = true;
      await failedScope.reset(dispose: true);
      _scopes.removeLast();
      rethrow;
    } finally {
      _pushScopeInProgress = false;
    }
  }

  /// Disposes all factories/Singletons that have been registered in this scope
  /// (in the reverse order in which they were registered)
  /// and pops (destroys) the scope so that the previous scope gets active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is popped.
  /// As dispose functions can be async, you should await this function.
  @override
  Future<void> popScope() async {
    if (_currentScope.isPopping) {
      return;
    }
    throwIf(
      _pushScopeInProgress,
      StateError(
        'you can not pop a scope '
        'inside the init function of another scope',
      ),
    );
    throwIfNot(
      _scopes.length > 1,
      StateError(
        "GetIt: You are already on the base scope. you can't pop this one",
      ),
    );
    // make sure that nothing new can be registered in this scope
    // while the scopes async dispose functions are running
    final scopeToPop = _currentScope;
    scopeToPop.isFinal = true;
    scopeToPop.isPopping = true;
    await scopeToPop.dispose();
    await scopeToPop.reset(dispose: true);
    _scopes.remove(scopeToPop);
    onScopeChanged?.call(false);
  }

  /// if you have a lot of scopes with names you can pop (see [popScope]) all scopes above
  /// the scope with [scopeName] including that scope
  /// Scopes are popped in order from the top
  /// As dispose functions can be async, you should await this function.
  @override
  Future<bool> popScopesTill(String scopeName, {bool inclusive = true}) async {
    assert(
      scopeName != _baseScopeName || !inclusive,
      "You can't pop the base scope",
    );
    if (!hasScope(scopeName)) {
      return false;
    }
    String? poppedScopeName;
    _Scope nextScopeToPop = _currentScope;
    bool somethingWasPopped = false;

    while (nextScopeToPop.name != _baseScopeName &&
        hasScope(scopeName) &&
        (nextScopeToPop.name != scopeName || inclusive)) {
      poppedScopeName = nextScopeToPop.name;
      await dropScope(poppedScopeName!);
      somethingWasPopped = true;
      nextScopeToPop = _scopes.lastWhere((x) => x.isPopping == false);
    }

    if (somethingWasPopped) {
      onScopeChanged?.call(false);
    }
    return somethingWasPopped;
  }

  /// Disposes all registered factories and singletons in the provided scope
  /// (in the reverse order in which they were registered),
  /// then drops (destroys) the scope. If the dropped scope was the last one,
  /// the previous scope becomes active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is dropped.
  /// As dispose functions can be async, you should await this function.
  @override
  Future<void> dropScope(String scopeName) async {
    throwIf(
      _pushScopeInProgress,
      StateError(
        'you can not drop a scope '
        'inside the init function of another scope',
      ),
    );
    if (currentScopeName == scopeName) {
      return popScope();
    }

    throwIfNot(
      _scopes.length > 1,
      StateError(
        "GetIt: You are already on the base scope. you can't drop this one",
      ),
    );
    final scope = _scopes.lastWhere(
      (s) => s.name == scopeName,
      orElse: () => throw ArgumentError("Scope $scopeName not found"),
    );
    if (scope.isPopping) {
      /// due to some race conditions it is possible that a scope is already
      /// popping when we try to drop it.
      return;
    }
    // make sure that nothing new can be registered in this scope
    // while the scopes async dispose functions are running
    scope.isFinal = true;
    scope.isPopping = true;
    await scope.dispose();
    await scope.reset(dispose: true);
    _scopes.remove(scope);
  }

  /// Tests if the scope by name [scopeName] is registered in GetIt
  @override
  bool hasScope(String scopeName) {
    return _scopes.any((x) => x.name == scopeName);
  }

  @override
  String? get currentScopeName => _currentScope.name;

  void _register<T extends Object, P1, P2>({
    required ServiceFactoryType type,
    FactoryFunc<T>? factoryFunc,
    FactoryFuncParam<T, P1, P2>? factoryFuncParam,
    FactoryFuncAsync<T>? factoryFuncAsync,
    FactoryFuncParamAsync<T, P1, P2>? factoryFuncParamAsync,
    T? instance,
    required String? instanceName,
    required bool isAsync,
    Iterable<Type>? dependsOn,
    required bool shouldSignalReady,
    DisposingFunc<T>? disposeFunc,
    bool useWeakReference = false,
  }) {
    throwIfNot(
      const Object() is! T,
      'GetIt: You have to provide type. Did you accidentally do `var sl=GetIt.instance();` '
      'instead of var sl=GetIt.instance;',
    );

    _Scope registrationScope;
    int i = _scopes.length;
    // find the first not final scope
    do {
      i--;
      registrationScope = _scopes[i];
    } while (registrationScope.isFinal && i >= 0);
    assert(
      i >= 0,
      'The baseScope should always be open. If you see this error please file an issue at',
    );

    final existingTypeRegistration = registrationScope.typeRegistrations[T];
    // if we already have a registration for this type we have to check if its a valid re-registration
    if (existingTypeRegistration != null) {
      if (instanceName != null) {
        throwIf(
          existingTypeRegistration.namedFactories.containsKey(instanceName) &&
              !allowReassignment &&
              !skipDoubleRegistration,
          ArgumentError(
            'Object/factory with name $instanceName and '
            'type $T is already registered inside GetIt. ',
          ),
        );

        /// skip double registration
        if (skipDoubleRegistration &&
            !allowReassignment &&
            existingTypeRegistration.namedFactories.containsKey(instanceName)) {
          return;
        }
      } else {
        if (existingTypeRegistration.factories.isNotEmpty) {
          throwIfNot(
            allowReassignment ||
                allowRegisterMultipleImplementationsOfoneType ||
                skipDoubleRegistration,
            ArgumentError('Type $T is already registered inside GetIt. '),
          );

          /// skip double registration
          if (skipDoubleRegistration && !allowReassignment) {
            return;
          }
        }
      }
    }

    if (instance != null) {
      /// check if we are shadowing an existing Object
      final factoryThatWouldbeShadowed = _findFirstFactoryByNameAndTypeOrNull(
        instanceName,
        type: T,
      );

      final objectThatWouldbeShadowed = factoryThatWouldbeShadowed?.instance;
      if (objectThatWouldbeShadowed != null &&
          objectThatWouldbeShadowed is ShadowChangeHandlers) {
        objectThatWouldbeShadowed.onGetShadowed(instance);
      }
    }

    final typeRegistration = registrationScope.typeRegistrations.putIfAbsent(
      T,
      () => _TypeRegistration<T>(),
    );

    final serviceFactory = _ServiceFactory<T, P1, P2>(
      this,
      type,
      registeredIn: typeRegistration,
      registrationScope: registrationScope,
      creationFunction: factoryFunc,
      creationFunctionParam: factoryFuncParam,
      asyncCreationFunctionParam: factoryFuncParamAsync,
      asyncCreationFunction: factoryFuncAsync,
      instance: instance,
      isAsync: isAsync,
      instanceName: instanceName,
      shouldSignalReady: shouldSignalReady,
      disposeFunction: disposeFunc,
      useWeakReference: useWeakReference,
    );

    if (instanceName != null) {
      typeRegistration.namedFactories[instanceName] = serviceFactory;
    } else {
      if (allowRegisterMultipleImplementationsOfoneType) {
        typeRegistration.factories.add(serviceFactory);
      } else {
        if (typeRegistration.factories.isNotEmpty) {
          typeRegistration.factories[0] = serviceFactory;
        } else {
          typeRegistration.factories.add(serviceFactory);
        }
      }
    }

    // simple Singletons get are already created, nothing else has to be done
    if (type == ServiceFactoryType.constant &&
        !shouldSignalReady &&
        !isAsync &&
        (dependsOn?.isEmpty ?? true)) {
      return;
    }

    // if it's an async or a dependent Singleton we start its creation function here after we check if
    // it is dependent on other registered Singletons.
    if ((isAsync || (dependsOn?.isNotEmpty ?? false)) &&
        type == ServiceFactoryType.constant) {
      /// Any client awaiting the completion of this Singleton
      /// Has to wait for the completion of the Singleton itself as well
      /// as for the completion of all the Singletons this one depends on
      /// For this we use [outerFutureGroup]
      /// A `FutureGroup` completes only if it's closed and all contained
      /// Futures have completed
      final outerFutureGroup = FutureGroup();
      Future dependentFuture;

      if (dependsOn?.isNotEmpty ?? false) {
        /// To wait for the completion of all Singletons this one is depending on
        /// before we start to create itself we use [dependentFutureGroup]
        final dependentFutureGroup = FutureGroup();

        for (final dependency in dependsOn!) {
          late final _ServiceFactory<Object, dynamic, dynamic>?
              dependentFactory;
          if (dependency is InitDependency) {
            dependentFactory = _findFirstFactoryByNameAndTypeOrNull(
              dependency.instanceName,
              type: dependency.type,
            );
          } else {
            dependentFactory = _findFirstFactoryByNameAndTypeOrNull(
              null,
              type: dependency,
            );
          }
          throwIf(
            dependentFactory == null,
            ArgumentError(
              'Dependent Type $dependency is not registered in GetIt',
            ),
          );
          throwIfNot(
            dependentFactory!.canBeWaitedFor,
            ArgumentError(
              'Dependent Type $dependency is not an async Singleton',
            ),
          );
          dependentFactory.objectsWaiting.add(serviceFactory.registrationType);
          dependentFutureGroup.add(dependentFactory._readyCompleter.future);
        }
        dependentFutureGroup.close();

        dependentFuture = dependentFutureGroup.future;
      } else {
        /// if we have no dependencies we still create a dummy Future so that
        /// we can use the same code path further down
        dependentFuture = Future.sync(() {}); // directly execute then
      }
      outerFutureGroup.add(dependentFuture);

      /// if someone uses getAsync on an async Singleton that has not be started to get created
      /// because its dependent on other objects this doesn't work because [pendingResult] is
      /// not set in that case. Therefore we have to set [outerFutureGroup] as [pendingResult]
      dependentFuture.then((_) {
        Future isReadyFuture;
        if (!isAsync) {
          /// SingletonWithDependencies
          serviceFactory._instance = factoryFunc!();

          /// check if we are shadowing an existing Object
          final factoryThatWouldbeShadowed =
              _findFirstFactoryByNameAndTypeOrNull(
            instanceName,
            type: T,
            lookInScopeBelow: true,
          );

          final objectThatWouldbeShadowed =
              factoryThatWouldbeShadowed?.instance;
          if (objectThatWouldbeShadowed != null &&
              objectThatWouldbeShadowed is ShadowChangeHandlers) {
            objectThatWouldbeShadowed.onGetShadowed(serviceFactory.instance!);
          }

          if (!serviceFactory.shouldSignalReady) {
            /// As this isn't an async function we declare it as ready here
            /// if wasn't marked that it will signalReady
            isReadyFuture = Future<T>.value(serviceFactory.instance!);
            serviceFactory._readyCompleter.complete(serviceFactory.instance!);
            serviceFactory.objectsWaiting.clear();
          } else {
            isReadyFuture = serviceFactory._readyCompleter.future;
          }
        } else {
          /// Async Singleton with dependencies
          final asyncResult = factoryFuncAsync!();

          isReadyFuture = asyncResult.then((instance) {
            serviceFactory._instance = instance;

            /// check if we are shadowing an existing Object
            final factoryThatWouldbeShadowed =
                _findFirstFactoryByNameAndTypeOrNull(
              instanceName,
              type: T,
              lookInScopeBelow: true,
            );

            final objectThatWouldbeShadowed =
                factoryThatWouldbeShadowed?.instance;
            if (objectThatWouldbeShadowed != null &&
                objectThatWouldbeShadowed is ShadowChangeHandlers) {
              objectThatWouldbeShadowed.onGetShadowed(instance);
            }

            if (!serviceFactory.shouldSignalReady && !serviceFactory.isReady) {
              serviceFactory._readyCompleter.complete();
              serviceFactory.objectsWaiting.clear();
            }

            return instance;
          });
        }
        outerFutureGroup.add(isReadyFuture);
        outerFutureGroup.close();
      });

      serviceFactory.pendingResult = outerFutureGroup.future.then((
        completedFutures,
      ) {
        return serviceFactory.instance!;
      });
    }
  }

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
  @override
  void signalReady(Object? instance) {
    _ServiceFactory registeredInstance;
    if (instance != null) {
      registeredInstance = _findFactoryByInstance(instance);

      throwIfNot(
        registeredInstance.shouldSignalReady,
        ArgumentError.value(
          instance,
          'This instance of type ${instance.runtimeType} is not supposed to be '
          'signalled.\nDid you forget to set signalsReady==true when registering it?',
        ),
      );

      throwIf(
        registeredInstance.isReady,
        StateError(
          'This instance of type ${instance.runtimeType} was already signalled',
        ),
      );

      registeredInstance._readyCompleter.complete();
      registeredInstance.objectsWaiting.clear();
    } else {
      /// Manual signalReady without an instance

      /// In case that there are still factories that are marked to wait for a signal
      /// but aren't signalled we throw an error with details which objects are concerned
      final notReady = _allFactories
          .where(
            (x) =>
                (x.shouldSignalReady) && (!x.isReady) ||
                (x.pendingResult != null) && (!x.isReady),
          )
          .map<String>((x) => '${x.registrationType}/${x.instanceName}')
          .toList();
      throwIf(
        notReady.isNotEmpty,
        StateError(
          "You can't signal ready manually if you have registered instances that should "
          "signal ready or are async.\n"
          // this lint is stupid because it doesn't recognize newlines
          // ignore: missing_whitespace_between_adjacent_strings
          'Did you forget to pass an object instance?'
          'This registered types/names: $notReady should signal ready but are not ready',
        ),
      );

      _globalReadyCompleter.complete();
    }
  }

  /// returns a Future that completes if all asynchronously created Singletons and any
  /// Singleton that had [signalsReady==true] are ready.
  /// This can be used inside a FutureBuilder to change the UI as soon as all initialization
  /// is done. If you pass a [timeout], a [WaitingTimeOutException] will be thrown if not all
  /// Singletons were ready in the given time. The Exception contains details on which
  /// Singletons are not ready yet.
  @override
  Future<void> allReady({
    Duration? timeout,
    bool ignorePendingAsyncCreation = false,
  }) {
    final futures = FutureGroup();
    _allFactories
        .where(
      (x) =>
          (x.isAsync && !ignorePendingAsyncCreation ||
              (!x.isAsync &&
                  x.pendingResult != null) || // Singletons with dependencies
              x.shouldSignalReady) &&
          !x.isReady &&
          x.factoryType == _ServiceFactoryType.constant,
    )
        .forEach((f) {
      if (f.pendingResult != null) {
        futures.add(f.pendingResult!);
        if (f.shouldSignalReady) {
          futures.add(
            f._readyCompleter.future,
          ); // asyncSingleton with signalReady = true
        }
      } else {
        futures.add(
          f._readyCompleter.future,
        ); // non async singletons that have signalReady == true and not dependencies
      }
    });
    futures.close();
    if (timeout != null) {
      return futures.future.timeout(
        timeout,
        onTimeout: () async => throw _createTimeoutError(),
      );
    } else {
      return futures.future;
    }
  }

  /// Returns if all async Singletons are ready without waiting
  /// if [allReady] should not wait for the completion of async Singletons set
  /// [ignorePendingAsyncCreation==true]
  @override
  bool allReadySync([bool ignorePendingAsyncCreation = false]) {
    final notReadyTypes = _allFactories
        .where(
      (x) =>
          (x.isAsync && !ignorePendingAsyncCreation ||
                  (!x.isAsync &&
                      x.pendingResult !=
                          null) || // Singletons with dependencies
                  x.shouldSignalReady) &&
              !x.isReady &&
              x.factoryType == _ServiceFactoryType.constant ||
          x.factoryType == _ServiceFactoryType.lazy,
    )
        .map<String>((x) {
      if (x.isNamedRegistration) {
        return 'Object ${x.instanceName} has not completed';
      } else {
        return 'Registered object of Type ${x.registrationType} has not completed';
      }
    }).toList();

    /// In debug mode we print the List of not ready types/named instances
    if (notReadyTypes.isNotEmpty) {
      _debugOutput('Not yet ready objects:');
      _debugOutput(notReadyTypes);
    }
    return notReadyTypes.isEmpty;
  }

  WaitingTimeOutException _createTimeoutError() {
    final allFactories = _allFactories;
    final waitedBy = Map.fromEntries(
      allFactories
          .where(
            (x) =>
                (x.shouldSignalReady || x.pendingResult != null) &&
                !x.isReady &&
                x.objectsWaiting.isNotEmpty,
          )
          .map<MapEntry<String, List<String>>>(
            (isWaitedFor) => MapEntry(
              isWaitedFor.debugName,
              isWaitedFor.objectsWaiting
                  .map((waitedByType) => waitedByType.toString())
                  .toList(),
            ),
          ),
    );
    final notReady = allFactories
        .where(
          (x) => (x.shouldSignalReady || x.pendingResult != null) && !x.isReady,
        )
        .map((f) => f.debugName)
        .toList();
    final areReady = allFactories
        .where(
          (x) => (x.shouldSignalReady || x.pendingResult != null) && x.isReady,
        )
        .map((f) => f.debugName)
        .toList();

    return WaitingTimeOutException(waitedBy, notReady, areReady);
  }

  /// Returns a Future that completes if the instance of a Singleton, defined by Type [T] or
  /// by name [instanceName] or by passing an existing [instance], is ready
  /// If you pass a [timeout], a [WaitingTimeOutException] will be thrown if the instance
  /// is not ready in the given time. The Exception contains details on which Singletons are
  /// not ready at that time.
  /// [callee] optional parameter which makes debugging easier. Pass `this` in here.
  @override
  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  }) {
    _ServiceFactory factoryToCheck;
    if (instance != null) {
      factoryToCheck = _findFactoryByInstance(instance);
    } else {
      factoryToCheck = _findFactoryByNameAndType<T>(instanceName);
    }
    // throwIfNot(
    //   factoryToCheck.canBeWaitedFor &&
    //       factoryToCheck.factoryType != _ServiceFactoryType.alwaysNew,
    //   ArgumentError(
    //       'You only can use this function on Singletons that are async, that are marked as '
    //       'dependent or that are marked with "signalsReady==true"'),
    // );
    if (!factoryToCheck.isReady) {
      factoryToCheck.objectsWaiting.add(callee.runtimeType);
    }
    if (factoryToCheck.isAsync &&
        factoryToCheck.factoryType == ServiceFactoryType.lazy &&
        factoryToCheck.instance == null) {
      if (timeout != null) {
        return factoryToCheck.getObjectAsync(null, null).timeout(
          timeout,
          onTimeout: () {
            throw _createTimeoutError();
          },
        );
      } else {
        return factoryToCheck.getObjectAsync(null, null);
      }
    }
    if (factoryToCheck.pendingResult != null) {
      if (timeout != null) {
        return factoryToCheck.pendingResult!.timeout(
          timeout,
          onTimeout: () {
            throw _createTimeoutError();
          },
        );
      } else {
        return factoryToCheck.pendingResult!;
      }
    }
    if (timeout != null) {
      return factoryToCheck._readyCompleter.future.timeout(
        timeout,
        onTimeout: () => throw _createTimeoutError(),
      );
    } else {
      return factoryToCheck._readyCompleter.future;
    }
  }

  /// Checks if an async Singleton defined by an [instance], a type [T] or an [instanceName]
  /// is ready without waiting.
  @override
  bool isReadySync<T extends Object>({Object? instance, String? instanceName}) {
    _ServiceFactory factoryToCheck;
    if (instance != null) {
      factoryToCheck = _findFactoryByInstance(instance);
    } else {
      factoryToCheck = _findFactoryByNameAndType<T>(instanceName);
    }
    throwIfNot(
      factoryToCheck.canBeWaitedFor &&
          factoryToCheck.factoryType != ServiceFactoryType.alwaysNew,
      ArgumentError(
        'You only can use this function on async Singletons or Singletons '
        'that have ben marked with "signalsReady" or that they depend on others',
      ),
    );
    return factoryToCheck.isReady;
  }
}
