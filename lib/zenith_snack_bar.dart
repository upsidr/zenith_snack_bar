import 'dart:async';

import 'package:flutter/material.dart';

/// The controller for the SnackBar.
///
/// Typical usage is as follows:
///
/// ```dart
/// ZenithSnackBarScope.of(context).show(
///   context: context,
///   content: ...,
/// );
/// ```
class ZenithSnackBarController {
  _Entry? _overlay;
  final Map<Key, Timer> _timers = {};
  Completer? _removing;

  /// Add the content.
  ///
  /// Show the SnackBar if the content is the first one. Add the content
  /// according to priority if items already exist.
  ///
  /// **Note that the content requires a [Key].**
  Future<void> add({
    required BuildContext context,
    required ZenithSnackBarTileMixin content,
  }) async {
    assert(content.key != null);
    await _removing?.future;
    final currentChildren =
        _overlay?.snackBar.children.where((e) => e.key != content.key).toList();
    final children = ((currentChildren ?? []) + [content])
      ..sort((a, b) => a.priority.compareTo(b.priority));
    final overlay = _overlay;
    if (overlay != null) {
      _overlay = overlay.copyWith(
        snackBar: _ZenithSnackBar(
          highlight: children.first,
          controller: overlay.snackBar.controller,
          children: children,
        ),
      );
      overlay.entry.markNeedsBuild();
      _hideAutomatically(content.key!, content.duration);
      return;
    }
    final snackBar = _ZenithSnackBar(
      highlight: children.first,
      controller: _Controller(),
      children: children,
    );
    final entry = OverlayEntry(
      builder: (context) => ZenithSnackBarScope(
        controller: this,
        child: _overlay!.snackBar,
      ),
    );
    _overlay = _Entry(entry, snackBar);
    if (!context.mounted) {
      return;
    }
    Overlay.of(context).insert(entry);
    _hideAutomatically(content.key!, content.duration);
  }

  /// Remove the content according to the key.
  ///
  /// Dismiss the SnackBar if the content is last one.
  Future<void> remove(Key key) async {
    if (_removing?.isCompleted == false) {
      return;
    }
    _removing = Completer();
    await _hide(key);
    _removing?.complete();
  }

  void _hideAutomatically(Key key, Duration duration) {
    if (duration == Duration.zero) {
      return;
    }
    _timers[key]?.cancel();
    _timers[key] = Timer(duration, () {
      _hide(key);
    });
  }

  Future<void> _hide(Key key) async {
    final overlay = _overlay;
    if (overlay == null) {
      return;
    }
    final child = overlay.snackBar.children.where((e) => e.key != key).toList();
    if (child.isEmpty) {
      await dismiss();
      return;
    }
    _overlay = overlay.copyWith(
      snackBar: _ZenithSnackBar(
        highlight: child.first,
        controller: overlay.snackBar.controller,
        children: child,
      ),
    );
    overlay.entry.markNeedsBuild();
  }

  /// Dismiss the SnackBar.
  Future<void> dismiss() async {
    await _overlay?.snackBar.controller.hide();
    dispose();
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _overlay?.entry.remove();
    _overlay = null;
  }

  @override
  int get hashCode => _overlay.hashCode;

  @override
  bool operator ==(Object other) =>
      other is ZenithSnackBarController && other._overlay == _overlay;
}

/// The scope for SnackBars.
///
/// Typical usage is as follows:
///
/// ```dart
/// class _MyAppState extends State<MyApp> {
///   late ZenithSnackBarController controller;
///
///   @override
///   void initState() {
///     super.initState();
///     controller = ZenithSnackBarController();
///   }
///
///   @override
///   void dispose() {
///     controller.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       home: ZenithSnackBarScope(
///         controller: controller,
///         child: Home(),
///       ),
///     );
///   }
/// }
/// ```
class ZenithSnackBarScope extends InheritedWidget {
  const ZenithSnackBarScope({
    super.key,
    required super.child,
    required this.controller,
  });

  final ZenithSnackBarController controller;

