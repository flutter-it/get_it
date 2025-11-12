import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:get_it/get_it.dart';
import 'package:get_it_example/app_model.dart';
import 'package:get_it_example/preview_wrapper.dart';

// This is our global ServiceLocator
GetIt getIt = GetIt.instance;

void setupLocator() {
  // Here you can register other dependencies if needed
  /// I use signalReady here only to show how to use it. In 99% of the cases
  /// you don't need it. Just use registerSingletonAsync
  getIt.registerSingleton<AppModel>(
    AppModelImplementation(),
    signalsReady: true,
  );
}

void main() {
  setupLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    // Access the instance of the registered AppModel
    // As we don't know for sure if AppModel is already ready we use isReady
    getIt.isReady<AppModel>().then(
          (_) => getIt<AppModel>().addListener(update),
        );
    // Alternative
    // getIt.getAsync<AppModel>().addListener(update);

    super.initState();
  }

  @override
  void dispose() {
    getIt<AppModel>().removeListener(update);
    super.dispose();
  }

  void update() => setState(() => {});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: FutureBuilder(
        future: getIt.allReady(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text('You have pushed the button this many times:'),
                    Text(
                      getIt<AppModel>().counter.toString(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: getIt<AppModel>().incrementCounter,
                tooltip: 'Increment',
                child: const Icon(Icons.add),
              ),
            );
          } else {
            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Waiting for initialisation'),
                SizedBox(height: 16),
                CircularProgressIndicator(),
              ],
            );
          }
        },
      ),
    );
  }
}

// ==============================================================================
// Flutter Widget Preview Examples
// ==============================================================================
//
// Flutter's widget previewer renders widgets in isolation, without running
// main() or your normal app initialization. This means `get_it` won't be
// initialized automatically. Below are two approaches to handle this:

// ------------------------------------------------------------------------------
// Approach 1: Direct Registration with isRegistered() Check
// ------------------------------------------------------------------------------
//
// Use this for simple, one-off previews where you want maximum control.
// The previewer may call this function multiple times, so we check if
// the service is already registered before registering it again.

@Preview()
Widget preview() {
  // Guard against double registration since preview functions
  // can be called multiple times during hot reload
  if (!getIt.isRegistered<AppModel>()) {
    getIt.registerSingleton<AppModel>(
      AppModelImplementation(),
      signalsReady: true,
    );
  }
  return const MyApp();
}

// ------------------------------------------------------------------------------
// Approach 2: Wrapper Widget with Automatic Cleanup
// ------------------------------------------------------------------------------
//
// Use this when you want automatic cleanup or need to reuse the same setup
// across multiple previews. The wrapper handles initialization in initState
// and cleanup via reset() in dispose.
//
// Uncomment the @Preview annotation to enable this preview:

// @Preview(name: 'With GetIt Wrapper', wrapper: wrapper)
Widget previewWithWrapper() => const MyApp();

// Wrapper function (must be top-level or static for @Preview)
Widget wrapper(Widget child) {
  return GetItPreviewWrapper(
    init: (getIt) {
      // Register all preview dependencies here
      getIt.registerSingleton<AppModel>(
        AppModelImplementation(),
        signalsReady: true,
      );
    },
    child: child,
  );
}

// Note: GetItPreviewWrapper is defined in preview_wrapper.dart
// See that file for full documentation on how it works.
