import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'body_viewer.dart';

/// Renders `assets/body_viewer/index.html` in a WebView. Assets are served
/// through Android's WebViewAssetLoader so the page can fetch `body.glb`.
class WebBodyViewerController implements BodyViewerController {
  static const _domain = 'appassets.androidplatform.net';
  static const _url =
      'https://$_domain/assets/flutter_assets/assets/body_viewer/index.html';

  final _events = StreamController<BodyViewerEvent>.broadcast();
  InAppWebViewController? _web;

  @override
  Stream<BodyViewerEvent> get events => _events.stream;

  void _emit(BodyViewerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Widget buildView() => InAppWebView(
    initialUrlRequest: URLRequest(url: WebUri(_url)),
    initialSettings: InAppWebViewSettings(
      transparentBackground: true,
      isInspectable: kDebugMode,
      supportZoom: false,
      disableContextMenu: true,
      webViewAssetLoader: WebViewAssetLoader(
        domain: _domain,
        pathHandlers: [AssetsPathHandler(path: '/assets/')],
      ),
    ),
    gestureRecognizers: {
      Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
    },
    onWebViewCreated: (controller) {
      _web = controller;
      controller.addJavaScriptHandler(
        handlerName: 'viewer',
        callback: (args) {
          final event = parseViewerMessage(args.isEmpty ? null : args.first);
          if (event != null) _emit(event);
          return null;
        },
      );
    },
    onReceivedError: (controller, request, error) {
      if (request.isForMainFrame ?? true) {
        _emit(ViewerFailed(error.description));
      }
    },
  );

  Future<void> _call(String function, [Object? arg]) async {
    final args = arg == null ? '' : jsonEncode(arg);
    await _web?.evaluateJavascript(
      source: 'window.viewer && window.viewer.$function($args);',
    );
  }

  @override
  Future<void> select(String muscleId) => _call('select', muscleId);

  @override
  Future<void> highlight({
    required List<String> primary,
    required List<String> secondary,
  }) => _call('highlight', {'primary': primary, 'secondary': secondary});

  @override
  Future<void> clear() => _call('clear');

  @override
  Future<void> setView(BodyView view) => _call('setView', view.name);

  @override
  Future<void> resetView() => _call('resetView');

  @override
  Future<void> reload() async => _web?.reload();

  @override
  void dispose() => _events.close();
}
