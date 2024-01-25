import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:karla/core/router/router.dart';
import 'package:karla/core/services/snackbar_service.dart';
import 'package:karla/core/utils/extensions/log.dart';
import 'package:karla/models/user/user.dart';
import 'package:karla/views/auth/signup/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';

class UniLinksService {
  static String _promoId = '';
  static String get promoId => _promoId;
  static bool get hasPromoId => _promoId.isNotEmpty;

  static void reset() => _promoId = '';

  static Future<void> init({checkActualVersion = false}) async {
    //  APP is not running and the user clicks on a link.
    try {
      final Uri? uri = await getInitialUri();

      if (uri != null && uri.path == '/reward/') {
        _uniLinkHandler(uri: uri);
      } else {
        initUniLinks();
      }
    } on PlatformException {
      if (kDebugMode) {
        print("(PlatformException) Failed to receive initial uri.");
      }
    } on FormatException catch (error) {
      if (kDebugMode) {
        print(
            "(FormatException) Malformed Initial URI received. Error: $error");
      }
    }

    // APP is already running and the user clicks on a link.
    uriLinkStream.listen((Uri? uri) async {
      if (uri != null) {
        uri.log();
        uri.path.log();
        if (uri.path == '/reward/') {
          _uniLinkHandler(uri: uri);
        } else {
          initUniLinks();
        }
      }
    }, onError: (error) {
      if (kDebugMode) print('UniLinks onUriLink error: $error');
    });
  }

  static Future<void> _uniLinkHandler({required Uri? uri}) async {
    if (uri == null || uri.queryParameters.isEmpty) return;
    Map<String, String> params = uri.queryParameters;

    String receivedPromoId = params['reward_id'] ?? '';
    if (receivedPromoId.isEmpty) return;
    _promoId = receivedPromoId;

    final myContext = router.routerDelegate.navigatorKey.currentContext;

    if (User.instance.accessToken.isEmpty) {
      myContext?.goNamed(
        SignupScreen.routeName,
        queryParams: {
          'referralCode': _promoId,
        },
      );
    } else {
      SnackBarService.showMessage(
          myContext!, 'You need to logout first to signup as new user');
    }
  }

  static void initUniLinks() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        getInitialLink().then((String? initialLink) {
          ('initial link $initialLink').log();
          handleLink(initialLink);
        });

        linkStream.listen((String? link) {
          handleLink(link);
        });
      } catch (e) {
        ('Error: $e').log();
      }
    });
  }

  static void handleLink(String? link) {
    if (link != null) {
      final match = RegExp(r"merchantId=(\d+)").firstMatch(link);
      if (match != null) {
        final merchantId = int.parse(match.group(1)!);
        saveMerchantIdToPrefs(merchantId);
      } else if (Uri.parse(link).path == '/reward/') {
        _uniLinkHandler(uri: Uri.parse(link));
      }
    }
  }

  static Future<void> saveMerchantIdToPrefs(int merchantId) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('merchantId', merchantId);
  }

  static Future<int?> getMerchantIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('merchantId');
  }
}
