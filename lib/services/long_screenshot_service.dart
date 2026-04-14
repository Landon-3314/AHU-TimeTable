import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class LongScreenshotService {
  LongScreenshotService._();

  static final LongScreenshotService instance = LongScreenshotService._();
  static const MethodChannel _channel = MethodChannel('app.scroll_capture');

  final Map<String, _RegisteredScrollable> _scrollables =
      <String, _RegisteredScrollable>{};
  final Map<String, double> _savedOffsets = <String, double>{};

  bool _initialized = false;
  int _nextId = 0;

  void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  String nextId() => 'scrollable_${_nextId++}';

  void register({
    required String id,
    required ScrollController controller,
    required GlobalKey boundaryKey,
    required bool Function() isOffstage,
  }) {
    _scrollables[id] = _RegisteredScrollable(
      id: id,
      controller: controller,
      boundaryKey: boundaryKey,
      isOffstage: isOffstage,
    );
  }

  void unregister(String id) {
    _scrollables.remove(id);
    _savedOffsets.remove(id);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'describeScrollables':
        return _describeScrollables();
      case 'prepareCapture':
        return _prepareCapture(arguments);
      case 'scrollTo':
        return _scrollTo(arguments);
      case 'restoreCapture':
        return _restoreCapture(arguments);
      default:
        throw MissingPluginException('Unhandled method: ${call.method}');
    }
  }

  List<Map<String, Object>> _describeScrollables() {
    final descriptions = <Map<String, Object>>[];
    for (final entry in _scrollables.values) {
      final description = entry.describe();
      if (description != null) {
        descriptions.add(description);
      }
    }
    return descriptions;
  }

  Future<bool> _prepareCapture(Object? arguments) async {
    final entry = _resolveEntry(arguments);
    if (entry == null) {
      return false;
    }

    _rememberOffset(entry);
    return true;
  }

  Future<Map<String, Object?>> _scrollTo(Object? arguments) async {
    final offset = _readOffset(arguments);
    final entry = _resolveEntry(arguments);
    if (entry == null || offset == null) {
      return <String, Object?>{'ok': false};
    }

    _rememberOffset(entry);
    await _jumpTo(entry, offset);

    return <String, Object?>{
      'ok': true,
      'pixels': entry.currentPixels,
      'maxScrollExtent': entry.maxScrollExtent,
      'viewportDimension': entry.viewportDimension,
    };
  }

  Future<bool> _restoreCapture(Object? arguments) async {
    final entry = _resolveEntry(arguments);
    if (entry == null) {
      return false;
    }

    final savedOffset = _savedOffsets.remove(entry.id);
    if (savedOffset == null) {
      return false;
    }

    await _jumpTo(entry, savedOffset);
    return true;
  }

  String? _readId(Object? arguments) {
    if (arguments is! Map<Object?, Object?>) {
      return null;
    }
    return arguments['id'] as String?;
  }

  double? _readOffset(Object? arguments) {
    if (arguments is! Map<Object?, Object?>) {
      return null;
    }
    final value = arguments['offset'];
    return value is num ? value.toDouble() : null;
  }

  _RegisteredScrollable? _resolveEntry(Object? arguments) {
    final id = _readId(arguments);
    final entry = id == null ? null : _scrollables[id];
    if (entry == null || !entry.hasActivePosition) {
      return null;
    }
    return entry;
  }

  void _rememberOffset(_RegisteredScrollable entry) {
    _savedOffsets.putIfAbsent(entry.id, () => entry.currentPixels);
  }

  Future<void> _jumpTo(_RegisteredScrollable entry, double offset) async {
    final target = offset.clamp(0.0, entry.maxScrollExtent).toDouble();
    if ((entry.currentPixels - target).abs() <= 0.5) {
      return;
    }

    entry.controller.jumpTo(target);
    await _waitForRenderedFrame();
  }

  Future<void> _waitForRenderedFrame() async {
    await Future<void>.delayed(Duration.zero);
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }
}

class _RegisteredScrollable {
  const _RegisteredScrollable({
    required this.id,
    required this.controller,
    required this.boundaryKey,
    required this.isOffstage,
  });

  final String id;
  final ScrollController controller;
  final GlobalKey boundaryKey;
  final bool Function() isOffstage;

  bool get hasActivePosition => controller.hasClients && !isOffstage();

  double get currentPixels => controller.position.pixels;

  double get maxScrollExtent => controller.position.maxScrollExtent;

  double get viewportDimension => controller.position.viewportDimension;

  Map<String, Object>? describe() {
    if (!controller.hasClients || isOffstage()) {
      return null;
    }

    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }

    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (rect.width <= 0 || rect.height <= 0) {
      return null;
    }

    final position = controller.position;
    if (axisDirectionToAxis(position.axisDirection) != Axis.vertical) {
      return null;
    }

    return <String, Object>{
      'id': id,
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
      'pixels': position.pixels,
      'maxScrollExtent': position.maxScrollExtent,
      'viewportDimension': position.viewportDimension,
    };
  }
}
