/// 每日亮屏用量记录模型。
library;

/// 某一自然日内累计的亮屏时长，用于跨天归零与本地持久化。
class DailyUsage {
  /// 记录对应的自然日（当地时区），取值为年月日均已归零的 [DateTime]。
  final DateTime day;

  /// 当日累计亮屏时长。
  final Duration accumulated;

  DailyUsage({required this.day, this.accumulated = Duration.zero})
    : assert(
        day.hour == 0 && day.minute == 0 && day.second == 0,
        'day 必须是归零到日期的 DateTime',
      );

  /// 以 [now] 所在自然日创建一条零用量记录。
  factory DailyUsage.today(DateTime now) {
    return DailyUsage(day: dateOnly(now));
  }

  /// 将任意 [DateTime] 归零到当地时区的日期（00:00:00）。
  static DateTime dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// 从 JSON 构造，`day` 格式为 `yyyy-MM-dd`。
  factory DailyUsage.fromJson(Map<String, dynamic> json) {
    final rawDay = json['day'];
    final seconds = json['accumulatedSeconds'];

    if (rawDay is! String) {
      throw const FormatException('DailyUsage.day 必须是 yyyy-MM-dd 字符串');
    }
    if (seconds is! num || seconds < 0) {
      throw const FormatException('accumulatedSeconds 必须是非负数');
    }

    DateTime? parsed;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDay)) {
      parsed = DateTime.tryParse(rawDay);
    }
    if (parsed == null) {
      throw FormatException('无法解析日期: $rawDay');
    }

    return DailyUsage(
      day: parsed,
      accumulated: Duration(seconds: seconds.toInt()),
    );
  }

  /// 序列化为 JSON，`day` 输出为 `yyyy-MM-dd`。
  Map<String, dynamic> toJson() => {
    'day': _formatDay(day),
    'accumulatedSeconds': accumulated.inSeconds,
  };

  /// 判断 [dt] 是否与本记录属于同一个自然日。
  bool isSameDay(DateTime dt) =>
      dt.year == day.year && dt.month == day.month && dt.day == day.day;

  /// 累加一段亮屏时长，返回新的记录。
  DailyUsage addScreenTime(Duration delta) {
    if (delta <= Duration.zero) return this;
    return DailyUsage(day: day, accumulated: accumulated + delta);
  }

  /// 返回 [now] 所在自然日对应的用量记录：
  /// 同一天则保留累计值，跨天则归零开新一天。
  DailyUsage rollover(DateTime now) {
    if (isSameDay(now)) return this;
    return DailyUsage.today(now);
  }

  static String _formatDay(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  bool operator ==(Object other) =>
      other is DailyUsage &&
      other.day == day &&
      other.accumulated == accumulated;

  @override
  int get hashCode => Object.hash(day, accumulated);

  @override
  String toString() =>
      'DailyUsage(day: ${_formatDay(day)}, accumulated: $accumulated)';
}
