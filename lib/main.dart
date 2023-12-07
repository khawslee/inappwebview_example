import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _WebViewFormState createState() => _WebViewFormState();
}

class _WebViewFormState extends State<MyHomePage> {
  final GlobalKey webViewKey = GlobalKey();

  double _progress = 0;
  int pressCount = 0;
  Timer? resetTimer;

  late InAppWebViewController webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));
  late PullToRefreshController pullToRefreshController;

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController.reload();
        } else if (Platform.isIOS) {
          webViewController.loadUrl(
              urlRequest: URLRequest(url: await webViewController.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await webViewController.canGoBack()) {
          webViewController.goBack();
          return false;
        }
        // press one time show toast message, press two time exit the app
        pressCount++;
        if (pressCount == 1) {
          // Show toast message
          showToast('Press one more time to exit');

          // Start the reset timer
          resetTimer?.cancel(); // Cancel any existing timer
          resetTimer = Timer(const Duration(seconds: 2), () {
            pressCount = 0; // Reset the pressCount after 2 seconds
          });
          return false;
        } else if (pressCount == 2) {
          // Exit the app
          return true;
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text("In App Webview Flutter example"),
            centerTitle: true),
        body: SafeArea(
          child: Center(
            child: Stack(
              children: [
                InAppWebView(
                  key: webViewKey,
                  initialUrlRequest:
                      URLRequest(url: Uri.parse("https://flutter.dev/")),
                  initialOptions: options,
                  pullToRefreshController: pullToRefreshController,
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  androidOnPermissionRequest:
                      (controller, origin, resources) async {
                    return PermissionRequestResponse(
                        resources: resources,
                        action: PermissionRequestResponseAction.GRANT);
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    var uri = navigationAction.request.url!;

                    if (![
                      "http",
                      "https",
                      "file",
                      "chrome",
                      "data",
                      "javascript",
                      "about"
                    ].contains(uri.scheme)) {
                      // if (await canLaunch(url)) {
                      //   // Launch the App
                      //   await launch(
                      //     url,
                      //   );
                      //   // and cancel the request
                      //   return NavigationActionPolicy.CANCEL;
                      // }
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadError: (controller, url, code, message) {
                    pullToRefreshController.endRefreshing();
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      pullToRefreshController.endRefreshing();
                    }
                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    print(consoleMessage);
                  },
                ),
                _progress < 1.0
                    ? LinearProgressIndicator(value: _progress)
                    : Container(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showToast(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s),
    ));
  }
}
