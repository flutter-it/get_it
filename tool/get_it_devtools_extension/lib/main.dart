import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:get_it_devtools_extension/src/widgets/filter_dialog.dart';
import 'package:get_it_devtools_extension/src/widgets/sort_dialog.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Sorting
  SortField _sortField = SortField.defaultOrder;
  SortDirection _sortDirection = SortDirection.asc;

  // Filters
  final Set<String> _selectedRegistrationTypes = {};
  final Set<String> _selectedScopes = {};
  bool? _filterAsync;
  bool? _filterReady;
  bool? _filterCreated;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RegistrationInfo> get _filteredRegistrations {
    final filtered = [
      if (_searchQuery.isNotEmpty) _matchesSearch,
      if (_selectedScopes.isNotEmpty) _matchesScope,
      if (_selectedRegistrationTypes.isNotEmpty) _matchesRegistrationType,
      if (_filterAsync != null) _matchesAsync,
      if (_filterReady != null) _matchesReady,
      if (_filterCreated != null) _matchesCreated,
    ].fold<Iterable<RegistrationInfo>>(_registrations, (data, predicate) => data.where(predicate)).toList();

    // For defaultOrder, descending means reversing the list
    if (_sortField == SortField.defaultOrder) {
      return _sortDirection == SortDirection.desc ? filtered.reversed.toList() : filtered;
    }

    return filtered..sort(_compareBySortField);
  }

  bool _matchesSearch(RegistrationInfo item) {
    final query = _searchQuery.toLowerCase();
    return item.type.toLowerCase().contains(query) ||
        (item.instanceName?.toLowerCase().contains(query) ?? false) ||
        (item.instanceDetails?.toLowerCase().contains(query) ?? false);
  }

  bool _matchesScope(RegistrationInfo item) => _selectedScopes.contains(item.scopeName);

  bool _matchesRegistrationType(RegistrationInfo item) => _selectedRegistrationTypes.contains(item.registrationType);

  bool _matchesAsync(RegistrationInfo item) => item.isAsync == _filterAsync;

  bool _matchesReady(RegistrationInfo item) => item.isReady == _filterReady;

  bool _matchesCreated(RegistrationInfo item) => item.isCreated == _filterCreated;

  int _compareBySortField(RegistrationInfo a, RegistrationInfo b) {
    if (_sortField == SortField.defaultOrder) return 0;

    final comparison = switch (_sortField) {
      SortField.type => a.type.compareTo(b.type),
      SortField.instanceName => (a.instanceName ?? '').compareTo(b.instanceName ?? ''),
      SortField.instanceDetails => (a.instanceDetails ?? '').compareTo(b.instanceDetails ?? ''),
      SortField.defaultOrder => 0,
    };

    return _sortDirection == SortDirection.asc ? comparison : -comparison;
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
      final response = await serviceManager.callServiceExtensionOnMainIsolate('ext.get_it.getRegistrations');
      final List<dynamic> data = response.json?['registrations'] ?? [];
      final registrations = data.map((e) => RegistrationInfo.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _registrations = registrations;
        _isLoading = false;
      });
    } catch (e) {
      // If the extension is not registered yet (app starting up), we might get an error.
      // We can retry or just show empty state.
      setState(() {
        _error = 'Could not fetch registrations. Make sure debugEventsEnabled is true in GetIt.';
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
            ElevatedButton(onPressed: _fetchRegistrations, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        AreaPaneHeader(
          title: const Text('GetIt Registrations'),
          actions: [
            IconButton(icon: const Icon(Icons.filter_list), tooltip: 'Filter', onPressed: _handleFilterPressed),
            IconButton(icon: const Icon(Icons.sort), tooltip: 'Sort', onPressed: _handleSortPressed),
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _fetchRegistrations),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search registrations...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty == true
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        // Show active filter chips
        if (_selectedRegistrationTypes.isNotEmpty ||
            _selectedScopes.isNotEmpty ||
            _filterAsync != null ||
            _filterReady != null ||
            _filterCreated != null)
          _buildFilterChips(),
        Expanded(child: _buildTable()),
      ],
    );
  }

  Widget _buildTable() {
    final filtered = _filteredRegistrations;

    if (filtered.isEmpty && _searchQuery.isNotEmpty) {
      return const Center(child: Text('No results found'));
    }

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
          rows: filtered.map((item) {
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
                          child: Text(_truncateText(item.instanceDetails!, 50), overflow: TextOverflow.ellipsis),
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

  Padding _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ..._selectedScopes.map(
            (scope) => Chip(
              label: Text('Scope: $scope'),
              onDeleted: () {
                setState(() {
                  _selectedScopes.remove(scope);
                });
              },
            ),
          ),
          ..._selectedRegistrationTypes.map(
            (type) => Chip(
              label: Text('Mode: $type'),
              onDeleted: () {
                setState(() {
                  _selectedRegistrationTypes.remove(type);
                });
              },
            ),
          ),
          if (_filterAsync != null)
            Chip(
              label: Text('Async: ${_filterAsync! ? 'Yes' : 'No'}'),
              onDeleted: () {
                setState(() {
                  _filterAsync = null;
                });
              },
            ),
          if (_filterReady != null)
            Chip(
              label: Text('Ready: ${_filterReady! ? 'Yes' : 'No'}'),
              onDeleted: () {
                setState(() {
                  _filterReady = null;
                });
              },
            ),
          if (_filterCreated != null)
            Chip(
              label: Text('Created: ${_filterCreated! ? 'Yes' : 'No'}'),
              onDeleted: () {
                setState(() {
                  _filterCreated = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleFilterPressed() async {
    final allRegistrationTypes = _registrations.map((r) => r.registrationType).toSet().toList()..sort();
    final allScopes = _registrations.map((r) => r.scopeName).toSet().toList()..sort();

    final initialState = FilterState(
      selectedScopes: _selectedScopes,
      selectedRegistrationTypes: _selectedRegistrationTypes,
      filterAsync: _filterAsync,
      filterReady: _filterReady,
      filterCreated: _filterCreated,
    );
    final result = await showDialog<FilterState>(
      context: context,
      builder: (context) =>
          FilterDialog(registrationTypes: allRegistrationTypes, scopes: allScopes, initialState: initialState),
    );

    if (result != null) {
      setState(() {
        _selectedScopes
          ..clear()
          ..addAll(result.selectedScopes);
        _selectedRegistrationTypes
          ..clear()
          ..addAll(result.selectedRegistrationTypes);
        _filterAsync = result.filterAsync;
        _filterReady = result.filterReady;
        _filterCreated = result.filterCreated;
      });
    }
  }

  Future<void> _handleSortPressed() async {
    final initialState = SortState(field: _sortField, direction: _sortDirection);
    final result = await showDialog<SortState>(
      context: context,
      builder: (context) => SortDialog(initialState: initialState),
    );
    if (result != null) {
      setState(() {
        _sortField = result.field;
        _sortDirection = result.direction;
      });
    }
  }
}
