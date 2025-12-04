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

bool _devToolsExtensionRegistered = false;

void _debugOutput(Object message) {
  if (_isDebugMode) {
    if (!GetIt.noDebugOutput) {
      // ignore: avoid_print
      print(message);
    }
  }
}

/// If I use `Singleton` without specifier in the comments I mean normal and lazy
class _ObjectRegistration<T extends Object, P1, P2>
    extends ObjectRegistration<T> {
  @override
  final ObjectRegistrationType registrationType;

  final _GetItImplementation _getItInstance;
  final _TypeRegistration registeredIn;
  final _Scope registrationScope;

  /// Unique registration number for tracking registration order
  final int registrationNumber;

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

  /// Optional callback that is called after the instance has been created
  final void Function(T)? onCreatedCallback;

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
  late final Type registeredWithType;

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
  String get debugName => '$instanceName : $registeredWithType';

  @override
  bool get canBeWaitedFor =>
      shouldSignalReady || pendingResult != null || isAsync;

  final bool shouldSignalReady;

  int _referenceCount = 0;

  _ObjectRegistration(
    this._getItInstance,
    this.registrationType, {
    required this.registrationNumber,
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
    this.onCreatedCallback,
  })  : _instance = instance,
        assert(
          !(disposeFunction != null &&
              instance != null &&
              instance is Disposable),
          ' You are trying to register type ${instance.runtimeType} '
          'that implements "Disposable" but you also provide a disposing function',
        ) {
    registeredWithType = T;
    _readyCompleter = Completer();
  }

  FutureOr dispose() {
    /// check if we are shadowing an existing Object
    final registrationThatWouldbeShadowed =
        _getItInstance._findFirstRegistrationByNameAndTypeOrNull(
      instanceName,
      type: T,
      lookInScopeBelow: true,
    );

    final objectThatWouldbeShadowed = registrationThatWouldbeShadowed?.instance;
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

  /// Checks if the registered type T is a subtype of S (or the same type)
  /// Uses the generic list covariance trick: <T>[] is List<S>
  bool isSubtypeOf<S>() {
    return <T>[] is List<S>;
  }

  /// Checks if the registered type T is exactly the same as type S (not just a subtype)
  bool isExactType<S>() {
    return T == S;
  }

  /// Validates that factory parameters are compatible with their expected types.
  /// Only active in debug mode for zero production overhead.
  /// Throws ArgumentError with clear message if validation fails.
  void _validateFactoryParams(dynamic param1, dynamic param2) {
    if (!_isDebugMode) return;

    // Validate param1
    if (param1 != null || <P1?>[] is! List<P1>) {
      // param1 is provided OR P1 is non-nullable (must validate)
      if (param1 is! P1) {
        throw ArgumentError(
          "GetIt: Cannot use parameter value of type '${param1.runtimeType}' "
          "as type '$P1' for factory of type '$T'.\n"
          "${param1 == null ? 'Param1 is required (non-nullable) but null was passed.\n' : ''}"
          "Use: getIt<$T>(param1: <your $P1 value>)",
        );
      }
    }

    // Validate param2
    if (param2 != null || <P2?>[] is! List<P2>) {
      // param2 is provided OR P2 is non-nullable (must validate)
      if (param2 is! P2) {
        throw ArgumentError(
          "GetIt: Cannot use parameter value of type '${param2.runtimeType}' "
          "as type '$P2' for factory of type '$T'.\n"
          "${param2 == null ? 'Param2 is required (non-nullable) but null was passed.\n' : ''}"
          "Use: getIt<$T>(param1: <value>, param2: <your $P2 value>)",
        );
      }
    }
  }

  /// returns an instance depending on the type of the registration if [async==false]
  T getObject(dynamic param1, dynamic param2) {
    assert(
      !(![
            ObjectRegistrationType.alwaysNew,
            ObjectRegistrationType.cachedFactory,
          ].contains(registrationType) &&
          (param1 != null || param2 != null)),
      'You can only pass parameters to factories!',
    );

    try {
      switch (registrationType) {
        case ObjectRegistrationType.alwaysNew:
          if (creationFunctionParam != null) {
            // Validate parameters in debug mode
            _validateFactoryParams(param1, param2);
            return creationFunctionParam!(param1 as P1, param2 as P2);
          } else {
            return creationFunction!();
          }
        case ObjectRegistrationType.cachedFactory:
          if (weakReferenceInstance?.target != null &&
              param1 == lastParam1 &&
              param2 == lastParam2) {
            return weakReferenceInstance!.target!;
          } else {
            T newInstance;
            if (creationFunctionParam != null) {
              // Validate parameters in debug mode BEFORE casting
              _validateFactoryParams(param1, param2);
              lastParam1 = param1 as P1?;
              lastParam2 = param2 as P2?;
              newInstance = creationFunctionParam!(param1 as P1, param2 as P2);
            } else {
              newInstance = creationFunction!();
            }
            weakReferenceInstance = WeakReference(newInstance);
            return newInstance;
          }
        case ObjectRegistrationType.constant:
          return instance!;
        case ObjectRegistrationType.lazy:
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

            // Call onCreated callback if provided
            onCreatedCallback?.call(instance!);

            /// check if we are shadowing an existing Object
            final registrationThatWouldbeShadowed =
                _getItInstance._findFirstRegistrationByNameAndTypeOrNull(
              instanceName,
              type: T,
              lookInScopeBelow: true,
            );

            final objectThatWouldbeShadowed =
                registrationThatWouldbeShadowed?.instance;
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
            ObjectRegistrationType.alwaysNew,
            ObjectRegistrationType.cachedFactory,
          ].contains(registrationType) &&
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
      switch (registrationType) {
        case ObjectRegistrationType.alwaysNew:
          if (asyncCreationFunctionParam != null) {
            // Validate parameters in debug mode
            _validateFactoryParams(param1, param2);
            return asyncCreationFunctionParam!(param1 as P1, param2 as P2)
                as Future<R>;
          } else {
            return asyncCreationFunction!() as Future<R>;
          }
        case ObjectRegistrationType.cachedFactory:
          if (weakReferenceInstance?.target != null &&
              param1 == lastParam1 &&
              param2 == lastParam2) {
            return Future<R>.value(weakReferenceInstance!.target! as R);
          } else {
            if (asyncCreationFunctionParam != null) {
              // Validate parameters in debug mode BEFORE casting
              _validateFactoryParams(param1, param2);
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
        case ObjectRegistrationType.constant:
          if (instance != null) {
            return Future<R>.value(instance as R);
          } else {
            assert(pendingResult != null);
            return pendingResult! as Future<R>;
          }
        case ObjectRegistrationType.lazy:
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

              // Call onCreated callback if provided
              onCreatedCallback?.call(newInstance);

              /// check if we are shadowing an existing Object
              final registrationThatWouldbeShadowed =
                  _getItInstance._findFirstRegistrationByNameAndTypeOrNull(
                instanceName,
                type: T,
                lookInScopeBelow: true,
              );

              final objectThatWouldbeShadowed =
                  registrationThatWouldbeShadowed?.instance;
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
  final namedRegistrations =
      // ignore: prefer_collection_literals
      LinkedHashMap<String, _ObjectRegistration<T, dynamic, dynamic>>();
  final registrations = <_ObjectRegistration<T, dynamic, dynamic>>[];

  bool get isEmpty => registrations.isEmpty && namedRegistrations.isEmpty;

  _ObjectRegistration<T, dynamic, dynamic>? getRegistration(String? name) {
    return name != null ? namedRegistrations[name] : registrations.firstOrNull;
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
      // Always use strict LIFO disposal order (sorted by registrationNumber)
      final registrations = allRegistrations.toList()
        ..sort((a, b) => b.registrationNumber.compareTo(a.registrationNumber));

      for (final registration in registrations) {
        // Complete pending completers so allReady() can complete
        if (!registration.isReady) {
          registration._readyCompleter.complete();
        }
        await registration.dispose();
      }
    }
    typeRegistrations.clear();
  }

  List<_ObjectRegistration> get allRegistrations =>
      typeRegistrations.values.fold<List<_ObjectRegistration>>(
        [],
        (sum, x) =>
            sum..addAll([...x.registrations, ...x.namedRegistrations.values]),
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

    final registrations = [
      ...typeRegistration.registrations,
      ...typeRegistration.namedRegistrations.values,
    ];
    final instances = <T>[];
    for (final registration in registrations) {
      final T instance;
      if (registration.isAsync || registration.pendingResult != null) {
        /// We use an assert here instead of an `if..throw` for performance reasons
        assert(
          registration.registrationType == ObjectRegistrationType.constant ||
              registration.registrationType == ObjectRegistrationType.lazy,
          "You can't use getAll with an async Factory of $T.",
        );
        throwIfNot(
          registration.isReady,
          StateError(
            'You tried to access an instance of $T that is not ready yet',
          ),
        );
        instance = registration.instance!;
      } else {
        instance = registration.getObject(param1, param2);
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

    final registrations = [
      ...typeRegistration.registrations,
      ...typeRegistration.namedRegistrations.values,
    ];
    final instances = <T>[];
    for (final registration in registrations) {
      final T instance;
      if (registration.isAsync || registration.pendingResult != null) {
        instance = await registration.getObjectAsync(param1, param2);
      } else {
        instance = registration.getObject(param1, param2);
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

  /// Global registration number counter for tracking registration order
  int _registrationNumber = 0;

  /// Helper method to safely get instance details via toString()
  static String? _getInstanceDetails(Object instance) {
    try {
      return instance.toString();
    } catch (e) {
      return 'Error calling toString(): $e';
    }
  }

  _GetItImplementation() {
    assert(() {
      if (!_devToolsExtensionRegistered) {
        _devToolsExtensionRegistered = true;
        registerExtension('ext.get_it.getRegistrations',
            (method, parameters) async {
          final registrations = <Map<String, dynamic>>[];
          for (final scope in _scopes) {
            for (final typeRegistration in scope.typeRegistrations.values) {
              for (final registration in [
                ...typeRegistration.registrations,
                ...typeRegistration.namedRegistrations.values
              ]) {
                registrations.add({
                  'type': registration.registeredWithType.toString(),
                  'instanceName': registration.instanceName,
                  'scopeName': scope.name,
                  'registrationType': registration.registrationType.toString(),
                  'isAsync': registration.isAsync,
                  'isReady': registration.isReady,
                  'isCreated': registration.instance != null,
                  'instanceDetails': registration.instance != null
                      ? _getInstanceDetails(registration.instance!)
                      : null,
                });
              }
            }
          }
          return ServiceExtensionResponse.result(
              jsonEncode({'registrations': registrations}));
        });
      }
      return true;
    }());
  }

  @override
  bool debugEventsEnabled = false;

  void _fireDevToolEvent(String kind, Map<String, dynamic> parameters) {
    assert(() {
      if (debugEventsEnabled) {
        postEvent('get_it.$kind', parameters);
      }
      return true;
    }());
  }

  @override
  void Function(bool pushed)? onScopeChanged;

  /// We still support a global ready signal mechanism for that we use this
  /// Completer.
  final _globalReadyCompleter = Completer();

  /// Cached allReady future - invalidated when new async singletons are registered
  Future<void>? _cachedAllReadyFuture;

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

  /// Is used by several other functions to retrieve the correct [_ObjectRegistration]
  _ObjectRegistration<T, dynamic, dynamic>?
      _findFirstRegistrationByNameAndTypeOrNull<T extends Object>(
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

    _ObjectRegistration<T, dynamic, dynamic>? instanceRegistration;

    int scopeLevel = _scopes.length - (lookInScopeBelow ? 2 : 1);

    final lookUpType = type ?? T;
    while (instanceRegistration == null && scopeLevel >= 0) {
      final _TypeRegistration? typeRegistration =
          _scopes[scopeLevel].typeRegistrations[lookUpType];

      final foundRegistration = typeRegistration?.getRegistration(instanceName);
      assert(
        foundRegistration is _ObjectRegistration<T, dynamic, dynamic>?,
        'It looks like you have passed your lookup type via the `type` but '
        'but the receiving variable is not a compatible type.',
      );

      instanceRegistration =
          foundRegistration as _ObjectRegistration<T, dynamic, dynamic>?;
      scopeLevel--;
    }

    return instanceRegistration;
  }

  /// Is used by several other functions to retrieve the correct [_ObjectRegistration]
  _ObjectRegistration _findRegistrationByNameAndType<T extends Object>(
    String? instanceName, [
    Type? type,
  ]) {
    final instanceRegistration = _findFirstRegistrationByNameAndTypeOrNull<T>(
      instanceName,
      type: type,
    );

    throwIfNot(
      instanceRegistration != null,
      // ignore: missing_whitespace_between_adjacent_strings
      StateError(
        'GetIt: Object/factory with ${instanceName != null ? 'with name $instanceName and ' : ''}'
        'type $T is not registered inside GetIt. '
        '\n(Did you accidentally do GetIt sl=GetIt.instance(); instead of GetIt sl=GetIt.instance;'
        '\nDid you forget to register it?)',
      ),
    );

    return instanceRegistration!;
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
    final _ObjectRegistration<Object, dynamic, dynamic>? objectRegistration;
    if (throwIfNotFound) {
      objectRegistration =
          _findRegistrationByNameAndType<T>(instanceName, type);
    } else {
      objectRegistration = _findFirstRegistrationByNameAndTypeOrNull<T>(
          instanceName,
          type: type);
      if (objectRegistration == null) {
        return null;
      }
    }

    final Object instance;
    if (objectRegistration.isAsync ||
        objectRegistration.pendingResult != null) {
      /// We use an assert here instead of an `if..throw` for performance reasons
      assert(
        objectRegistration.registrationType ==
                ObjectRegistrationType.constant ||
            objectRegistration.registrationType == ObjectRegistrationType.lazy,
        "You can't use get with an async Factory of ${instanceName ?? T.toString()}.",
      );
      throwIfNot(
        objectRegistration.isReady,
        StateError(
          'You tried to access an instance of ${instanceName ?? T.toString()} that is not ready yet',
        ),
      );
      instance = objectRegistration.instance!;
    } else {
      instance = objectRegistration.getObject(param1, param2);
    }

    assert(
      instance is T,
      'Object with name $instanceName has a different type '
      '(${objectRegistration.registeredWithType}) than the one that is inferred '
      '($T) where you call it',
    );

    return instance as T;
  }

  @override
  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
    String? onlyInScope,
  }) {
    final Iterable<T> instances;

    if (onlyInScope != null) {
      // Search specific named scope
      final scope = _scopes.firstWhereOrNull((s) => s.name == onlyInScope);
      throwIf(
        scope == null,
        StateError('Scope with name "$onlyInScope" does not exist'),
      );
      instances = scope!.getAll<T>(param1: param1, param2: param2);
    } else if (fromAllScopes) {
      instances = [
        for (final scope in _scopes)
          ...scope.getAll<T>(param1: param1, param2: param2),
      ];
    } else {
      instances = _currentScope.getAll<T>(param1: param1, param2: param2);
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
    final objectRegistrationToGet =
        _findRegistrationByNameAndType<T>(instanceName, type);
    return objectRegistrationToGet.getObjectAsync<T>(param1, param2);
  }

  @override
  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
    String? onlyInScope,
  }) async {
    final Iterable<T> instances;

    if (onlyInScope != null) {
      // Search specific named scope
      final scope = _scopes.firstWhereOrNull((s) => s.name == onlyInScope);
      throwIf(
        scope == null,
        StateError('Scope with name "$onlyInScope" does not exist'),
      );
      instances = await scope!.getAllAsync<T>(param1: param1, param2: param2);
    } else if (fromAllScopes) {
      instances = [
        for (final scope in _scopes)
          ...await scope.getAllAsync<T>(param1: param1, param2: param2),
      ];
    } else {
      instances = await _currentScope.getAllAsync<T>(
        param1: param1,
        param2: param2,
      );
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

  @override
  List<T> findAll<T extends Object>({
    bool includeSubtypes = true,
    bool inAllScopes = false,
    String? onlyInScope,
    bool includeMatchedByRegistrationType = true,
    bool includeMatchedByInstance = true,
    bool instantiateLazySingletons = false,
    bool callFactories = false,
  }) {
    // Validations
    throwIf(
      !includeSubtypes && includeMatchedByInstance,
      ArgumentError(
        'includeSubtypes=false (exact type matching) is only possible with '
        'registration type matching. Runtime instance type checking (is operator) '
        'cannot distinguish exact types from subtypes. '
        'Either set includeSubtypes=true or includeMatchedByInstance=false.',
      ),
    );

    throwIf(
      instantiateLazySingletons && !includeMatchedByRegistrationType,
      ArgumentError(
        'instantiateLazySingletons=true requires includeMatchedByRegistrationType=true. '
        'Cannot determine which lazy singletons to instantiate without checking registration types.',
      ),
    );

    throwIf(
      callFactories && !includeMatchedByRegistrationType,
      ArgumentError(
        'callFactories=true requires includeMatchedByRegistrationType=true. '
        'Cannot determine which factories to call without checking registration types.',
      ),
    );

    // Determine which registrations to search
    final Iterable<_ObjectRegistration> registrationsToSearch;

    if (onlyInScope != null) {
      // Search specific named scope
      final scope = _scopes.firstWhereOrNull((s) => s.name == onlyInScope);
      throwIf(
        scope == null,
        StateError('Scope with name "$onlyInScope" does not exist'),
      );
      registrationsToSearch = scope!.allRegistrations;
    } else if (inAllScopes) {
      // Search all scopes
      registrationsToSearch = _allRegistrations;
    } else {
      // Search current scope only (default)
      registrationsToSearch = _currentScope.allRegistrations;
    }

    // Find matching instances
    final List<T> instances = <T>[];

    for (final registration in registrationsToSearch) {
      Object? instanceToAdd;

      // Check registration type match
      if (includeMatchedByRegistrationType) {
        final bool registrationTypeMatches = includeSubtypes
            ? registration.isSubtypeOf<T>()
            : registration.isExactType<T>();

        if (registrationTypeMatches) {
          // Handle based on registration type
          if (registration.registrationType ==
              ObjectRegistrationType.alwaysNew) {
            // Factory
            if (callFactories) {
              instanceToAdd = registration.getObject(null, null);
            }
          } else if (registration.instance != null) {
            // Already instantiated singleton
            instanceToAdd = registration.instance;
          } else if (instantiateLazySingletons &&
              registration.registrationType == ObjectRegistrationType.lazy) {
            // Uninstantiated lazy singleton - instantiate it
            instanceToAdd = registration.getObject(null, null);
          }
        }
      }

      // Check instance type match (if we haven't found a match yet)
      if (includeMatchedByInstance && instanceToAdd == null) {
        if (registration.instance != null) {
          final instance = registration.instance!;
          if (instance is T) {
            instanceToAdd = instance;
          }
        }
      }

      if (instanceToAdd != null) {
        instances.add(instanceToAdd as T);
      }
    }

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
      type: ObjectRegistrationType.alwaysNew,
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
      type: ObjectRegistrationType.cachedFactory,
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
      type: ObjectRegistrationType.cachedFactory,
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
      type: ObjectRegistrationType.cachedFactory,
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
      type: ObjectRegistrationType.cachedFactory,
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
      type: ObjectRegistrationType.alwaysNew,
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
      type: ObjectRegistrationType.alwaysNew,
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
      type: ObjectRegistrationType.alwaysNew,
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
    void Function(T instance)? onCreated,
    bool useWeakReference = false,
  }) {
    _register<T, void, void>(
      type: ObjectRegistrationType.lazy,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
      disposeFunc: dispose,
      onCreatedFunc: onCreated,
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
      type: ObjectRegistrationType.constant,
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
    final existingRegistration = _findFirstRegistrationByNameAndTypeOrNull<T>(
      instanceName,
    );
    if (existingRegistration != null) {
      throwIfNot(
        existingRegistration.registrationType ==
                ObjectRegistrationType.constant &&
            !existingRegistration.isAsync,
        StateError(
          'registerSingletonIfAbsent can only be called for a type that is already registered as Singleton and not for factories or async/lazy Singletons',
        ),
      );
      existingRegistration._referenceCount++;
      return existingRegistration.instance!;
    }

    final instance = factoryFunc();
    _register<T, void, void>(
      type: ObjectRegistrationType.constant,
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
    final objectRegistration = _findRegistrationByInstance(instance);
    if (objectRegistration._referenceCount < 1) {
      assert(
        objectRegistration._referenceCount == 0,
        'GetIt: releaseInstance was called on an object that was already released',
      );
      unregister(instance: instance);
    } else {
      objectRegistration._referenceCount--;
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
      type: ObjectRegistrationType.constant,
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
    void Function(T instance)? onCreated,
  }) {
    _register<T, void, void>(
      type: ObjectRegistrationType.constant,
      instanceName: instanceName,
      isAsync: true,
      factoryFuncAsync: factoryFunc,
      dependsOn: dependsOn,
      shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
      disposeFunc: dispose,
      onCreatedFunc: onCreated,
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
    void Function(T instance)? onCreated,
    bool useWeakReference = false,
  }) {
    _register<T, void, void>(
      isAsync: true,
      type: ObjectRegistrationType.lazy,
      instanceName: instanceName,
      factoryFuncAsync: factoryFunc,
      shouldSignalReady: false,
      disposeFunc: dispose,
      onCreatedFunc: onCreated,
      useWeakReference: useWeakReference,
    );
  }

  @override
  ObjectRegistration? findFirstObjectRegistration<T extends Object>(
      {Object? instance, String? instanceName}) {
    if (instance != null) {
      return _findFirstRegistrationByInstanceOrNull(instance);
    } else {
      return _findFirstRegistrationByNameAndTypeOrNull<T>(instanceName);
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
      return _findFirstRegistrationByInstanceOrNull(instance) != null;
    } else {
      return _findFirstRegistrationByNameAndTypeOrNull<T>(
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
    final registrationToRemove = instance != null
        ? _findRegistrationByInstance(instance)
        : _findRegistrationByNameAndType<T>(instanceName);

    throwIf(
      registrationToRemove.objectsWaiting.isNotEmpty,
      StateError(
        'There are still other objects waiting for this instance so signal ready',
      ),
    );

    if (registrationToRemove._referenceCount > 0 && !ignoreReferenceCount) {
      registrationToRemove._referenceCount--;
      return;
    }

    // Complete pending completer so allReady() can complete
    if (!registrationToRemove.isReady) {
      registrationToRemove._readyCompleter.complete();
    }

    final typeRegistration = registrationToRemove.registeredIn;

    if (registrationToRemove.isNamedRegistration) {
      typeRegistration.namedRegistrations
          .remove(registrationToRemove.instanceName);
    } else {
      typeRegistration.registrations.remove(registrationToRemove);
    }
    if (typeRegistration.isEmpty) {
      registrationToRemove.registrationScope.typeRegistrations.remove(T);
    }

    if (registrationToRemove.instance != null) {
      if (disposingFunction != null) {
        final dispose =
            disposingFunction.call(registrationToRemove.instance! as T);
        if (dispose is Future) {
          await dispose;
        }
      } else {
        final dispose = registrationToRemove.dispose();
        if (dispose is Future) {
          await dispose;
        }
      }
    }
    assert(() {
      _fireDevToolEvent('unregister', {
        'type': T.toString(),
        'instanceName': instanceName,
      });
      return true;
    }());
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

    final registrationToRename = instance != null
        ? _findRegistrationByInstance(instance)
        : _findRegistrationByNameAndType<T>(instanceName);

    if (instance != null) {
      instanceName = registrationToRename.instanceName;
    }

    throwIfNot(
      registrationToRename.isNamedRegistration,
      StateError('This instance $instance is not registered with a name'),
    );

    final typeRegistration = registrationToRename.registeredIn;
    throwIf(
      typeRegistration.namedRegistrations.containsKey(newInstanceName),
      StateError(
        'There is already an instance of type ${registrationToRename.registeredWithType} registered with the name $newInstanceName',
      ),
    );

    typeRegistration.namedRegistrations[newInstanceName] = registrationToRename;
    typeRegistration.namedRegistrations.remove(instanceName);
    registrationToRename.instanceName = newInstanceName;
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
    _ObjectRegistration instanceRegistration;

    if (instance != null) {
      instanceRegistration = _findRegistrationByInstance(instance);
    } else {
      instanceRegistration = _findRegistrationByNameAndType<T>(instanceName);
    }
    throwIfNot(
      instanceRegistration.registrationType == ObjectRegistrationType.lazy,
      StateError(
        'There is no type ${instance.runtimeType} registered as LazySingleton in GetIt',
      ),
    );

    dynamic disposeReturn;
    if (instanceRegistration.instance != null) {
      if (disposingFunction != null) {
        disposeReturn =
            disposingFunction.call(instanceRegistration.instance! as T);
      } else {
        disposeReturn = instanceRegistration.dispose();
      }
    }

    instanceRegistration.resetInstance();
    instanceRegistration.pendingResult = null;
    instanceRegistration._readyCompleter = Completer();
    if (disposeReturn is Future) {
      await disposeReturn;
    }
  }

  @override
  Future<void> resetLazySingletons({
    bool dispose = true,
    bool inAllScopes = false,
    String? onlyInScope,
  }) async {
    // Determine which registrations to search
    final Iterable<_ObjectRegistration> registrationsToSearch;

    if (onlyInScope != null) {
      final scope = _scopes.firstWhereOrNull((s) => s.name == onlyInScope);
      throwIf(
        scope == null,
        StateError('Scope with name "$onlyInScope" does not exist'),
      );
      registrationsToSearch = scope!.allRegistrations;
    } else if (inAllScopes) {
      registrationsToSearch = _allRegistrations;
    } else {
      registrationsToSearch = _currentScope.allRegistrations;
    }

    // Filter for lazy singletons that have been instantiated
    final lazySingletons = registrationsToSearch.where(
      (reg) =>
          reg.registrationType == ObjectRegistrationType.lazy &&
          reg.instance != null,
    );

    // Reset each lazy singleton
    for (final registration in lazySingletons) {
      dynamic disposeReturn;

      if (dispose) {
        disposeReturn = registration.dispose();
      }

      registration.resetInstance();
      registration.pendingResult = null;
      registration._readyCompleter = Completer();

      if (disposeReturn is Future) {
        await disposeReturn;
      }
    }
  }

  @override
  bool checkLazySingletonInstanceExists<T extends Object>({
    String? instanceName,
  }) {
    final registrationWithInstance =
        _findRegistrationByNameAndType<T>(instanceName);
    throwIfNot(
      registrationWithInstance.registrationType == ObjectRegistrationType.lazy,
      StateError(
        'There is no type $T  with name $instanceName registered as LazySingleton in GetIt',
      ),
    );

    return registrationWithInstance.instance != null;
  }

  List<_ObjectRegistration> get _allRegistrations =>
      _scopes.fold<List<_ObjectRegistration>>(
          [], (sum, x) => sum..addAll(x.allRegistrations));

  _ObjectRegistration? _findFirstRegistrationByInstanceOrNull(Object instance) {
    return _allRegistrations.firstWhereOrNull(
      (x) => identical(x.instance, instance),
    );
  }

  _ObjectRegistration _findRegistrationByInstance(Object instance) {
    final registrationWithInstance =
        _findFirstRegistrationByInstanceOrNull(instance);

    throwIf(
      registrationWithInstance == null,
      StateError(
        'This instance of the type ${instance.runtimeType} is not available in GetIt '
        'If you have registered it as LazySingleton, are you sure you have used '
        'it at least once?',
      ),
    );

    return registrationWithInstance!;
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
    _cachedAllReadyFuture = null;
    assert(() {
      _fireDevToolEvent('reset', {'dispose': dispose});
      return true;
    }());
  }

  /// Clears all registered types of the current scope in the reverse order in which they were registered.
  @override
  Future<void> resetScope({bool dispose = true}) async {
    if (dispose) {
      await _currentScope.dispose();
    }
    await _currentScope.reset(dispose: dispose);
    assert(() {
      _fireDevToolEvent(
          'resetScope', {'dispose': dispose, 'scopeName': _currentScope.name});
      return true;
    }());
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
      assert(() {
        _fireDevToolEvent(
            'scope_change', {'pushed': true, 'scopeName': scopeName});
        return true;
      }());
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
      assert(() {
        _fireDevToolEvent(
            'scope_change', {'pushed': true, 'scopeName': scopeName});
        return true;
      }());
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
    assert(() {
      _fireDevToolEvent(
          'scope_change', {'pushed': false, 'scopeName': scopeToPop.name});
      return true;
    }());
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
    required ObjectRegistrationType type,
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
    void Function(T)? onCreatedFunc,
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
          existingTypeRegistration.namedRegistrations
                  .containsKey(instanceName) &&
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
            existingTypeRegistration.namedRegistrations
                .containsKey(instanceName)) {
          return;
        }
      } else {
        if (existingTypeRegistration.registrations.isNotEmpty) {
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
      final registrationThatWouldbeShadowed =
          _findFirstRegistrationByNameAndTypeOrNull(
        instanceName,
        type: T,
      );

      final objectThatWouldbeShadowed =
          registrationThatWouldbeShadowed?.instance;
      if (objectThatWouldbeShadowed != null &&
          objectThatWouldbeShadowed is ShadowChangeHandlers) {
        objectThatWouldbeShadowed.onGetShadowed(instance);
      }
    }

    final typeRegistration = registrationScope.typeRegistrations.putIfAbsent(
      T,
      () => _TypeRegistration<T>(),
    );

    final objectRegistration = _ObjectRegistration<T, P1, P2>(
      this,
      type,
      registrationNumber: _registrationNumber++,
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
      onCreatedCallback: onCreatedFunc,
      useWeakReference: useWeakReference,
    );

    if (instanceName != null) {
      typeRegistration.namedRegistrations[instanceName] = objectRegistration;
    } else {
      if (allowRegisterMultipleImplementationsOfoneType) {
        typeRegistration.registrations.add(objectRegistration);
      } else {
        if (typeRegistration.registrations.isNotEmpty) {
          typeRegistration.registrations[0] = objectRegistration;
        } else {
          typeRegistration.registrations.add(objectRegistration);
        }
      }
    }

    // simple Singletons get are already created, nothing else has to be done
    if (type == ObjectRegistrationType.constant &&
        !shouldSignalReady &&
        !isAsync &&
        (dependsOn?.isEmpty ?? true)) {
      return;
    }

    // if it's an async or a dependent Singleton we start its creation function here after we check if
    // it is dependent on other registered Singletons.
    if ((isAsync || (dependsOn?.isNotEmpty ?? false)) &&
        type == ObjectRegistrationType.constant) {
      // Invalidate allReady cache since a new async singleton affects allReady()
      _cachedAllReadyFuture = null;

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
          late final _ObjectRegistration<Object, dynamic, dynamic>?
              dependentRegistration;
          if (dependency is InitDependency) {
            dependentRegistration = _findFirstRegistrationByNameAndTypeOrNull(
              dependency.instanceName,
              type: dependency.type,
            );
          } else {
            dependentRegistration = _findFirstRegistrationByNameAndTypeOrNull(
              null,
              type: dependency,
            );
          }
          throwIf(
            dependentRegistration == null,
            ArgumentError(
              'Dependent Type $dependency is not registered in GetIt',
            ),
          );
          throwIfNot(
            dependentRegistration!.canBeWaitedFor,
            ArgumentError(
              'Dependent Type $dependency is not an async Singleton',
            ),
          );
          dependentRegistration.objectsWaiting
              .add(objectRegistration.registeredWithType);
          dependentFutureGroup
              .add(dependentRegistration._readyCompleter.future);
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
          objectRegistration._instance = factoryFunc!();

          /// check if we are shadowing an existing Object
          final registrationThatWouldbeShadowed =
              _findFirstRegistrationByNameAndTypeOrNull(
            instanceName,
            type: T,
            lookInScopeBelow: true,
          );

          final objectThatWouldbeShadowed =
              registrationThatWouldbeShadowed?.instance;
          if (objectThatWouldbeShadowed != null &&
              objectThatWouldbeShadowed is ShadowChangeHandlers) {
            objectThatWouldbeShadowed
                .onGetShadowed(objectRegistration.instance!);
          }

          // Call onCreated callback if provided
          objectRegistration.onCreatedCallback
              ?.call(objectRegistration.instance!);

          if (!objectRegistration.shouldSignalReady) {
            /// As this isn't an async function we declare it as ready here
            /// if wasn't marked that it will signalReady
            isReadyFuture = Future<T>.value(objectRegistration.instance!);
            objectRegistration._readyCompleter
                .complete(objectRegistration.instance!);
            objectRegistration.objectsWaiting.clear();
          } else {
            isReadyFuture = objectRegistration._readyCompleter.future;
          }
        } else {
          /// Async Singleton with dependencies
          final asyncResult = factoryFuncAsync!();

          isReadyFuture = asyncResult.then((instance) {
            objectRegistration._instance = instance;

            /// check if we are shadowing an existing Object
            final registrationThatWouldbeShadowed =
                _findFirstRegistrationByNameAndTypeOrNull(
              instanceName,
              type: T,
              lookInScopeBelow: true,
            );

            final objectThatWouldbeShadowed =
                registrationThatWouldbeShadowed?.instance;
            if (objectThatWouldbeShadowed != null &&
                objectThatWouldbeShadowed is ShadowChangeHandlers) {
              objectThatWouldbeShadowed.onGetShadowed(instance);
            }

            // Call onCreated callback if provided
            objectRegistration.onCreatedCallback?.call(instance);

            if (!objectRegistration.shouldSignalReady &&
                !objectRegistration.isReady) {
              objectRegistration._readyCompleter.complete();
              objectRegistration.objectsWaiting.clear();
            }

            return instance;
          });
        }
        outerFutureGroup.add(isReadyFuture);
        outerFutureGroup.close();
      });

      objectRegistration.pendingResult = outerFutureGroup.future.then((
        completedFutures,
      ) {
        return objectRegistration.instance!;
      });
    }
    assert(() {
      _fireDevToolEvent('register', {
        'type': T.toString(),
        'instanceName': instanceName,
        'scopeName': registrationScope.name,
        'registrationType': type.toString(),
        'isAsync': isAsync,
        'isReady': objectRegistration.isReady,
        'isCreated': objectRegistration.instance != null,
      });
      return true;
    }());
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
    _ObjectRegistration registeredInstance;
    if (instance != null) {
      registeredInstance = _findRegistrationByInstance(instance);

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
      final notReady = _allRegistrations
          .where(
            (x) =>
                (x.shouldSignalReady) && (!x.isReady) ||
                (x.pendingResult != null) && (!x.isReady),
          )
          .map<String>((x) => '${x.registeredWithType}/${x.instanceName}')
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
    // Return cached future if available
    if (_cachedAllReadyFuture != null) {
      if (timeout != null) {
        return _cachedAllReadyFuture!.timeout(
          timeout,
          onTimeout: () => throw _createTimeoutError(),
        );
      }
      return _cachedAllReadyFuture!;
    }

    final futures = FutureGroup();
    _allRegistrations
        .where(
      (x) =>
          (x.isAsync && !ignorePendingAsyncCreation ||
              (!x.isAsync &&
                  x.pendingResult != null) || // Singletons with dependencies
              x.shouldSignalReady) &&
          !x.isReady &&
          x.registrationType == ObjectRegistrationType.constant,
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

    _cachedAllReadyFuture = futures.future;

    if (timeout != null) {
      return _cachedAllReadyFuture!.timeout(
        timeout,
        onTimeout: () => throw _createTimeoutError(),
      );
    }
    return _cachedAllReadyFuture!;
  }

  /// Returns if all async Singletons are ready without waiting
  /// if [allReady] should not wait for the completion of async Singletons set
  /// [ignorePendingAsyncCreation==true]
  @override
  bool allReadySync([bool ignorePendingAsyncCreation = false]) {
    final notReadyTypes = _allRegistrations
        .where(
      (x) =>
          (x.isAsync && !ignorePendingAsyncCreation ||
                  (!x.isAsync &&
                      x.pendingResult !=
                          null) || // Singletons with dependencies
                  x.shouldSignalReady) &&
              !x.isReady &&
              x.registrationType == ObjectRegistrationType.constant ||
          x.registrationType == ObjectRegistrationType.lazy,
    )
        .map<String>((x) {
      if (x.isNamedRegistration) {
        return 'Object ${x.instanceName} has not completed';
      } else {
        return 'Registered object of Type ${x.registeredWithType} has not completed';
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
    final allRegistrations = _allRegistrations;
    final waitedBy = Map.fromEntries(
      allRegistrations
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
    final notReady = allRegistrations
        .where(
          (x) => (x.shouldSignalReady || x.pendingResult != null) && !x.isReady,
        )
        .map((f) => f.debugName)
        .toList();
    final areReady = allRegistrations
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
    _ObjectRegistration registrationToCheck;
    if (instance != null) {
      registrationToCheck = _findRegistrationByInstance(instance);
    } else {
      registrationToCheck = _findRegistrationByNameAndType<T>(instanceName);
    }
    if (!registrationToCheck.isReady) {
      registrationToCheck.objectsWaiting.add(callee.runtimeType);
    }
    if (registrationToCheck.isAsync &&
        registrationToCheck.registrationType == ObjectRegistrationType.lazy &&
        registrationToCheck.instance == null) {
      if (timeout != null) {
        return registrationToCheck.getObjectAsync(null, null).timeout(
          timeout,
          onTimeout: () {
            throw _createTimeoutError();
          },
        );
      } else {
        return registrationToCheck.getObjectAsync(null, null);
      }
    }
    if (registrationToCheck.pendingResult != null) {
      if (timeout != null) {
        return registrationToCheck.pendingResult!.timeout(
          timeout,
          onTimeout: () {
            throw _createTimeoutError();
          },
        );
      } else {
        return registrationToCheck.pendingResult!;
      }
    }
    if (timeout != null) {
      return registrationToCheck._readyCompleter.future.timeout(
        timeout,
        onTimeout: () => throw _createTimeoutError(),
      );
    } else {
      return registrationToCheck._readyCompleter.future;
    }
  }

  /// Checks if an async Singleton defined by an [instance], a type [T] or an [instanceName]
  /// is ready without waiting.
  @override
  bool isReadySync<T extends Object>({Object? instance, String? instanceName}) {
    _ObjectRegistration registrationToCheck;
    if (instance != null) {
      registrationToCheck = _findRegistrationByInstance(instance);
    } else {
      registrationToCheck = _findRegistrationByNameAndType<T>(instanceName);
    }
    throwIfNot(
      registrationToCheck.canBeWaitedFor &&
          registrationToCheck.registrationType !=
              ObjectRegistrationType.alwaysNew,
      ArgumentError(
        'You only can use this function on async Singletons or Singletons '
        'that have ben marked with "signalsReady" or that they depend on others',
      ),
    );
    return registrationToCheck.isReady;
  }
}
