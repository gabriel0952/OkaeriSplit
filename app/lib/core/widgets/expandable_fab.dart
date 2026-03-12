import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────
// ExpandableFabChild — data class for each child button
// ──────────────────────────────────────────────────────────────

class ExpandableFabChild {
  const ExpandableFabChild({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

// ──────────────────────────────────────────────────────────────
// ExpandableFab — expandable multi-action FAB
//
// Uses a Column where child buttons always occupy their full size
// (maintainSize) but are invisible + non-interactive when closed.
// This keeps the Column height constant so Scaffold can position
// the FAB correctly at all times.
// ──────────────────────────────────────────────────────────────

class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    required this.children,
    this.openIcon = Icons.add,
  });

  final List<ExpandableFabChild> children;
  final IconData openIcon;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close() {
    if (_isOpen) _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Child buttons — always in layout (maintains Column height constant)
        // so Scaffold always positions the main FAB at the correct location.
        ...widget.children.reversed.map((child) {
          return IgnorePointer(
            ignoring: !_isOpen,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tappable label chip
                    GestureDetector(
                      onTap: () {
                        _close();
                        child.onPressed();
                      },
                      child: Material(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Text(
                            child.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Small FAB
                    FloatingActionButton.small(
                      heroTag: child.label,
                      onPressed: () {
                        _close();
                        child.onPressed();
                      },
                      child: Icon(child.icon, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Main FAB — always visible at bottom
        FloatingActionButton(
          heroTag: 'expandable_main',
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_isOpen ? Icons.close : widget.openIcon),
          ),
        ),
      ],
    );
  }
}
