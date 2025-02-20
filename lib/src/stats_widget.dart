import 'dart:async';

import 'package:async_stats/async_stats.dart';
import 'package:async_stats/src/ring_buffer.dart';
import 'package:flutter/material.dart';

class StatsWidget extends StatelessWidget {
  const StatsWidget({
    super.key,
    this.zone,
    this.timersScale = 100,
    this.microtaskScale = 200,
    this.latencyMsScale = 500,
  });

  final RunningTrackedZone? zone;

  final int timersScale;
  final int microtaskScale;
  final int latencyMsScale;

  @override
  Widget build(BuildContext context) {
    final zone = this.zone ?? RunningTrackedZone.current;
    if (zone == null) {
      return const Text(
        'Async stats tracking is disabled.\n'
        'Provide a TrackedZone object\n'
        'or wrap your widget tree with a TrackedZone.runWithStats().',
      );
    }

    return _Stats(
      granularity: zone.granularity,
      zone: zone,
      timersScale: timersScale,
      microtaskScale: microtaskScale,
      latencyMsScale: latencyMsScale,
    );
  }
}

class _Stats extends StatefulWidget {
  const _Stats({
    required this.granularity,
    required this.zone,
    required this.timersScale,
    required this.microtaskScale,
    required this.latencyMsScale,
  });

  final Duration granularity;
  final RunningTrackedZone zone;

  final int timersScale;
  final int microtaskScale;
  final int latencyMsScale;

  @override
  State<_Stats> createState() => _StatsState();
}

class _StatsState extends State<_Stats> with WidgetsBindingObserver {
  final _Ticker _ticker = _Ticker();
  Timer? _timer;

  RingBuffer<AsyncStats> get _buffer => widget.zone.buffer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  void _run() {
    _timer ??= Timer.periodic(widget.granularity, (timer) {
      if (mounted) {
        _ticker.tick();
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _run();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Timers, scale: ${widget.timersScale}'),
        Expanded(
          child: CustomPaint(
            painter: BarChartPainter(
              buffer: _buffer,
              repaint: _ticker,
              scale: widget.timersScale,
              getTargetMetric: (stats) => stats?.timerCount ?? 0,
            ),
          ),
        ),
        Text('Microtasks, scale: ${widget.microtaskScale}'),
        Expanded(
          child: CustomPaint(
            painter: BarChartPainter(
              buffer: _buffer,
              repaint: _ticker,
              scale: widget.microtaskScale,
              getTargetMetric: (stats) => stats?.microtaskCount ?? 0,
            ),
          ),
        ),
        Text('Avg Latency Ms, scale: ${widget.latencyMsScale}'),
        Expanded(
          child: CustomPaint(
            painter: BarChartPainter(
              buffer: _buffer,
              repaint: _ticker,
              scale: widget.latencyMsScale,
              getTargetMetric: (stats) => stats?.avgLatencyMs ?? 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _Ticker extends ChangeNotifier {
  _Ticker();

  void tick() => notifyListeners();
}

class BarChartPainter extends CustomPainter {
  final RingBuffer<AsyncStats> buffer;
  final int scale;
  final num Function(AsyncStats?) getTargetMetric;

  BarChartPainter({
    required this.buffer,
    required this.scale,
    required this.getTargetMetric,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.blue;

    final greenLinePaint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 4;

    final double barWidth = size.width / buffer.capacity;
    final double maxHeight = size.height;

    for (int i = 0; i < buffer.capacity; i++) {
      final targetMetric = getTargetMetric(buffer.source[i]);
      final x = i * barWidth;
      final double barHeight = (targetMetric / scale) * maxHeight;

      final rect = Rect.fromLTWH(
        x,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRect(rect, paint);
    }

    // Draw the head position.
    final headX = buffer.head * barWidth;
    canvas.drawLine(
      Offset(headX, 0),
      Offset(headX, size.height),
      greenLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
