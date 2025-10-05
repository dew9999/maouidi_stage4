// lib/flutter_flow/nav/nav.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../auth/base_auth_user_provider.dart';
import '../../flutter_flow/flutter_flow_util.dart';

// Import all pages
import '../../index.dart';
import '../../pages/privacy_policy_page.dart';
import '../../pages/terms_of_service_page.dart';
import '../../search/search_results_page.dart';
import '../../nav_bar_page.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  String? userRole;

  bool notifyOnAuthChange = true;

  bool get loading => showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser? newUser) {
    final shouldUpdate =
        user?.uid == null || newUser?.uid == null || user?.uid != newUser?.uid;
    initialUser ??= newUser;
    user = newUser;
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    updateNotifyOnAuthChange(true);
  }

  void updateUserRole(String? role) {
    userRole = role;
    notifyListeners();
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      errorBuilder: (context, state) => appStateNotifier.loggedIn
          ? const NavBarPage()
          : const WelcomeScreenWidget(),
      routes: [
        GoRoute(
          name: '_initialize',
          path: '/',
          builder: (context, state) {
            return appStateNotifier.loggedIn
                ? const NavBarPage()
                : const WelcomeScreenWidget();
          },
        ),
        GoRoute(
          name: 'WelcomeScreen',
          path: '/welcomeScreen',
          builder: (context, state) => const WelcomeScreenWidget(),
        ),
        GoRoute(
          name: 'Login',
          path: '/login',
          builder: (context, state) => const LoginWidget(),
        ),
        GoRoute(
          name: 'HomePage',
          path: '/homePage',
          builder: (context, state) =>
              const NavBarPage(initialPage: 'HomePage'),
        ),
        GoRoute(
          name: 'Create',
          path: '/create',
          builder: (context, state) => const CreateWidget(),
        ),
        GoRoute(
          name: 'ForgotPassword',
          path: '/forgotPassword',
          builder: (context, state) => const ForgotPasswordWidget(),
        ),
        GoRoute(
          name: 'user_profile',
          path: '/userProfile',
          builder: (context, state) => const UserProfileWidget(),
        ),
        GoRoute(
          name: 'PartnerListPage',
          path: '/partnerListPage',
          builder: (context, state) => PartnerListPageWidget(
            categoryName: state.uri.queryParameters['categoryName'],
          ),
        ),
        GoRoute(
          name: 'PartnerProfilePage',
          path: '/partnerProfilePage',
          builder: (context, state) => PartnerProfilePageWidget(
            partnerId: state.uri.queryParameters['partnerId'],
          ),
        ),
        GoRoute(
          name: 'BookingPage',
          path: '/bookingPage',
          builder: (context, state) => BookingPageWidget(
            partnerId: state.uri.queryParameters['partnerId']!,
            isPartnerBooking:
                state.uri.queryParameters['isPartnerBooking'] == 'true',
          ),
        ),
        GoRoute(
          name: 'PatientDashboard',
          path: '/patientDashboard',
          builder: (context, state) =>
              const NavBarPage(initialPage: 'PatientDashboard'),
        ),
        GoRoute(
          name: 'PartnerDashboardPage',
          path: '/partnerDashboardPage',
          builder: (context, state) => PartnerDashboardPageWidget(
            partnerId: state.uri.queryParameters['partnerId']!,
          ),
        ),
        GoRoute(
          name: 'SettingsPage',
          path: '/settingsPage',
          builder: (context, state) =>
              const NavBarPage(initialPage: 'SettingsPage'),
        ),
        GoRoute(
          name: 'PrivacyPolicyPage',
          path: '/privacyPolicy',
          builder: (context, state) => const PrivacyPolicyPage(),
        ),
        GoRoute(
          name: 'TermsOfServicePage',
          path: '/termsOfService',
          builder: (context, state) => const TermsOfServicePage(),
        ),
        GoRoute(
          name: 'SearchResultsPage',
          path: '/searchResults',
          builder: (context, state) => SearchResultsPage(
            searchTerm: state.uri.queryParameters['searchTerm']!,
          ),
        ),
      ],
      redirect: (context, state) {
        final appState = AppStateNotifier.instance;
        final loggedIn = appState.loggedIn;
        final path = state.uri.path;

        if (!loggedIn &&
            !['/welcomeScreen', '/login', '/create', '/forgotPassword']
                .contains(path)) {
          return '/welcomeScreen';
        }
        return null;
      },
    );
