import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum BottomSheetSnap { collapsed, peek, expanded }

class AppBottomSheet extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    BottomSheetSnap snap,
    ScrollController scrollController,
  ) builder;
  final BottomSheetSnap initialSnap;
  final ValueChanged<BottomSheetSnap>? onSnapChange;

  const AppBottomSheet({
    super.key,
    required this.builder,
    this.initialSnap = BottomSheetSnap.peek,
    this.onSnapChange,
  });

  @override
  State<AppBottomSheet> createState() => _AppBottomSheetState();
}

class _AppBottomSheetState extends State<AppBottomSheet> {
  static const double _collapsedFactor = 0.16;
  static const double _peekFactor = 0.70;
  static const double _expandedFactor = 0.96;

  late BottomSheetSnap _snap;
  late final DraggableScrollableController _sheetController;

  @override
  void initState() {
    super.initState();
    _snap = widget.initialSnap;
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_handleSheetSizeChange);
  }

  double _factorForSnap(BottomSheetSnap snap) {
    return switch (snap) {
      BottomSheetSnap.collapsed => _collapsedFactor,
      BottomSheetSnap.peek => _peekFactor,
      BottomSheetSnap.expanded => _expandedFactor,
    };
  }

  BottomSheetSnap _snapForFactor(double size) {
    if (size <= (_collapsedFactor + _peekFactor) / 2) {
      return BottomSheetSnap.collapsed;
    }
    if (size >= (_peekFactor + _expandedFactor) / 2) {
      return BottomSheetSnap.expanded;
    }
    return BottomSheetSnap.peek;
  }

  void _handleSheetSizeChange() {
    if (!_sheetController.isAttached) return;
    final nextSnap = _snapForFactor(_sheetController.size);
    if (nextSnap != _snap && mounted) {
      setState(() => _snap = nextSnap);
      widget.onSnapChange?.call(nextSnap);
    }
  }

  Future<void> _animateToSnap(BottomSheetSnap target) async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      _factorForSnap(target),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleFromHandle() {
    final target = switch (_snap) {
      BottomSheetSnap.collapsed => BottomSheetSnap.peek,
      BottomSheetSnap.peek => BottomSheetSnap.expanded,
      BottomSheetSnap.expanded => BottomSheetSnap.peek,
    };
    _animateToSnap(target);
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxHeight) {
    if (!_sheetController.isAttached || maxHeight <= 0) return;
    final delta = (details.primaryDelta ?? 0) / maxHeight;
    final nextSize =
        (_sheetController.size - delta).clamp(_collapsedFactor, _expandedFactor);
    _sheetController.jumpTo(nextSize);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final velocity = details.primaryVelocity ?? 0;
    final current = _sheetController.size;

    if (velocity > 350) {
      // Geser ke bawah
      final target = current < _peekFactor - 0.03
          ? BottomSheetSnap.collapsed
          : BottomSheetSnap.peek;
      _animateToSnap(target);
      return;
    }
    if (velocity < -350) {
      // Geser ke atas
      final target = current > _peekFactor + 0.03
          ? BottomSheetSnap.expanded
          : BottomSheetSnap.peek;
      _animateToSnap(target);
      return;
    }

    _animateToSnap(_snapForFactor(current));
  }

  @override
  void dispose() {
    _sheetController.removeListener(_handleSheetSizeChange);
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: _factorForSnap(widget.initialSnap),
        minChildSize: _collapsedFactor,
        maxChildSize: _expandedFactor,
        snap: true,
        snapSizes: const [_collapsedFactor, _peekFactor, _expandedFactor],
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 24,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.s2),
                _Handle(
                  snap: _snap,
                  onTap: _toggleFromHandle,
                  onVerticalDragUpdate: (details) =>
                      _handleDragUpdate(details, screenHeight),
                  onVerticalDragEnd: _handleDragEnd,
                ),
                Expanded(
                  child: widget.builder(context, _snap, scrollController),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final BottomSheetSnap snap;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  const _Handle({
    required this.snap,
    required this.onTap,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  String get _hintText => switch (snap) {
        BottomSheetSnap.collapsed => '⌃ TARIK KE ATAS UNTUK HASIL SCAN',
        BottomSheetSnap.peek => '⌃ TARIK KE ATAS · ⌄ GESER KE BAWAH',
        BottomSheetSnap.expanded => '⌄ TARIK KE BAWAH UNTUK PERKECIL',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _hintText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
