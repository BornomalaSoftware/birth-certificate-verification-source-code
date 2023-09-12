import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:nid/firebase_options.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nid/screens/browser.dart';
import 'package:nid/admanager.dart';
import 'package:nid/screens/no_internet.dart';

// Start :: AppOpenAd ----------------------------------------------------------

Future<void> showAppOpenAd() async {
  await AppOpenAd.load(
    adUnitId: AdManager.appOpenAdUnitId,
    orientation: AppOpenAd.orientationPortrait,
    request: const AdRequest(),
    adLoadCallback: AppOpenAdLoadCallback(onAdLoaded: (ad) {
      ad.show();
      FirebaseAnalytics.instance.logEvent(
        name: 'app_open_ad_loaded_and_shown',
        parameters: {
          "full_text": "App Open Ad Loaded And Shown",
        },
      );
    }, onAdFailedToLoad: (error) {
      FirebaseAnalytics.instance.logEvent(
        name: 'app_open_ad_failed_to_load',
        parameters: {
          "full_text": "App Open Ad Failed To Load",
        },
      );
    }),
  );
}

// End :: AppOpenAd ------------------------------------------------------------

// Start :: Connectivity -------------------------------------------------------
bool isConnected = false;

Future<void> checkConnection() async {
  final connectivityResult = Connectivity().checkConnectivity();
  if (await connectivityResult == ConnectivityResult.mobile ||
      await connectivityResult == ConnectivityResult.wifi ||
      await connectivityResult == ConnectivityResult.ethernet) {
    isConnected = true;
  }
}
// End :: Connectivity ---------------------------------------------------------

// Start :: Main ---------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await checkConnection();
  await showAppOpenAd();

  FirebaseAnalytics.instance.logScreenView(
    screenName: 'Root',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BR Verifier',
      debugShowCheckedModeBanner: false,
      navigatorObservers: <NavigatorObserver>[observer],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 1, 49, 122)),
        useMaterial3: true,
      ),
      home: isConnected
          ? const Browser(
              url: 'https://everify.bdris.gov.bd',
            )
          : const NoInternetConnection(),
    );
  }
}
// End :: Main -----------------------------------------------------------------
