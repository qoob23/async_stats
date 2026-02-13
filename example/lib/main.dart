import 'dart:async';
import 'dart:math';

import 'package:async_stats/async_stats.dart';
import 'package:flutter/material.dart';

void main() {
  const duration = Duration(milliseconds: 100);
  final trackedZone = RunningTrackedZone(granularity: duration);

  void spawnMicrotasks() => Future(() {
        final random = Random();
        final timers = random.nextInt(25);
        for (var i = 0; i < timers; i++) {
          Future(() {
            final microtasks = random.nextInt(10);
            for (var i = 0; i < microtasks; i++) {
              scheduleMicrotask(() {
                // no-op
              });
            }
          });
        }
        Future.delayed(duration, () => spawnMicrotasks());
      });

  trackedZone.runWithStats(() {
    spawnMicrotasks();
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Async Stats Example'),
      ),
      body: const DraggableBody(),
    );
  }
}

class DraggableBody extends StatefulWidget {
  const DraggableBody({super.key});

  @override
  State<DraggableBody> createState() => _DraggableBodyState();
}

class _DraggableBodyState extends State<DraggableBody> {
  Offset _offset = Offset.zero;
  double _width = 200;
  double _height = 200;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned(
              top: _offset.dy,
              left: _offset.dx,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _offset += details.delta;
                    _offset = Offset(
                      max(0, min(constraints.maxWidth - _width, _offset.dx)),
                      max(0, min(constraints.maxHeight - _height, _offset.dy)),
                    );
                  });
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.purple, width: 1),
                  ),
                  child: SizedBox(
                    height: _height,
                    width: _width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      // crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: StatsWidget()),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _width = max(
                                    200,
                                    min(
                                      constraints.maxWidth,
                                      _width + details.delta.dx,
                                    ),
                                  );
                                  _height = max(
                                    200,
                                    min(
                                      constraints.maxHeight,
                                      _height + details.delta.dy,
                                    ),
                                  );
                                });
                              },
                              onDoubleTap: () {
                                setState(() {
                                  if (_width == 200 && _height == 200) {
                                    _width = constraints.maxWidth;
                                    _height = constraints.maxHeight;
                                  } else {
                                    _width = 200;
                                    _height = 200;
                                  }
                                });
                              },
                              child: const Icon(Icons.south_east, size: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
