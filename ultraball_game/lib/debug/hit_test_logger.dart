import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Installs diagnostic hooks to surface the exact render box that causes
/// "Cannot hit test a render box that has never been laid out" and the
/// follow-on mouse_tracker.dart:199 assertion.
///
/// Call [install] once before [runApp].  Only active in debug mode.
class HitTestLogger {
  HitTestLogger._();

  static final List<String> _entries = [];
  static int _frame = 0;
  static bool _installed = false;
  static int _unlaidCount = 0; // total unlaid boxes ever seen

  /// Last [maxEntries] log lines (newest at end).
  static List<String> get entries => List.unmodifiable(_entries);
  static int get unlaidEverSeen => _unlaidCount;

  static const int _maxEntries = 60;

  static void install() {
    if (_installed || !kDebugMode) return;
    _installed = true;

    // ── 1. Intercept FlutterError to surface hit-test / mouse-tracker errors ──
    final prev = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exception.toString();
      final relevant = msg.contains('hit test') ||
          msg.contains('laid out') ||
          msg.contains('_debugDuringDeviceUpdate') ||
          msg.contains('mouse_tracker');
      if (relevant) {
        final lines = details.stack?.toString().split('\n') ?? const [];
        final appLines = lines
            .where((l) => l.contains('ultraball') || l.contains('lib/'))
            .take(4)
            .join('\n    ');
        _log('🔴 [F$_frame] ${msg.split("\n").first}\n'
            '  app frames:\n    ${appLines.isNotEmpty ? appLines : "(none)"}');
      }
      prev?.call(details);
    };

    // ── 2. Post-layout scan — runs after drawFrame() but before updateAllDevices ──
    // Registration order matters: Flutter's _handlePersistentFrameCallback
    // (which runs drawFrame) is registered before main() runs, so our callback
    // runs AFTER layout/paint and BEFORE post-frame callbacks (updateAllDevices).
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      _frame++;
      _scanRenderTree();
    });
  }

  // Walk the render tree and log any RenderBox where hasSize == false
  // (meaning performLayout has never run on it).
  static void _scanRenderTree() {
    int count = 0;
    // Keep only the last 10 segments of the path to avoid truncation
    final firstParts = <String>[];

    void visit(RenderObject obj, List<String> crumbs, int depth) {
      if (depth > 80) return;
      if (obj is RenderBox && !obj.hasSize) {
        _unlaidCount++;
        count++;
        if (firstParts.isEmpty) {
          firstParts.addAll(crumbs);
        }
      }
      int i = 0;
      obj.visitChildren((child) {
        final next = [...crumbs, '${obj.runtimeType}[$i]'];
        // Keep only last 12 crumbs to bound string length
        final trimmed = next.length > 12 ? next.sublist(next.length - 12) : next;
        visit(child, trimmed, depth + 1);
        i++;
      });
    }

    try {
      for (final rv in RendererBinding.instance.renderViews) {
        visit(rv, ['root'], 0);
      }
    } catch (e, s) {
      _log('⚠️ [F$_frame] SCAN THREW: $e');
      return;
    }

    if (count > 0) {
      final pathStr = firstParts.isEmpty ? '(none)' : firstParts.join('>');
      // Single message with count + path tail
      _log('🟠 [F$_frame] $count unlaid ║ $pathStr');
    }
  }

  static void _log(String msg) {
    _entries.add(msg);
    if (_entries.length > _maxEntries) _entries.removeAt(0);
    dev.log(msg, name: 'HitTestLogger');
  }
}

/// Overlay widget — wrap the game widget (or the whole app) with this to see
/// [HitTestLogger] output on screen.  Refreshes every second.
class HitTestDebugOverlay extends StatefulWidget {
  final Widget child;
  const HitTestDebugOverlay({super.key, required this.child});

  @override
  State<HitTestDebugOverlay> createState() => _HitTestDebugOverlayState();
}

class _HitTestDebugOverlayState extends State<HitTestDebugOverlay> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;
    final entries = HitTestLogger.entries;
    return Stack(
      children: [
        widget.child,
        if (entries.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 180,
                color: const Color(0xCC000000),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HitTestLogger  (${HitTestLogger.unlaidEverSeen} unlaid boxes total)',
                      style: const TextStyle(
                        color: Color(0xFFFF8800),
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        itemCount: entries.length,
                        itemBuilder: (_, i) {
                          final e = entries[entries.length - 1 - i];
                          final color = e.startsWith('🔴')
                              ? const Color(0xFFFF4444)
                              : e.startsWith('🟠')
                                  ? const Color(0xFFFF8800)
                                  : const Color(0xFF88CCFF);
                          return Text(
                            e,
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
