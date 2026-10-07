/// 全屏休息页：正计时秒表，休息结束自动返回计时。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'screen_time_controller.dart';

/// 全屏休息页。
///
/// 展示从休息开始到现在的毫秒级正计时秒表，当达到配置的休息时长后
/// 状态机会自动回到计时阶段，本页随之消失。
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

  @override
  void initState() {
    super.initState();
    final endsAt = widget.controller.machine.state.restEndsAt;
    final duration = widget.controller.machine.settings.restDuration;
    _restStart = endsAt?.subtract(duration) ?? DateTime.now();
    _tick();
    // 毫秒级刷新：每 50ms 更新一次秒表显示。
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
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
                '休息中',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _StopwatchDisplay(elapsed: _elapsed),
              const SizedBox(height: 16),
              Text(
                '目标时长 ${total.inMinutes} 分 ${total.inSeconds % 60} 秒',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              LinearProgressIndicator(value: progress, minHeight: 8),
              const Spacer(),
              Text(
                '休息结束后将自动返回',
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
  final Duration elapsed;

  const _StopwatchDisplay({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (elapsed.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');

    return Text(
      '$mm:$ss.$ms',
      textAlign: TextAlign.center,
      style: theme.textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        color: theme.colorScheme.primary,
      ),
    );
  }
}
