import 'package:flutter/material.dart';

import '../strings.dart';
import 'file_list.dart' show formatBytes;

/// Thin Explorer-style status strip: item count on the left, selection summary
/// (count + combined size) on the right.
class StatusBar extends StatelessWidget {
  final int itemCount;
  final int selectedCount;
  final int? selectedBytes;
  final FileExplorerStrings strings;

  const StatusBar({
    super.key,
    required this.itemCount,
    required this.selectedCount,
    required this.selectedBytes,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(strings.itemCount(itemCount), style: style),
          const Spacer(),
          if (selectedCount > 0)
            Text(
              strings.selectionSummary(
                selectedCount,
                (selectedBytes != null && selectedBytes! > 0)
                    ? formatBytes(selectedBytes!)
                    : '',
              ),
              style: style,
            ),
        ],
      ),
    );
  }
}
