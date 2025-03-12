import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../models/profile_filter.dart';

class FilterDialog extends StatefulWidget {
  final ProfileFilter initialFilter;
  final Function(ProfileFilter) onApplyFilter;
  final int? userAge;

  const FilterDialog({
    super.key,
    required this.initialFilter,
    required this.onApplyFilter,
    this.userAge,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late ProfileFilter _filter;
  final double _minPossibleAge = 18;
  final double _maxPossibleAge = 100;
  final double _minPossibleDistance = 1;
  final double _maxPossibleDistance = 50;

  @override
  void initState() {
    super.initState();
    // Create a copy of the initial filter
    _filter = ProfileFilter(
      minAge: widget.initialFilter.minAge,
      maxAge: widget.initialFilter.maxAge,
      maxDistance: widget.initialFilter.maxDistance,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Profiles',
                  style: AppTheme.headingStyle.copyWith(fontSize: 20),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Age Range
            Text('Age Range', style: AppTheme.subheadingStyle),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_filter.minAge}', style: AppTheme.bodyStyle),
                Text('${_filter.maxAge}', style: AppTheme.bodyStyle),
              ],
            ),
            RangeSlider(
              values: RangeValues(
                _filter.minAge.toDouble(),
                _filter.maxAge.toDouble(),
              ),
              min: _minPossibleAge,
              max: _maxPossibleAge,
              divisions: (_maxPossibleAge - _minPossibleAge).toInt(),
              activeColor: AppTheme.primaryColor,
              inactiveColor: Colors.grey[300],
              labels: RangeLabels('${_filter.minAge}', '${_filter.maxAge}'),
              onChanged: (RangeValues values) {
                setState(() {
                  _filter = _filter.copyWith(
                    minAge: values.start.round(),
                    maxAge: values.end.round(),
                  );
                });
              },
            ),

            const SizedBox(height: 20),

            // Maximum Distance
            Text(
              'Maximum Distance (${_filter.maxDistance} km)',
              style: AppTheme.subheadingStyle,
            ),
            const SizedBox(height: 8),
            Slider(
              value: _filter.maxDistance.toDouble(),
              min: _minPossibleDistance,
              max: _maxPossibleDistance,
              divisions: (_maxPossibleDistance - _minPossibleDistance).toInt(),
              activeColor: AppTheme.primaryColor,
              inactiveColor: Colors.grey[300],
              label: '${_filter.maxDistance} km',
              onChanged: (double value) {
                setState(() {
                  _filter = _filter.copyWith(maxDistance: value.round());
                });
              },
            ),

            const SizedBox(height: 30),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  widget.onApplyFilter(_filter);
                  Navigator.pop(context);
                },
                child: const Text('Apply Filters'),
              ),
            ),

            const SizedBox(height: 10),

            // Reset Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _filter = ProfileFilter.defaultFilter(
                      userAge: widget.userAge,
                    );
                  });
                },
                child: const Text('Reset to Default'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
