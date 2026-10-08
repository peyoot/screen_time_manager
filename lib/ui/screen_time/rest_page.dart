/// 全屏休息页：毫秒级秒表，支持正计时/倒计时切换，休息结束自动返回。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import 'screen_time_controller.dart';

/// 全屏休息页。
///
/// 展示毫秒级秒表（精度 50ms），支持正计时/倒计时切换：
/// - 正计时：从 0 开始累计，表示已休息时长；
/// - 倒计时：从目标时长递减，表示剩余休息时间。
/// 休息结束后状态机自动回到计时阶段，本页随之消失。
class RestPage extends StatefulWidget {
  final ScreenTimeController controller;

  const RestPage({super.key, required this.controller});

  @override
  State<RestPage> createState() => _RestPageState();
}

class _RestPageState extends State<RestPage> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  late final DateTime _restStart;
  bool _countDown = false;

  @override
  void initState() {
    super.initState();
    final endsAt = widget.controller.machine.state.restEndsAt;
    final duration = widget.controller.machine.settings.restDuration;
    _restStart = endsAt?.subtract(duration) ?? DateTime.now();
    _tick();
    // 毫秒级刷新：每 16ms 更新一次秒表显示（约 60fps），确保三位毫秒变化可见。
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    final elapsed = DateTime.now().difference(_restStart);
    setState(() => _elapsed = elapsed < Duration.zero ? Duration.zero : elapsed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = controller.machine.settings;
    final total = settings.restDuration;
    final theme = Theme.of(context);
    final l10n = S.of(context);

    // 根据模式计算显示时长：正计时直接显示，倒计时从总时长减去已用时。
    final displayDuration = _countDown
        ? (total - _elapsed < Duration.zero ? Duration.zero : total - _elapsed)
        : _elapsed;

    // 进度条始终基于正计时（已用时长 / 总时长）。
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.hotel_outlined,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.restTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _StopwatchDisplay(
                duration: displayDuration,
                isCountDown: _countDown,
              ),
              const SizedBox(height: 8),
              // 正计时/倒计时切换按钮。
              TextButton.icon(
                onPressed: () => setState(() => _countDown = !_countDown),
                icon: Icon(
                  _countDown ? Icons.timer_outlined : Icons.timer_10_outlined,
                  size: 18,
                ),
                label: Text(_countDown ? l10n.restCountDown : l10n.restCountUp),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.restTarget(total.inMinutes, total.inSeconds % 60),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              LinearProgressIndicator(value: progress, minHeight: 8),
              const Spacer(),
              Text(
                l10n.restAutoReturn,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 毫秒级秒表显示组件。
class _StopwatchDisplay extends StatelessWidget {
  final Duration duration;
  final bool isCountDown;

  const _StopwatchDisplay({
    required this.duration,
    required this.isCountDown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mm = duration.inMinutes.toString().padLeft(2, '0');
    final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');

    return Text(
      '$mm:$ss.$ms',
      textAlign: TextAlign.center,
      style: theme.textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        color: isCountDown
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
      ),
    );
  }
}
