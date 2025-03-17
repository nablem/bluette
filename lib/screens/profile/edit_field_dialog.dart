import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../l10n/app_localizations.dart';

class EditFieldDialog extends StatefulWidget {
  final String initialValue;
  final String label;
  final String field;

  const EditFieldDialog({
    super.key,
    required this.initialValue,
    required this.label,
    required this.field,
  });

  @override
  State<EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<EditFieldDialog> {
  late TextEditingController _controller;
  String? _errorMessage;
  String? _selectedDropdownValue;

  // Options for dropdown fields
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _interestedInOptions = ['Male', 'Female', 'Everyone'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);

    // Initialize dropdown value if applicable
    if (widget.field == 'gender') {
      _selectedDropdownValue =
          _genderOptions.contains(widget.initialValue)
              ? widget.initialValue
              : null;
    } else if (widget.field == 'interested_in') {
      _selectedDropdownValue =
          _interestedInOptions.contains(widget.initialValue)
              ? widget.initialValue
              : null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _validateInput() {
    final l10n = AppLocalizations.of(context)!;

    // For dropdown fields, check if a value is selected
    if ((widget.field == 'gender' || widget.field == 'interested_in') &&
        _selectedDropdownValue == null) {
      setState(() {
        _errorMessage = l10n.errorSelectValue;
      });
      return false;
    }

    // For text fields, check if empty
    if (widget.field != 'gender' &&
        widget.field != 'interested_in' &&
        _controller.text.isEmpty) {
      setState(() {
        _errorMessage = l10n.errorFieldRequired(widget.label);
      });
      return false;
    }

    // Special validation for age
    if (widget.field == 'age') {
      try {
        final age = int.parse(_controller.text);
        if (age < 18 || age > 120) {
          setState(() {
            _errorMessage = l10n.errorAgeRange;
          });
          return false;
        }
      } catch (e) {
        setState(() {
          _errorMessage = l10n.errorInvalidNumber;
        });
        return false;
      }
    }

    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  void _save() {
    if (_validateInput()) {
      if (widget.field == 'age') {
        // Return as integer for age
        Navigator.of(context).pop(int.parse(_controller.text));
      } else if (widget.field == 'gender' || widget.field == 'interested_in') {
        // Return selected dropdown value
        Navigator.of(context).pop(_selectedDropdownValue);
      } else {
        // Return as string for other fields
        Navigator.of(context).pop(_controller.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(l10n.editProfile),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.field == 'gender')
            _buildDropdown(_genderOptions, l10n.selectGender)
          else if (widget.field == 'interested_in')
            _buildDropdown(_interestedInOptions, l10n.selectPreference)
          else
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: widget.label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorMessage,
              ),
              keyboardType:
                  widget.field == 'age'
                      ? TextInputType.number
                      : TextInputType.text,
              autofocus: true,
              onSubmitted: (_) => _save(),
            ),

          if ((widget.field == 'gender' || widget.field == 'interested_in') &&
              _errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _save,
          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _buildDropdown(List<String> options, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDropdownValue,
          hint: Text(hint),
          isExpanded: true,
          dropdownColor: Colors.white,
          items:
              options.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedDropdownValue = newValue;
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }
}
