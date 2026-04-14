import 'package:flutter/material.dart';

import '../services/long_screenshot_service.dart';

class LongScreenshotScrollCapture extends StatefulWidget {
  const LongScreenshotScrollCapture({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<LongScreenshotScrollCapture> createState() =>
      _LongScreenshotScrollCaptureState();
}

class _LongScreenshotScrollCaptureState
    extends State<LongScreenshotScrollCapture> {
  final GlobalKey _boundaryKey = GlobalKey();
  late final String _id = LongScreenshotService.instance.nextId();

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(LongScreenshotScrollCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _register();
    }
  }

  @override
  void dispose() {
    LongScreenshotService.instance.unregister(_id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _boundaryKey, child: widget.child);
  }

  void _register() {
    LongScreenshotService.instance.register(
      id: _id,
      controller: widget.controller,
      boundaryKey: _boundaryKey,
      isOffstage: () => _isOffstage(context),
    );
  }

  bool _isOffstage(BuildContext context) {
    var offstage = false;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) {
        offstage = true;
        return false;
      }
      return true;
    });
    return offstage;
  }
}
