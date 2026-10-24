/// 强制休息豁免时间段的编辑对话框与展示格式化。
///
/// 仅在"强制休息"开启时由设置对话框调用（关闭时不展示该区块）。
/// 支持每天重复或只在一周中的特定几天生效，并允许跨零点时间段。
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/exemption_window.dart';

/// 弹出豁免时间段编辑器；返回 null 表示取消/未保存。
///
/// [initial] 为空表示新增。
Future<ExemptionWindow?> showExemptionWindowEditor(
  BuildContext context, {
  ExemptionWindow? initial,
}) {
  return showDialog<ExemptionWindow>(
    context: context,
    builder: (_) => _ExemptionWindowDialog(initial: initial),
  );
}

/// 把时间段格式化为列表展示文案，例如"周一 周三 08:00–12:00"。
String formatExemptionWindow(BuildContext context, ExemptionWindow window) {
  final l10n = S.of(context);
  final localizations = MaterialLocalizations.of(context);
  final weekdays = window.weekdays.toList()..sort();
  final dayText = window.repeatsDaily
      ? l10n.exemptEveryDay
      : weekdays.map((day) => weekdayLabel(context, day)).join(' ');
  final start = _formatMinute(context, window.startMinute, localizations);
  final end = _formatMinute(context, window.endMinute, localizations);
  return '$dayText $start–$end';
}

/// 星期几的短名（[weekday] 取 1..7，周一..周日）。
///
/// 优先用 intl 的本地化缩写（如 Mon / 周一 / 月 / 월）；若当前 locale
/// 没有日期符号数据则退回 [MaterialLocalizations.narrowWeekdays]。
String weekdayLabel(BuildContext context, int weekday) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  // 2026-01-05 是周一，依次偏移到目标星期。
  final date = DateTime(2026, 1, 5 + (weekday - DateTime.monday));
  try {
    return DateFormat.E(locale).format(date);
  } on Object {
    return MaterialLocalizations.of(context).narrowWeekdays[weekday % 7];
  }
}

/// 分钟数 → 本地化时间文本（1440 = 次日 00:00，按 00:00 展示）。
String _formatMinute(
  BuildContext context,
  int minute,
  MaterialLocalizations localizations,
) {
  final normalized = minute % 1440;
  final time = TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  return time.format(context);
}

class _ExemptionWindowDialog extends StatefulWidget {
  final ExemptionWindow? initial;

  const _ExemptionWindowDialog({this.initial});

  @override
  State<_ExemptionWindowDialog> createState() => _ExemptionWindowDialogState();
}

class _ExemptionWindowDialogState extends State<_ExemptionWindowDialog> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _days;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _start = initial == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : TimeOfDay(
            hour: initial.startMinute ~/ 60,
            minute: initial.startMinute % 60,
          );
    _end = initial == null
        ? const TimeOfDay(hour: 13, minute: 0)
        : TimeOfDay(
            // 1440 表示 24:00，编辑时回显为次日 00:00。
            hour: (initial.endMinute % 1440) ~/ 60,
            minute: initial.endMinute % 60,
          );
    _days = initial == null
        ? {for (var d = DateTime.monday; d <= DateTime.sunday; d++) d}
        : {...initial.weekdays};
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  void _save() {
    final l10n = S.of(context);
    final startMinute = _start.hour * 60 + _start.minute;
    final endMinute = _end.hour * 60 + _end.minute;
    if (startMinute == endMinute) {
      setState(() => _error = l10n.exemptInvalidRange);
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = l10n.exemptInvalidWeekdays);
      return;
    }
    // 结束时间回显为 00:00 且用户未改动时，按"次日 00:00"（1440）理解更符合
    // 跨零点语义；但若起始时间也早于结束，则 00:00 应表示当天结束。
    final normalizedEnd =
        _end == const TimeOfDay(hour: 0, minute: 0) && startMinute > 0
            ? 1440
            : endMinute;
    if (startMinute == normalizedEnd) {
      setState(() => _error = l10n.exemptInvalidRange);
      return;
    }
    Navigator.of(context).pop(
      ExemptionWindow(
        startMinute: startMinute,
        endMinute: normalizedEnd,
        weekdays: _days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? l10n.exemptDialogAddTitle
            : l10n.exemptDialogEditTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: true),
                    child: Text(
                      l10n.exemptTimeRange(
                        l10n.exemptStart,
                        _start.format(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–'),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: false),
                    child: Text(
                      l10n.exemptTimeRange(
                        l10n.exemptEnd,
                        _end.format(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.exemptWeekdays,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: Text(l10n.exemptEveryDay),
                  selected: _days.length == 7,
                  onSelected: (selected) => setState(() {
                    _days = selected
                        ? {for (var d = 1; d <= 7; d++) d}
                        : <int>{};
                    _error = null;
                  }),
                ),
                for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                  FilterChip(
                    label: Text(weekdayLabel(context, day)),
                    selected: _days.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bankCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.settingsSave)),
      ],
    );
  }
}
