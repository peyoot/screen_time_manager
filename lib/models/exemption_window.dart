/// 强制休息豁免时间段模型。
///
/// 用户在"强制休息"开启时仍可指定若干时间段（可每天重复，也可只在
/// 一周中的特定几天生效）。落在这些时间段内时，状态机与原生计时核心
/// 都按"强制休息已关闭"处理：只累计亮屏时长、阈值进度冻结、不触发休息。
library;

/// 一个豁免时间段（按当地时区的"星期几 + 分钟"表达）。
///
/// - [startMinute] / [endMinute]：一天内的分钟数（0..1440，1440 表示 24:00）。
///   区间为左闭右开 `[start, end)`；`end < start` 表示**跨零点**，
///   例如 23:00–07:00 记作 1380–420，归属起点那一天。
/// - [weekdays]：生效的星期几，取值同 [DateTime.weekday]（周一=1 … 周日=7）。
///   包含全部 7 天即"每天重复"。
class ExemptionWindow {
  /// 起始分钟（含）。
  final int startMinute;

  /// 结束分钟（不含）；1440 表示当天 24:00。
  final int endMinute;

  /// 生效星期几集合（1..7）。
  final Set<int> weekdays;

  ExemptionWindow({
    required this.startMinute,
    required this.endMinute,
    required Set<int> weekdays,
  }) : weekdays = Set.unmodifiable(weekdays) {
    if (startMinute < 0 || startMinute > 1439) {
      throw ArgumentError.value(startMinute, 'startMinute', '必须在 0..1439');
    }
    if (endMinute < 0 || endMinute > 1440) {
      throw ArgumentError.value(endMinute, 'endMinute', '必须在 0..1440');
    }
    if (startMinute == endMinute) {
      throw ArgumentError('起始与结束时间不能相同');
    }
    if (this.weekdays.isEmpty) {
      throw ArgumentError('生效星期不能为空');
    }
    if (this.weekdays.any((d) => d < DateTime.monday || d > DateTime.sunday)) {
      throw ArgumentError.value(this.weekdays, 'weekdays', '取值须在 1..7');
    }
  }

  /// 是否为每天重复（7 天全选）。
  bool get repeatsDaily => weekdays.length == 7;

  /// 是否跨零点。
  bool get crossesMidnight => endMinute < startMinute;

  /// 在 [now]（当地时区）时刻本时间段是否生效。
  ///
  /// 跨零点时段归属起点那一天：例如"周五 23:00–07:00"，
  /// 周六凌晨 02:00 仍算生效（按周五判定）。
  bool isActiveAt(DateTime now) {
    final minute = now.hour * 60 + now.minute;
    if (!crossesMidnight) {
      return weekdays.contains(now.weekday) &&
          minute >= startMinute &&
          minute < endMinute;
    }
    if (minute >= startMinute) return weekdays.contains(now.weekday);
    if (minute < endMinute) {
      final previousDay =
          now.weekday == DateTime.monday ? DateTime.sunday : now.weekday - 1;
      return weekdays.contains(previousDay);
    }
    return false;
  }

  /// 序列化为通道/JSON 可传输的 Map（weekdays 排序后输出，便于比较）。
  Map<String, dynamic> toJson() => {
        'startMinute': startMinute,
        'endMinute': endMinute,
        'weekdays': weekdays.toList()..sort(),
      };

  /// 从 JSON 构造；字段非法时抛出 [FormatException]（调用方选择跳过该条）。
  factory ExemptionWindow.fromJson(Map<String, dynamic> json) {
    final start = json['startMinute'];
    final end = json['endMinute'];
    final days = json['weekdays'];
    if (start is! int || end is! int || days is! List) {
      throw const FormatException('豁免时间段字段类型错误');
    }
    final weekdays = <int>{};
    for (final d in days) {
      if (d is! int || d < DateTime.monday || d > DateTime.sunday) {
        throw const FormatException('豁免时间段星期取值错误');
      }
      weekdays.add(d);
    }
    try {
      return ExemptionWindow(
        startMinute: start,
        endMinute: end,
        weekdays: weekdays,
      );
    } on ArgumentError catch (e) {
      throw FormatException('豁免时间段取值错误: ${e.message}');
    }
  }

  ExemptionWindow copyWith({
    int? startMinute,
    int? endMinute,
    Set<int>? weekdays,
  }) {
    return ExemptionWindow(
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      weekdays: weekdays ?? this.weekdays,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExemptionWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hash(
        startMinute,
        endMinute,
        Object.hashAll(weekdays.toList()..sort()),
      );

  @override
  String toString() =>
      'ExemptionWindow(${weekdays.toList()..sort()} $startMinute-$endMinute)';
}
