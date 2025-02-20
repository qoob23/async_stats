// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:typed_data';

import 'package:async_stats/src/ring_buffer.dart';
import 'package:meta/meta.dart';

// 1. сколько микротаск было создано таймером / микротаской
// 2. сколько заняла синхронная операция
// 3. стактрейсы и попапы медленных / плодящих микротаски операций?

@immutable
final class AsyncStats {
  final int timerCount;
  final int microtaskCount;
  final double avgLatencyMs;

  const AsyncStats({
    required this.timerCount,
    required this.microtaskCount,
    required this.avgLatencyMs,
  });

  @override
  int get hashCode => Object.hash(timerCount, microtaskCount, avgLatencyMs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsyncStats &&
          runtimeType == other.runtimeType &&
          timerCount == other.timerCount &&
          microtaskCount == other.microtaskCount &&
          avgLatencyMs == other.avgLatencyMs;

  @override
  String toString() =>
      'AsyncStats(timerCount: $timerCount, microtaskCount: $microtaskCount, avgLatencyMs: $avgLatencyMs)';
}

class RunningTrackedZone {
  RunningTrackedZone({
    this.capacity = 100,
    this.granularity = const Duration(seconds: 1),
  }) : _buffer = RingBuffer(capacity) {
    Timer.periodic(granularity, _maybeReportAndReset);
  }

  final int capacity;
  final Duration granularity;

  final RingBuffer<AsyncStats> _buffer;
  RingBuffer<AsyncStats> get buffer => _buffer;

  static RunningTrackedZone? get current {
    return Zone.current[#trackedZone] as RunningTrackedZone?;
  }

  int _timerCount = 0;
  int _microtaskCount = 0;

  final Int64List _latenciesMs = Int64List(10000);
  int _pointer = 0;

  final sw = Stopwatch()..start();

  AsyncStats _produceStats() {
    int sum = 0;

    for (int i = 0; i < _pointer; i++) {
      sum += _latenciesMs[i];
    }

    final avgLatency = _pointer > 0 ? sum / _pointer : 0.0;

    return AsyncStats(
      timerCount: _timerCount,
      microtaskCount: _microtaskCount,
      avgLatencyMs: avgLatency,
    );
  }

  void _reset() {
    _timerCount = 0;
    _microtaskCount = 0;
    _latenciesMs.fillRange(0, _pointer, 0);
    _pointer = 0;
  }

  void _maybeReportAndReset([void _]) {
    if (sw.elapsed > granularity) {
      sw.reset();
      final stats = _produceStats();
      _reset();
      buffer.add(stats);
    }
  }

  R runWithStats<R>(R Function() fn) {
    return runZoned(
      fn,
      zoneValues: {#trackedZone: this},
      zoneSpecification: ZoneSpecification(
        createTimer: (
          Zone self,
          ZoneDelegate parent,
          Zone zone,
          Duration duration,
          void Function() callback,
        ) {
          _timerCount++;
          final sw = Stopwatch()..start();

          void fn() {
            final diff = sw.elapsed - duration;
            _latenciesMs[_pointer++] = diff.inMilliseconds;
            callback();
          }

          return parent.createTimer(zone, duration, fn);
        },
        scheduleMicrotask: (
          Zone self,
          ZoneDelegate parent,
          Zone zone,
          void Function() scheduleMicroTask,
        ) {
          _microtaskCount++;
          return parent.scheduleMicrotask(zone, scheduleMicroTask);
        },
      ),
    );
  }
}
