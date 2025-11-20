import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import 'src/model.dart';

void main() {
  runApp(const GetItDevToolsExtension());
}

class GetItDevToolsExtension extends StatelessWidget {
  const GetItDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: GetItDevToolsScreen());
  }
}

class GetItDevToolsScreen extends StatefulWidget {
  const GetItDevToolsScreen({super.key});

  @override
  State<GetItDevToolsScreen> createState() => _GetItDevToolsScreenState();
}

class _GetItDevToolsScreenState extends State<GetItDevToolsScreen> {
  List<RegistrationInfo> _registrations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _fetchRegistrations();

      // Listen for events
      serviceManager.service?.onExtensionEvent.listen((Event event) {
        if (event.extensionKind?.startsWith('get_it') ?? false) {
          _fetchRegistrations();
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRegistrations() async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.get_it.getRegistrations',
      );
      final List<dynamic> data = response.json?['registrations'] ?? [];
      final registrations = data
          .map((e) => RegistrationInfo.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _registrations = registrations;
        _isLoading = false;
      });
    } catch (e) {
      // If the extension is not registered yet (app starting up), we might get an error.
      // We can retry or just show empty state.
      setState(() {
        _error =
            'Could not fetch registrations. Make sure debugEventsEnabled is true in GetIt.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRegistrations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        AreaPaneHeader(
          title: const Text('GetIt Registrations'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _fetchRegistrations,
            ),
          ],
        ),
        Expanded(child: _buildTable()),
      ],
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Instance Name')),
            DataColumn(label: Text('Scope')),
            DataColumn(label: Text('Mode')),
            DataColumn(label: Text('Async')),
            DataColumn(label: Text('Ready')),
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('Instance Details')),
          ],
          rows: _registrations.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.type)),
                DataCell(Text(item.instanceName ?? '')),
                DataCell(Text(item.scopeName)),
                DataCell(Text(item.registrationType)),
                DataCell(Text(item.isAsync.toString())),
                DataCell(Text(item.isReady.toString())),
                DataCell(Text(item.isCreated.toString())),
                DataCell(
                  item.instanceDetails != null
                      ? Tooltip(
                          message: item.instanceDetails!,
                          child: Text(
                            _truncateText(item.instanceDetails!, 50),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : const Text(''),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}
