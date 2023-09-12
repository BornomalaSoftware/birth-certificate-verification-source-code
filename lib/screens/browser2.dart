// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nid/screens/about.dart';
import 'package:nid/screens/browser.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:nid/admanager.dart';

class UDRNBrowser extends StatefulWidget {
  const UDRNBrowser(
      {Key? key, required this.url, this.analytics, this.observer})
      : super(key: key);

  final String url;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;

  @override
  State<UDRNBrowser> createState() => _UDRNBrowserState();
}

class _UDRNBrowserState extends State<UDRNBrowser>
    with TickerProviderStateMixin {
  late final WebViewController _controller;

  // Start :: BannerAd ---------------------------------------------------------

  BannerAd? _bannerAd;

  void loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _bannerAd = ad as BannerAd?;
          });
          widget.analytics!.logEvent(
            name: "UDRNBrowser_banner_ad_loaded",
            parameters: {
              "full_text": "UDRNBrowser's Banner Ad Loaded",
            },
          );
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          widget.analytics!.logEvent(
            name: "UDRNBrowser_banner_ad_failed_to_load",
            parameters: {
              "full_text": "UDRNBrowser's Banner Ad Failed To Load",
            },
          );
          ad.dispose();
        },
        onAdOpened: (Ad ad) {
          widget.analytics!.logEvent(
            name: "UDRNBrowser_banner_ad_opened",
            parameters: {
              "full_text": "UDRNBrowser's Banner Ad Opened",
            },
          );
        },
        onAdClosed: (Ad ad) {
          widget.analytics!.logEvent(
            name: "UDRNBrowser_banner_ad_closed",
            parameters: {
              "full_text": "UDRNBrowser's Banner Ad Closed",
            },
          );
        },
      ),
    );
    _bannerAd!.load();
  }
  // End :: BannerAd -----------------------------------------------------------

  // Start :: InterstitialAd ---------------------------------------------------
  void showInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdManager.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.show();
          widget.analytics!.logEvent(
            name: "browser_interstitialad_loaded_and_shown",
            parameters: {
              "full_text": "Browser's InterstitialAd Loaded And Shown",
            },
          );
        },
        onAdFailedToLoad: (err) {
          widget.analytics!.logEvent(
            name: "browser_interstitialad_failed_to_load",
            parameters: {
              "full_text": "Browser's InterstitialAd Failed To Load",
            },
          );
        },
      ),
    );
  }
  // End :: InterstitialAd -----------------------------------------------------

  // Declare :: ProgressController ---------------------------------------------
  late AnimationController progressController;
  bool determinate = false;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: 'UDRNBrowserPage',
    );

    loadBannerAd();
    // showInterstitialAd();

    // Start :: ProgressController ----------------------------
    progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(() {
        setState(() {});
      });
    progressController.repeat();
    // End :: ProgressController ------------------------------

    // Start :: WebViewController -----------------------------
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            _cleanUI();
            progressController.value = progress / 100;
            if (progress == 100) {
              progressController.stop();
            }
          },
          onPageStarted: (String url) {
            progressController.value = 0;
          },
          onPageFinished: (String url) {
            progressController.value = 0;
          },
          onWebResourceError: (WebResourceError error) {
            SnackBar(
                content: const Text('Something went wrong!'),
                backgroundColor: Colors.black54,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)));
          },

          // Handle Requests
          onNavigationRequest: (NavigationRequest request) async {
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            // debugPrint('url change to ${change.url}');
            FirebaseAnalytics.instance.logEvent(
              name: "UDRNBrowser_url_change",
              parameters: {
                "full_text": "Url change to ${change.url}",
              },
            );
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message.message),
                backgroundColor: Colors.black54,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          );
        },
      )
      ..loadRequest(Uri.parse(widget.url));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    // End :: WebViewController -------------------------------
  }

  // Start :: RemoveHeader&Footer ----------------------------------------------
  Future<void> _cleanUI() async {
    await _controller.runJavaScript(
        "javascript:(function() {document.getElementsByClassName('container')[0].style.display='none'; document.getElementsByClassName('container body-content')[0].style.padding='20px'; document.getElementsByTagName('p')[1].style.display='none'; document.getElementsByTagName('p')[3].style.display='none'; document.getElementsByTagName('img')[1].style.marginLeft='25px'; document.getElementsByTagName('footer')[0].style.display='none'; document.getElementsByTagName('hr')[0].style.display='none'; document.getElementsByTagName('hr')[1].style.display='none'; document.getElementsByTagName('h3')[0].style.display='none'; document.getElementsByTagName('form')[0].style.padding='20px'; document.getElementsByClassName('text-info')[0].style.display='none'; document.getElementsByClassName('form-control')[0].style.height='40px'; document.getElementsByClassName('form-control')[0].style.maxWidth='100%'; document.getElementsByClassName('form-control')[0].style.border='0'; document.getElementsByClassName('datepicker')[0].style.minWidth='100%'; document.getElementsByClassName('datepicker')[0].style.height='40px'; document.getElementsByClassName('datepicker')[0].style.border='0'; document.getElementsByClassName('form-group')[2].style.border='1px dotted gray'; document.getElementsByClassName('form-group')[2].style.padding='0px'; document.getElementsByClassName('form-group')[2].style.display='grid'; document.getElementsByClassName('form-group')[2].style.justifyContent='center'; document.getElementsByClassName('form-group')[2].style.align='center'; document.getElementById('CaptchaInputText').style.height='40px'; document.getElementById('CaptchaInputText').style.minWidth='100%'; document.getElementById('CaptchaInputText').style.border='0'; document.getElementsByClassName('btn-primary')[0].style.height='40px'; document.getElementsByClassName('btn-primary')[0].style.minWidth='100%'; document.getElementsByClassName('btn-primary')[1].style.display='none'; })()");
  }
  // End :: RemoveHeader&Footer ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const Icon(Icons.verified_rounded, color: Colors.black45),
          title: const Text('BDRN Verification',
              style: TextStyle(color: Colors.black45, fontSize: 15)),
          actions: <Widget>[
            IconButton(
                icon:
                    const Icon(Icons.clear_all_rounded, color: Colors.black45),
                onPressed: () {
                  showInterstitialAd();
                  _controller.clearCache();
                  const snackBar = SnackBar(
                    content: Center(child: Text('Clear Form')),
                    // action: SnackBarAction(
                    //   label: 'Undo',
                    //   onPressed: () {
                    //     // Some code to undo the change.
                    //   },
                    // ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UDRNBrowser(
                                url:
                                    'https://everify.bdris.gov.bd/UDRNVerification',
                              )));
                }),
            IconButton(
                onPressed: () {
                  showInterstitialAd();
                  const snackBar = SnackBar(
                    content:
                        Center(child: Text('Birth Certificate Verification')),
                    // action: SnackBarAction(
                    //   label: 'Undo',
                    //   onPressed: () {
                    //     // Some code to undo the change.
                    //   },
                    // ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const Browser(
                              url: "https://everify.bdris.gov.bd")));
                },
                icon: const Icon(
                  Icons.swap_vert_circle_outlined,
                  color: Colors.black45,
                )),
            IconButton(
                icon: const Icon(Icons.info_outline_rounded,
                    color: Colors.black45),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const About()));
                }),
          ],
        ),
        body: Column(
          children: [
            // Start :: LinearProgressIndicator ----------------------------
            LinearProgressIndicator(
              value: progressController.value,
            ),
            // End :: LinearProgressIndicator ------------------------------

            // Start :: WebView --------------------------------------------
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
            // End :: WebView ----------------------------------------------

            const LinearProgressIndicator(
              value: 0,
            ),
            
            // Start :: BannerAd -------------------------------------------
            if (_bannerAd != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
              )
            // End :: BannerAd ----------------------------------------------
          ],
        ),
      ),
    );
  }
}
