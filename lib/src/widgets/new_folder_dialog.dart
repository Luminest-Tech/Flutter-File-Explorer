import 'package:flutter/material.dart';

import '../strings.dart';

class NewFolderDialog extends StatefulWidget {
  final FileExplorerStrings strings;

  const NewFolderDialog({super.key, required this.strings});

  static Future<String?> show(BuildContext context, FileExplorerStrings strings) {
    return showDialog<String>(
      context: context,
      builder: (_) => NewFolderDialog(strings: strings),
    );
  }

  @override
  State<NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<NewFolderDialog> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.strings.newFolderDefaultName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    if (name.contains(RegExp(r'[\\/:*?"<>|]'))) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(s.newFolderTitle),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          decoration: InputDecoration(
            labelText: s.newFolderFieldLabel,
            isDense: true,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancelButton),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(s.createButton),
        ),
      ],
    );
  }
}
