import 'package:flutter/material.dart';

enum SortField { defaultOrder, type, instanceName, instanceDetails }

enum SortDirection { asc, desc }

/// Sort state data class
class SortState {
  final SortField field;
  final SortDirection direction;

  const SortState({this.field = SortField.defaultOrder, this.direction = SortDirection.asc});
}

/// Standalone sort dialog widget
class SortDialog extends StatefulWidget {
  final SortState initialState;

  const SortDialog({super.key, required this.initialState});

  @override
  State<SortDialog> createState() => _SortDialogState();
}

class _SortDialogState extends State<SortDialog> {
  late SortField selectedField;
  late SortDirection selectedDirection;

  @override
  void initState() {
    super.initState();
    selectedField = widget.initialState.field;
    selectedDirection = widget.initialState.direction;
  }

  String _sortFieldName(SortField field) {
    switch (field) {
      case SortField.defaultOrder:
        return 'Default Order';
      case SortField.type:
        return 'Type';
      case SortField.instanceName:
        return 'Instance Name';
      case SortField.instanceDetails:
        return 'Instance Details';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sort By'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sort field selection
          ...SortField.values.map(
            (field) => RadioMenuButton<SortField>(
              value: field,
              groupValue: selectedField,
              onChanged: (value) {
                setState(() {
                  selectedField = value!;
                });
              },
              child: Text(_sortFieldName(field)),
            ),
          ),
          const Divider(),
          // Sort direction selection
          Row(
            children: [
              Expanded(
                child: RadioMenuButton<SortDirection>(
                  value: SortDirection.asc,
                  groupValue: selectedDirection,
                  onChanged: (value) {
                    setState(() {
                      selectedDirection = value!;
                    });
                  },
                  child: const Text('Ascending'),
                ),
              ),
              Expanded(
                child: RadioMenuButton<SortDirection>(
                  value: SortDirection.desc,
                  groupValue: selectedDirection,
                  onChanged: (value) {
                    setState(() {
                      selectedDirection = value!;
                    });
                  },
                  child: const Text('Descending'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(SortState(field: selectedField, direction: selectedDirection));
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
