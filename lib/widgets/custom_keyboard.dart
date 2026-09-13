import 'package:flutter/material.dart';

/// In-app keyboard. The Android system keyboard is never opened: typing
/// screens use a read-only field plus this keyboard.
class CustomKeyboard extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final String languageHint; // e.g. 'English', 'Persian', 'German'

  const CustomKeyboard({
    super.key,
    required this.onKey,
    required this.onBackspace,
    required this.onSpace,
    this.languageHint = 'English',
  });

  List<List<String>> get _rows {
    final hint = languageHint.toLowerCase();
    if (hint.contains('persian') ||
        hint.contains('farsi') ||
        hint.contains('فارسی')) {
      return const [
        ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج', 'چ'],
        ['ش', 'س', 'ی', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ک', 'گ'],
        ['ظ', 'ط', 'ز', 'ر', 'ذ', 'د', 'پ', 'و'],
      ];
    }
    if (hint.contains('german') || hint.contains('deutsch')) {
      return const [
        ['Q', 'W', 'E', 'R', 'T', 'Z', 'U', 'I', 'O', 'P', 'Ü'],
        ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ö', 'Ä'],
        ['Y', 'X', 'C', 'V', 'B', 'N', 'M', 'ẞ'],
      ];
    }
    // Default Latin layout (English + other languages).
    return const [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in _rows) _buildRow(context, row),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _Key(
                    label: 'SPACE',
                    onTap: onSpace,
                    wide: true,
                  ),
                ),
                Expanded(
                  child: _Key(
                    icon: Icons.backspace_outlined,
                    onTap: onBackspace,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> row) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          for (final key in row)
            Expanded(
              child: _Key(label: key, onTap: () => onKey(key)),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool wide;

  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 22)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: wide ? 13 : 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
