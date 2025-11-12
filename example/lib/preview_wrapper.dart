import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// A wrapper widget for Flutter widget previews that initializes `get_it`.
///
/// Flutter's widget previewer renders widgets in isolation, separate from your
/// app's normal initialization flow. This means `get_it` won't be initialized
/// automatically. This wrapper handles `get_it` setup and cleanup for previews.
///
/// ## How to Use
///
/// ```dart
/// Widget myWrapper(Widget child) {
///   return GetItPreviewWrapper(
///     init: (getIt) {
///       // Register your preview dependencies
///       getIt.registerLazySingleton<ApiService>(() => MockApiService());
///       getIt.registerLazySingleton<UserRepo>(() => MockUserRepo());
///     },
///     child: child,
///   );
/// }
///
/// @Preview(name: 'My Widget', wrapper: myWrapper)
/// Widget myWidgetPreview() => const MyWidget();
/// ```
///
/// ## When to Use This vs Direct Registration
///
/// **Use this wrapper when:**
/// - You want automatic cleanup (calls `reset()` on dispose)
/// - You have complex setup logic
/// - You want to reuse the same setup across multiple previews
///
/// **Use direct registration when:**
/// - You have simple, one-off previews
/// - You want maximum control over initialization
///
/// Example of direct registration:
/// ```dart
/// @Preview()
/// Widget preview() {
///   if (!getIt.isRegistered<MyService>()) {
///     getIt.registerSingleton<MyService>(MockService());
///   }
///   return const MyWidget();
/// }
/// ```
///
/// ## How It Works
///
/// 1. **initState**: Calls your `init` function to register dependencies
/// 2. **build**: Returns your child widget with GetIt ready to use
/// 3. **dispose**: Calls `getIt.reset()` to clean up all registrations
///
/// The preview environment may call your preview function multiple times,
/// so the wrapper ensures proper cleanup between renders.
class GetItPreviewWrapper extends StatefulWidget {
  const GetItPreviewWrapper({
    super.key,
    required this.init,
    required this.child,
  });

  /// The child widget to render after `get_it` is initialized
  final Widget child;

  /// Initialization function that registers dependencies in `get_it`
  ///
  /// This is called once in `initState` before the widget is built.
  /// Register all your preview dependencies here.
  ///
  /// Example:
  /// ```dart
  /// init: (getIt) {
  ///   getIt.registerLazySingleton<ApiService>(() => MockApiService());
  ///   getIt.registerSingleton<Config>(TestConfig());
  /// }
  /// ```
  final void Function(GetIt getIt) init;

  @override
  State<GetItPreviewWrapper> createState() => _GetItPreviewWrapperState();
}

class _GetItPreviewWrapperState extends State<GetItPreviewWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize get_it with preview dependencies
    widget.init(GetIt.instance);
  }

  @override
  void dispose() {
    // Clean up all get_it registrations when preview is disposed
    GetIt.instance.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
