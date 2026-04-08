import 'package:flutter/material.dart';

/// Filter state data class
class FilterState {
  final Set<String> selectedScopes;
  final Set<String> selectedRegistrationTypes;
  final bool? filterAsync;
  final bool? filterReady;
  final bool? filterCreated;

  const FilterState({
    this.selectedScopes = const {},
    this.selectedRegistrationTypes = const {},
    this.filterAsync,
    this.filterReady,
    this.filterCreated,
  });

  FilterState copyWith({
    Set<String>? selectedScopes,
    Set<String>? selectedRegistrationTypes,
    bool? filterAsync,
    bool? filterReady,
    bool? filterCreated,
  }) {
    return FilterState(
      selectedScopes: selectedScopes ?? this.selectedScopes,
      selectedRegistrationTypes: selectedRegistrationTypes ?? this.selectedRegistrationTypes,
      filterAsync: filterAsync ?? this.filterAsync,
      filterReady: filterReady ?? this.filterReady,
      filterCreated: filterCreated ?? this.filterCreated,
    );
  }
}

/// Standalone filter dialog widget
class FilterDialog extends StatefulWidget {
  final List<String> registrationTypes;
  final List<String> scopes;
  final FilterState initialState;

  const FilterDialog({super.key, required this.registrationTypes, required this.scopes, required this.initialState});

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late Set<String> selectedScopes;
  late Set<String> selectedRegistrationTypes;
  late bool? filterAsync;
  late bool? filterReady;
  late bool? filterCreated;

  @override
  void initState() {
    super.initState();
    selectedScopes = Set<String>.from(widget.initialState.selectedScopes);
    selectedRegistrationTypes = Set<String>.from(widget.initialState.selectedRegistrationTypes);
    filterAsync = widget.initialState.filterAsync;
    filterReady = widget.initialState.filterReady;
    filterCreated = widget.initialState.filterCreated;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter'),
      content: SingleChildScrollView(
        child: Column(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.scopes.isNotEmpty) ...[
              const Text('Scope:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.scopes
                    .map(
                      (scope) => FilterChip(
                        label: Text(scope),
                        selected: selectedScopes.contains(scope),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedScopes.add(scope);
                            } else {
                              selectedScopes.remove(scope);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            if (widget.registrationTypes.isNotEmpty) ...[
              const Text('Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.registrationTypes
                    .map(
                      (type) => FilterChip(
                        label: Text(type),
                        selected: selectedRegistrationTypes.contains(type),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedRegistrationTypes.add(type);
                            } else {
                              selectedRegistrationTypes.remove(type);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            const Text('Async:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Yes'),
                  selected: filterAsync == true,
                  onSelected: (selected) {
                    setState(() {
                      filterAsync = selected ? true : null;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('No'),
                  selected: filterAsync == false,
                  onSelected: (selected) {
                    setState(() {
                      filterAsync = selected ? false : null;
                    });
                  },
                ),
              ],
            ),

            const Text('Ready:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Yes'),
                  selected: filterReady == true,
                  onSelected: (selected) {
                    setState(() {
                      filterReady = selected ? true : null;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('No'),
                  selected: filterReady == false,
                  onSelected: (selected) {
                    setState(() {
                      filterReady = selected ? false : null;
                    });
                  },
                ),
              ],
            ),

            const Text('Created:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Yes'),
                  selected: filterCreated == true,
                  onSelected: (selected) {
                    setState(() {
                      filterCreated = selected ? true : null;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('No'),
                  selected: filterCreated == false,
                  onSelected: (selected) {
                    setState(() {
                      filterCreated = selected ? false : null;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              selectedScopes.clear();
              selectedRegistrationTypes.clear();
              filterAsync = null;
              filterReady = null;
              filterCreated = null;
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(
              FilterState(
                selectedScopes: selectedScopes,
                selectedRegistrationTypes: selectedRegistrationTypes,
                filterAsync: filterAsync,
                filterReady: filterReady,
                filterCreated: filterCreated,
              ),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
