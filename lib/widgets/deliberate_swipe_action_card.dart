import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Passive horizontal swipe affordance that never competes with vertical scroll.
class DeliberateSwipeActionCard extends StatefulWidget {
  const DeliberateSwipeActionCard({
    super.key,
    required this.child,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.rightLabel = 'إجراء',
    this.leftLabel = 'إجراء',
    this.rightIcon = Icons.arrow_forward_rounded,
    this.leftIcon = Icons.arrow_back_rounded,
    this.rightColor,
    this.leftColor,
    this.triggerDistance = 104,
  });

  final Widget child;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final String rightLabel;
  final String leftLabel;
  final IconData rightIcon;
  final IconData leftIcon;
  final Color? rightColor;
  final Color? leftColor;
  final double triggerDistance;

  @override
  State<DeliberateSwipeActionCard> createState() => _DeliberateSwipeActionCardState();
}

class _DeliberateSwipeActionCardState extends State<DeliberateSwipeActionCard> {
  int? _pointer;
  Offset? _start;
  Offset? _last;
  bool _horizontalIntent = false;
  bool _verticalIntent = false;
  double _offset = 0;

  static const double _intentDelta = 24;
  static const double _directionRatio = 2.2;
  static const double _maxReveal = 126;

  void _reset({bool repaint = true}) {
    _pointer = null;
    _start = null;
    _last = null;
    _horizontalIntent = false;
    _verticalIntent = false;
    if (_offset != 0 && repaint && mounted) {
      setState(() => _offset = 0);
    } else {
      _offset = 0;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _start = event.position;
    _last = event.position;
    _horizontalIntent = false;
    _verticalIntent = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer || _start == null || _verticalIntent) return;
    _last = event.position;
    final delta = event.position - _start!;
    final dx = delta.dx;
    final dy = delta.dy;
    final absDx = dx.abs();
    final absDy = dy.abs();

    if (!_horizontalIntent) {
      if (absDy >= _intentDelta && absDy > absDx * 1.15) {
        _verticalIntent = true;
        return;
      }
      if (absDx < _intentDelta || absDx < absDy * _directionRatio) return;
      if (dx > 0 && widget.onSwipeRight == null) return;
      if (dx < 0 && widget.onSwipeLeft == null) return;
      _horizontalIntent = true;
    }

    final allowed = dx > 0 ? widget.onSwipeRight != null : widget.onSwipeLeft != null;
    if (!allowed) return;
    final nextOffset = dx.clamp(-_maxReveal, _maxReveal).toDouble();
    if ((nextOffset - _offset).abs() < 0.5 || !mounted) return;
    setState(() => _offset = nextOffset);
  }

  void _finish(PointerEvent event) {
    if (_pointer != event.pointer) return;
    final start = _start;
    final last = _last ?? event.position;
    final horizontalIntent = _horizontalIntent;
    final verticalIntent = _verticalIntent;
    final offset = _offset;
    final callback = offset >= 0 ? widget.onSwipeRight : widget.onSwipeLeft;

    var shouldTrigger = false;
    if (start != null && horizontalIntent && !verticalIntent && callback != null) {
      final delta = last - start;
      final absDx = delta.dx.abs();
      final absDy = delta.dy.abs();
      final requiredDistance = math.max(widget.triggerDistance, 72);
      shouldTrigger = absDx >= requiredDistance && absDx >= absDy * _directionRatio;
    }

    _reset();
    if (shouldTrigger) callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    final swipeRight = _offset > 0;
    final activeColor = swipeRight
        ? (widget.rightColor ?? Theme.of(context).colorScheme.primary)
        : (widget.leftColor ?? Theme.of(context).colorScheme.secondary);
    final activeLabel = swipeRight ? widget.rightLabel : widget.leftLabel;
    final activeIcon = swipeRight ? widget.rightIcon : widget.leftIcon;
    final alignment = swipeRight ? Alignment.centerLeft : Alignment.centerRight;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _finish,
      onPointerCancel: _finish,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (_offset != 0)
              Positioned.fill(
                child: Container(
                  alignment: alignment,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  color: activeColor.withValues(alpha: 0.16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(activeIcon, color: activeColor),
                      const SizedBox(width: 7),
                      Text(
                        activeLabel,
                        style: TextStyle(color: activeColor, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            Transform.translate(offset: Offset(_offset, 0), child: widget.child),
          ],
        ),
      ),
    );
  }
}
