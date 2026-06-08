import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class WebViewPage extends StatefulWidget {
  final String title;
  final String homeUrl;
  final String storageKey;

  const WebViewPage({
    super.key,
    required this.title,
    required this.homeUrl,
    required this.storageKey,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage>
    with WidgetsBindingObserver {
  late final WebViewController _controller;

  static const String jshoxHome = 'https://jshox.com';
  static const String deweyHome = 'https://local.dewey.in';
  static const String defaultKey = 'default_home';
  static const String userAgentKey = 'user_agent_mode';

  double _progress = 0;
  double _lastScrollY = 0;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isOnline = true;
  bool _isMobileUserAgent = true;
  bool _isLoadingCached = false;

  late String _defaultHome;
  late String _currentUrl;

  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';
  static const String desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _monitorConnectivity();
  }

  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      if (_isOnline != isOnline) {
        setState(() => _isOnline = isOnline);
        if (isOnline && _hasError) {
          _retry();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateTheme();
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    _defaultHome = prefs.getString(defaultKey) ?? jshoxHome;
    _currentUrl = prefs.getString(widget.storageKey) ?? _defaultHome;
    _isMobileUserAgent = prefs.getBool(userAgentKey) ?? true;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(_isMobileUserAgent ? mobileUserAgent : desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.navigate,
          onPageStarted: (_) {
            setState(() => _hasError = false);
          },
          onWebResourceError: (error) {
            setState(() {
              _hasError = true;
              _errorMessage = error.description;
            });
          },
          onPageFinished: (url) async {
            final prefs = await SharedPreferences.getInstance();
            prefs.setString(widget.storageKey, url);
            _currentUrl = url;
            _updateTheme();
            setState(() => _isLoadingCached = false);
          },
          onProgress: (p) => setState(() => _progress = p / 100),
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  Future<void> _loadUrlWithCache(String url) async {
    // Only cache jshox.com, always load local.dewey.in fresh
    final shouldCache = url.contains('jshox.com');

    if (shouldCache) {
      try {
        final file = await DefaultCacheManager().getSingleFile(url);
        if (file.existsSync()) {
          setState(() => _isLoadingCached = true);
          _controller.loadRequest(Uri.parse(url));
          return;
        }
      } catch (e) {
        // Cache miss, load normally
      }
    }

    // Load without cache (for local.dewey.in or cache miss)
    _controller.loadRequest(Uri.parse(url));
  }

  void _updateTheme() {
    final isDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    _controller.runJavaScript('''
      (function() {
        if (document.getElementById('ios-safe-area')) {
          document.getElementById('ios-safe-area').remove();
        }
        const style = document.createElement('style');
        style.id = 'ios-safe-area';
        style.innerHTML = `
          body {
            padding-top: env(safe-area-inset-top);
          }
          html {
            color-scheme: ${isDark ? 'dark' : 'light'};
          }
        `;
        document.head.appendChild(style);
      })();
    ''');

    _updateStatusBar();
  }

  void _updateStatusBar() {
    final isDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  void _handleScroll(double y) {
    if ((y - _lastScrollY).abs() < 8) return;
    _lastScrollY = y;
  }

  void _haptic() {
    HapticFeedback.mediumImpact();
  }

  void _goHome() {
    _haptic();
    _loadUrlWithCache(jshoxHome);
  }

  void _openSite(String url) {
    _haptic();
    _loadUrlWithCache(url);
  }

  Future<void> _setDefault(String url) async {
    _haptic();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _defaultHome = url);
    prefs.setString(defaultKey, url);
  }

  Future<void> _goBack() async {
    _haptic();
    if (await _controller.canGoBack()) {
      _controller.goBack();
    }
  }

  Future<void> _goForward() async {
    _haptic();
    if (await _controller.canGoForward()) {
      _controller.goForward();
    }
  }

  void _retry() {
    _haptic();
    setState(() => _hasError = false);
    _controller.reload();
  }

  Future<void> _share() async {
    _haptic();
    await Share.share(
      _currentUrl,
      subject: 'Check this out',
    );
  }

  Future<void> _toggleUserAgent() async {
    _haptic();
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isMobileUserAgent = !_isMobileUserAgent);
    prefs.setBool(userAgentKey, _isMobileUserAgent);

    _controller.setUserAgent(
      _isMobileUserAgent ? mobileUserAgent : desktopUserAgent,
    );

    _controller.reload();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isMobileUserAgent ? '📱 Switched to Mobile View' : '🖥️ Switched to Desktop View',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleDoubleTap() {
    _haptic();
    _controller.runJavaScript('''
      (function() {
        const currentZoom = window.visualViewport.scale;
        const newZoom = currentZoom === 1 ? 1.5 : 1;
        document.documentElement.style.zoom = newZoom;
      })();
    ''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _progress < 1 && !_hasError
                ? LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_isLoadingCached)
            Container(
              height: 2,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
          Expanded(
            child: _hasError
                ? _buildErrorScreen()
                : GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity == null) return;

                      if (details.primaryVelocity! > 300) {
                        _goBack();
                      } else if (details.primaryVelocity! < -300) {
                        _goForward();
                      }
                    },
                    onDoubleTap: _handleDoubleTap,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.axis == Axis.vertical) {
                          _handleScroll(n.metrics.pixels);
                        }
                        return false;
                      },
                      child: ScrollConfiguration(
                        behavior: const _NoGlowScrollBehavior(),
                        child: RefreshIndicator(
                          onRefresh: () => _controller.reload(),
                          child: WebViewWidget(controller: _controller),
                        ),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withOpacity(0.85),
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(0.25),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        onPressed: _goBack,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: _goForward,
                      ),
                      IconButton(
                        icon: const Icon(Icons.home),
                        onPressed: _goHome,
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (value) {
                          if (value == 'open_jshox') _openSite(jshoxHome);
                          if (value == 'open_dewey') _openSite(deweyHome);
                          if (value == 'default_jshox') _setDefault(jshoxHome);
                          if (value == 'default_dewey') _setDefault(deweyHome);
                          if (value == 'share') _share();
                          if (value == 'toggle_ua') _toggleUserAgent();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'open_jshox',
                            child: Text('JSHOX'),
                          ),
                          const PopupMenuItem(
                            value: 'open_dewey',
                            child: Text('Local.Dewey'),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'default_jshox',
                            child: Row(
                              children: [
                                const Text('Set default: JSHOX'),
                                if (_defaultHome == jshoxHome)
                                  const Spacer(),
                                if (_defaultHome == jshoxHome)
                                  const Icon(Icons.check, size: 16),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'default_dewey',
                            child: Row(
                              children: [
                                const Text('Set default: Local.Dewey'),
                                if (_defaultHome == deweyHome)
                                  const Spacer(),
                                if (_defaultHome == deweyHome)
                                  const Icon(Icons.check, size: 16),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                const Icon(Icons.share, size: 18),
                                const SizedBox(width: 12),
                                const Text('Share'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_ua',
                            child: Row(
                              children: [
                                Icon(
                                  _isMobileUserAgent ? Icons.smartphone : Icons.desktop_mac,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isMobileUserAgent ? 'Desktop View' : 'Mobile View',
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error.withOpacity(0.6),
              ),
              const SizedBox(height: 24),
              Text(
                _isOnline ? 'Page Failed to Load' : 'No Connection',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _isOnline
                    ? 'There was a problem loading this page'
                    : 'Check your internet connection',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _goHome,
                icon: const Icon(Icons.home),
                label: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Disables iOS overscroll glow (prevents flashes)
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
