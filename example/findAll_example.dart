import 'package:get_it/get_it.dart';

abstract interface class IOutput {
  void write(String message);
}

class FileOutput implements IOutput {
  @override
  void write(String message) {
    print('File: $message');
  }
  
  void clearFile() {
    print('Clearing file');
  }
}

class ConsoleOutput implements IOutput {
  @override
  void write(String message) {
    print('Console: $message');
  }
}

class RemoteLoggingOutput implements IOutput {
  @override
  void write(String message) {
    print('Remote: $message');
  }
}

class DatabaseService {
  void save(String data) {
    print('Saving to DB: $data');
  }
}

void main() {
  final getIt = GetIt.instance;
  
  // Register various services that implement IOutput interface
  getIt
    ..registerSingleton<FileOutput>(FileOutput())
    ..registerSingleton<ConsoleOutput>(ConsoleOutput())
    ..registerLazySingleton<RemoteLoggingOutput>(() => RemoteLoggingOutput())
    ..registerSingleton<DatabaseService>(DatabaseService());
  
  // Access the lazy singleton to create its instance
  getIt<RemoteLoggingOutput>();
  
  // Use getAll to get services registered AS IOutput
  print('Services registered as IOutput:');
  try {
    final explicitOutputs = getIt.getAll<IOutput>();
    print('Found ${explicitOutputs.length} services registered as IOutput');
  } catch (e) {
    print('No services registered explicitly as IOutput');
  }
  
  // Use findAll to get all services that ARE IOutput (runtime check)
  print('\nServices that implement IOutput:');
  final allOutputs = getIt.findAll<IOutput>();
  print('Found ${allOutputs.length} services that implement IOutput');
  
  for (final output in allOutputs) {
    output.write('Hello from ${output.runtimeType}!');
  }
  
  // Still access specific implementations with type safety:
  getIt<FileOutput>().clearFile();
  
  // Example of broadcasting to all outputs
  print('\nBroadcasting message to all outputs:');
  messageAll(getIt, 'This is a broadcast message!');
}

void messageAll(GetIt getIt, String message) {
  for (final output in getIt.findAll<IOutput>()) {
    output.write(message);
  }
}