  static ZenithSnackBarController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ZenithSnackBarScope>()!
        .controller;
  }

  @override
  bool updateShouldNotify(covariant ZenithSnackBarScope oldWidget) {
    return oldWidget.controller != controller;
  }
}

/// The mixin for the SnackBar content.
mixin ZenithSnackBarTileMixin on Widget {
  /// Priority of the content.
  ///
  /// The smaller the value, the higher the priority.
  int get priority;

  /// Display duration.
  ///
  /// The content is never hidden if this is [Duration.zero].
  Duration get duration;
}

/// The content for the SnackBar.
class ZenithSnackBarTile extends StatefulWidget with ZenithSnackBarTileMixin {
  const ZenithSnackBarTile({
    required Key key,
    required this.child,
    required this.priority,
    this.duration = Duration.zero,
    this.dismissible = true,
    this.padding = const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
  }) : super(key: key);

  final Widget child;
  final EdgeInsets padding;
  @override
  final int priority;
  @override
  final Duration duration;
  final bool dismissible;

  @override
  State<ZenithSnackBarTile> createState() => _ZenithSnackBarTileState();
}

class _ZenithSnackBarTileState extends State<ZenithSnackBarTile>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    animation.forward();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (widget.dismissible) {
      child = Dismissible(
        key: ValueKey(widget.child),
        onDismissed: (_) {
          ZenithSnackBarScope.of(context).remove(widget.key!);
        },
        direction: DismissDirection.horizontal,
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      );
    } else {
      child = Padding(
        padding: widget.padding,
        child: widget.child,
      );
    }
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeInCirc)),
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.fastEaseInToSlowEaseOut)),
        ),
        child: child,
      ),
    );
  }
}

class _ZenithSnackBar extends StatefulWidget {
  const _ZenithSnackBar({
    required this.highlight,
    required this.children,
    required this.controller,
  });

  final ZenithSnackBarTileMixin highlight;
  final List<ZenithSnackBarTileMixin> children;
  final _Controller controller;

  @override
  State<_ZenithSnackBar> createState() => _ZenithSnackBarState();
}

class _ZenithSnackBarState extends State<_ZenithSnackBar>
    with TickerProviderStateMixin
    implements _Listener {
  late AnimationController animation =
      SnackBar.createAnimationController(vsync: this);

  @override
  Future<void> onHide() async {
    try {
      await animation.reverse().orCancel;
    } on TickerCanceled {
      // do nothing
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(this);
    animation.forward();
  }

  @override
  void dispose() {
    widget.controller.removeListener(this);
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heightAnimation =
        CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn);
    final fadeInAnimation =
        CurvedAnimation(parent: animation, curve: const Interval(0.4, 1));
    final child = FadeTransition(
      opacity: fadeInAnimation,
      child: AnimatedBuilder(
        animation: heightAnimation,
        builder: (context, child) => Align(
          alignment: AlignmentDirectional.bottomCenter,
          heightFactor: heightAnimation.value,
          child: child,
        ),
        child: SafeArea(
          child: Material(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ),
        ),
      ),
    );
    return Positioned(
      top: 16,
      left: 32,
      right: 32,
      child: Semantics(
        onDismiss: () {
          ZenithSnackBarScope.of(context).dismiss();
        },
        child: Dismissible(
          direction: DismissDirection.vertical,
          onDismissed: (_) {
            ZenithSnackBarScope.of(context).dismiss();
          },
          key: const Key('dismissible'),
          child: child,
        ),
      ),
    );
  }
}

abstract class _Listener {
  Future<void> onHide();
}

class _Controller {
  final List<_Listener> list = [];

  Future<void> hide() async {
    final list = List.of(this.list);
    for (var value in list) {
      await value.onHide();
    }
  }

  void addListener(_Listener listener) {
    list.add(listener);
  }

  void removeListener(_Listener listener) {
    list.remove(listener);
  }
}

class _Entry {
  _Entry(this.entry, this.snackBar);

  final OverlayEntry entry;
  final _ZenithSnackBar snackBar;

  _Entry copyWith({
    OverlayEntry? entry,
    _ZenithSnackBar? snackBar,
  }) {
    return _Entry(entry ?? this.entry, snackBar ?? this.snackBar);
  }
}
