import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/motion.dart';

/// Starts a push transition one frame after the page is first built, so a long
/// first build does not swallow the start of the transition. A page whose
/// first load is still running does not hold the transition: it slides in
/// with its loading state and the content arrives when it is ready, so the
/// page underneath starts receding at once instead of freezing on screen.
mixin DeferredPushRouteMixin<T> on TransitionRoute<T> {
  _TickerCapture? _vsync;

  @override
  AnimationController createAnimationController() {
    final vsync = _vsync = _TickerCapture(navigator!);
    return AnimationController(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      debugLabel: debugLabel,
      vsync: vsync,
    );
  }

  @override
  TickerFuture didPush() {
    final ticker = _vsync?.ticker;
    if (ticker == null || ticker.muted) {
      return super.didPush();
    }
    ticker.muted = true;
    final pushed = super.didPush();
    final context = navigator!.context;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ticker.muted = !TickerMode.getValuesNotifier(context).value.enabled;
    });
    return pushed;
  }
}

/// Marks a page's first content as not ready yet. The push no longer waits
/// for it: the page moves in with its loading state and the content appears
/// when it is ready.
class ArrivalHold extends StatelessWidget {
  const ArrivalHold({super.key, required this.ready, required this.child});

  final bool ready;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _TickerCapture implements TickerProvider {
  _TickerCapture(this._parent);

  final NavigatorState _parent;
  Ticker? ticker;
  Duration _lead = Duration.zero;
  Duration? _last;

  // A run started between frames first ticks at zero, showing the frame on
  // screen again; its start value stays, as the route below links to it.
  @override
  Ticker createTicker(TickerCallback onTick) {
    return ticker = _parent.createTicker((elapsed) {
      final last = _last;
      if (elapsed == Duration.zero) {
        _lead = frameIntervalOf(_parent.context);
      } else if (last != null && elapsed <= last) {
        _lead = Duration.zero;
      }
      _last = elapsed;
      onTick(elapsed + _lead);
    });
  }
}
