// lib/flutter_flow/internationalization.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleStorageKey = '__locale_key__';

class FFLocalizations {
  FFLocalizations(this.locale);

  final Locale locale;

  static FFLocalizations of(BuildContext context) =>
      Localizations.of<FFLocalizations>(context, FFLocalizations)!;

  static List<String> languages() => ['en', 'ar', 'fr'];

  static late SharedPreferences _prefs;
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();
  static Future storeLocale(String locale) =>
      _prefs.setString(_kLocaleStorageKey, locale);
  static Locale? getStoredLocale() {
    final locale = _prefs.getString(_kLocaleStorageKey);
    return locale != null && locale.isNotEmpty ? createLocale(locale) : null;
  }

  String get languageCode => locale.toString();
  String? get languageShortCode =>
      _languagesWithShortCode.contains(locale.toString())
          ? '${locale.toString()}_short'
          : null;
  int get languageIndex => languages().contains(languageCode)
      ? languages().indexOf(languageCode)
      : 0;

  String getText(String key) =>
      (kTranslationsMap[key] ?? {})[locale.toString()] ?? '';

  String getVariableText({
    String? enText = '',
    String? arText = '',
    String? frText = '',
  }) =>
      [enText, arText, frText][languageIndex] ?? '';

  static const Set<String> _languagesWithShortCode = {
    'ar',
    'az',
    'ca',
    'cs',
    'da',
    'de',
    'dv',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'gr',
    'he',
    'hi',
    'hu',
    'it',
    'km',
    'ku',
    'mn',
    'ms',
    'no',
    'pt',
    'ro',
    'ru',
    'rw',
    'sv',
    'th',
    'uk',
    'vi',
  };
}

class FFLocalizationsDelegate extends LocalizationsDelegate<FFLocalizations> {
  const FFLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final language = locale.toString();
    return FFLocalizations.languages().contains(
      language.endsWith('_')
          ? language.substring(0, language.length - 1)
          : language,
    );
  }

  @override
  Future<FFLocalizations> load(Locale locale) =>
      SynchronousFuture<FFLocalizations>(FFLocalizations(locale));

  @override
  bool shouldReload(FFLocalizationsDelegate old) => false;
}

Locale createLocale(String language) => language.contains('_')
    ? Locale.fromSubtags(
        languageCode: language.split('_').first,
        scriptCode: language.split('_').last,
      )
    : Locale(language);

// YOUR TRANSLATION MAP GOES HERE
// (Use the complete map I provided in the previous step)

final kTranslationsMap = <Map<String, Map<String, String>>>[
  // WelcomeScreen & Auth
  {
    'zuf2lagf': {'en': 'Welcome!', 'ar': 'مرحباً!', 'fr': 'Bienvenue !'},
    '2qjevbjl': {
      'en':
          'Thanks for joining! Access or create your account below, and get started on your journey!',
      'ar': 'شكرًا لانضمامك! سجّل دخولك أو أنشئ حسابك أدناه، وابدأ رحلتك!',
      'fr':
          'Merci de nous rejoindre ! Accédez ou créez votre compte ci-dessous et commencez votre parcours !'
    },
    '68x5i214': {'en': 'Sign Up', 'ar': 'إنشاء حساب', 'fr': 'S\'inscrire'},
    'oerhp1hv': {'en': 'Log In', 'ar': 'تسجيل الدخول', 'fr': 'Se connecter'},
    'za064viu': {
      'en': 'Welcome to Maouidi',
      'ar': 'مرحباً بكم في موعدي!',
      'fr': 'Bienvenue sur Maouidi'
    },
    'bw1u9riq': {
      'en': 'Use the account below to sign in.',
      'ar': 'استخدم الحساب أدناه لتسجيل الدخول.',
      'fr': 'Utilisez le compte ci-dessous pour vous connecter.'
    },
    'uhtykqxj': {
      'en': 'Forgot Password?',
      'ar': 'هل نسيت كلمة السر؟',
      'fr': 'Mot de passe oublié ?'
    },
    'amfoac12': {
      'en': 'We will send you a reset link.',
      'ar': 'سوف نرسل لك رابط إعادة الضبط.',
      'fr': 'Nous vous enverrons un lien de réinitialisation.'
    },
    '73m8o8df': {
      'en': 'Send Link',
      'ar': 'إرسال الرابط',
      'fr': 'Envoyer le lien'
    },
    'hr7g0yzr': {
      'en': 'Create Account',
      'ar': 'إنشاء حساب',
      'fr': 'Créer un compte'
    },
    'a308pr0q': {
      'en': 'Enter your email here...',
      'ar': 'أدخل بريدك الإلكتروني هنا...',
      'fr': 'Entrez votre email ici...'
    },
    '849zhxnf': {'en': 'First Name', 'ar': 'الاسم الأول', 'fr': 'Prénom'},
    'nzslchkp': {
      'en': 'Last Name',
      'ar': 'اسم العائلة',
      'fr': 'Nom de famille'
    },
    'mwny79n8': {
      'en': 'Email Address',
      'ar': 'عنوان البريد الإلكتروني',
      'fr': 'Adresse e-mail'
    },
    'rfkbeomw': {'en': 'Password', 'ar': 'كلمة المرور', 'fr': 'Mot de passe'},
    'o1s0s1ma': {
      'en': 'Confirm Password',
      'ar': 'تأكيد كلمة المرور',
      'fr': 'Confirmez le mot de passe'
    },
    'elr6im80': {'en': 'Sign In', 'ar': 'تسجيل الدخول', 'fr': 'Se connecter'},
    'j50kiywl': {'en': 'Sign In', 'ar': 'تسجيل الدخول', 'fr': 'Se connecter'},
    '0simneyn': {
      'en': 'Forgot Password',
      'ar': 'هل نسيت كلمة السر؟',
      'fr': 'Mot de passe oublié'
    },
  },
  // Home Page & Search
  {
    'zwhxx1yq': {
      'en': 'Search by name...',
      'ar': 'البحث بالاسم...',
      'fr': 'Rechercher par nom...'
    },
    't7w8u2b4': {'en': 'Doctors', 'ar': 'أطباء', 'fr': 'Médecins'},
    'fvarzh30': {'en': 'Clinics', 'ar': 'عيادات', 'fr': 'Cliniques'},
    'vzmuomic': {
      'en': 'Homecare',
      'ar': 'رعاية منزلية',
      'fr': 'Soins à domicile'
    },
    '22avau5o': {
      'en': 'Charities',
      'ar': 'جمعيات خيرية',
      'fr': 'Organismes de bienfaisance'
    },
    'sh600y77': {
      'en': 'Featured Partners',
      'ar': 'الشركاء المميزون',
      'fr': 'Partenaires en vedette'
    },
    'wdwcwjyw': {'en': 'Maouidi', 'ar': 'موعدي', 'fr': 'Maouidi'},
    'srchptr': {
      'en': 'Search Partners',
      'ar': 'ابحث عن شركاء',
      'fr': 'Rechercher des partenaires'
    },
    'refinesrch': {
      'en': 'Refine your search...',
      'ar': 'حدد بحثك...',
      'fr': 'Affinez votre recherche...'
    },
    'noresults': {
      'en': 'No Results Found',
      'ar': 'لم يتم العثور على نتائج',
      'fr': 'Aucun résultat trouvé'
    },
    'noresultsmsg': {
      'en': 'We couldn\'t find any partners matching your search.',
      'ar': 'لم نتمكن من العثور على أي شركاء يطابقون بحثك.',
      'fr':
          'Nous n\'avons trouvé aucun partenaire correspondant à votre recherche.'
    },
  },
  // Partner Pages
  {
    'ptrlist': {'en': 'Partners', 'ar': 'الشركاء', 'fr': 'Partenaires'},
    'fltrstate': {
      'en': 'Filter by State',
      'ar': 'التصفية حسب الولاية',
      'fr': 'Filtrer par État'
    },
    'allstates': {
      'en': 'All States',
      'ar': 'كل الولايات',
      'fr': 'Tous les États'
    },
    'fltrspecialty': {
      'en': 'Filter by Specialty',
      'ar': 'التصفية حسب التخصص',
      'fr': 'Filtrer par Spécialité'
    },
    'allspecialties': {
      'en': 'All Specialties',
      'ar': 'كل التخصصات',
      'fr': 'Toutes les spécialités'
    },
    'clrfltrs': {
      'en': 'Clear Filters',
      'ar': 'مسح الفلاتر',
      'fr': 'Effacer les filtres'
    },
    'nopartners': {
      'en': 'No partners found matching your criteria.',
      'ar': 'لم يتم العثور على شركاء يطابقون معاييرك.',
      'fr': 'Aucun partenaire ne correspond à vos critères.'
    },
    'unnamedptr': {
      'en': 'Unnamed Partner',
      'ar': 'شريك بدون اسم',
      'fr': 'Partenaire sans nom'
    },
    'nospecialty': {
      'en': 'No Specialty',
      'ar': 'بدون تخصص',
      'fr': 'Pas de spécialité'
    },
    'notavail': {'en': 'N/A', 'ar': 'غير متاح', 'fr': 'N/D'},
    'booknow': {
      'en': 'Book Now',
      'ar': 'احجز الآن',
      'fr': 'Réserver maintenant'
    },
    'ptrerr': {'en': 'Error', 'ar': 'خطأ', 'fr': 'Erreur'},
    'ptridmissing': {
      'en': 'Partner ID is missing or invalid.',
      'ar': 'معرف الشريك مفقود أو غير صالح.',
      'fr': 'L\'ID du partenaire est manquant ou invalide.'
    },
    'savechgs': {
      'en': 'Save Changes',
      'ar': 'حفظ التغييرات',
      'fr': 'Sauvegarder'
    },
    'editprof': {
      'en': 'Edit Profile',
      'ar': 'تعديل الملف الشخصي',
      'fr': 'Modifier le profil'
    },
    'fullname': {'en': 'Full Name', 'ar': 'الاسم الكامل', 'fr': 'Nom complet'},
    'specialty': {'en': 'Specialty', 'ar': 'التخصص', 'fr': 'Spécialité'},
    'reviews': {'en': 'Reviews', 'ar': 'التقييمات', 'fr': 'Avis'},
    'bookappt': {
      'en': 'Book Appointment',
      'ar': 'حجز موعد',
      'fr': 'Prendre rendez-vous'
    },
    'viewloc': {
      'en': 'View Location on Map',
      'ar': 'عرض الموقع على الخريطة',
      'fr': 'Voir sur la carte'
    },
    'aboutptr': {'en': 'About', 'ar': 'حول', 'fr': 'À propos de'},
    'ptrreviews': {
      'en': 'Patient Reviews',
      'ar': 'تقييمات المرضى',
      'fr': 'Avis des patients'
    },
    'noreviews': {
      'en': 'No reviews yet.',
      'ar': 'لا توجد تقييمات بعد.',
      'fr': 'Aucun avis pour le moment.'
    },
    'ourdocs': {'en': 'Our Doctors', 'ar': 'أطباؤنا', 'fr': 'Nos médecins'},
    'nodocs': {
      'en': 'No doctors listed for this clinic yet.',
      'ar': 'لا يوجد أطباء مدرجون لهذه العيادة بعد.',
      'fr': 'Aucun médecin n\'est encore répertorié pour cette clinique.'
    },
  },
  // Booking Flow
  {
    'bookapptbar': {
      'en': 'Book an Appointment',
      'ar': 'حجز موعد',
      'fr': 'Prendre un rendez-vous'
    },
    'ptrnotconfig': {
      'en': 'This partner is not configured for bookings.',
      'ar': 'هذا الشريك غير مهيأ للحجوزات.',
      'fr': 'Ce partenaire n\'est pas configuré pour les réservations.'
    },
    'getnumberfor': {
      'en': 'Get a Number for',
      'ar': 'احصل على رقم لـ',
      'fr': 'Obtenir un numéro pour'
    },
    'requestvisit': {
      'en': 'Request a Visit for',
      'ar': 'اطلب زيارة لـ',
      'fr': 'Demander une visite pour'
    },
    'atpartner': {'en': 'at', 'ar': 'عند', 'fr': 'chez'},
    'closeddate': {
      'en': 'This partner is closed on the selected date.',
      'ar': 'هذا الشريك مغلق في التاريخ المحدد.',
      'fr': 'Ce partenaire est fermé à la date sélectionnée.'
    },
    'notworkingday': {
      'en': 'This partner does not work on the selected day.',
      'ar': 'هذا الشريك لا يعمل في اليوم المحدد.',
      'fr': 'Ce partenaire ne travaille pas le jour sélectionné.'
    },
    'submitting': {
      'en': 'Submitting...',
      'ar': 'جاري الإرسال...',
      'fr': 'Envoi en cours...'
    },
    'bookforpatient': {
      'en': 'Book for Patient',
      'ar': 'حجز لمريض',
      'fr': 'Réserver pour un patient'
    },
    'submithcreq': {
      'en': 'Submit Homecare Request',
      'ar': 'إرسال طلب رعاية منزلية',
      'fr': 'Soumettre la demande de soins'
    },
    'getmynum': {
      'en': 'Get My Number',
      'ar': 'احصل على رقمي',
      'fr': 'Obtenir mon numéro'
    },
    'loadslotserr': {
      'en': 'Could not load time slots',
      'ar': 'تعذر تحميل الفترات الزمنية',
      'fr': 'Impossible de charger les créneaux'
    },
    'noslots': {
      'en': 'No available slots for this day.',
      'ar': 'لا توجد فترات متاحة لهذا اليوم.',
      'fr': 'Aucun créneau disponible pour ce jour.'
    },
    'hcdetails': {
      'en': 'Homecare Details',
      'ar': 'تفاصيل الرعاية المنزلية',
      'fr': 'Détails des soins à domicile'
    },
    'casedesc': {
      'en': 'Brief Case Description',
      'ar': 'وصف مختصر للحالة',
      'fr': 'Brève description du cas'
    },
    'casedescex': {
      'en': 'e.g., Blood pressure check for elderly patient...',
      'ar': 'مثال: فحص ضغط الدم لمريض مسن...',
      'fr': 'Ex: Vérification de la tension pour un patient âgé...'
    },
    'fulladdr': {
      'en': 'Your Full Address',
      'ar': 'عنوانك الكامل',
      'fr': 'Votre adresse complète'
    },
    'fulladdrex': {
      'en': 'Your full address for the home visit...',
      'ar': 'عنوانك الكامل للزيارة المنزلية...',
      'fr': 'Votre adresse complète pour la visite...'
    },
    'fieldreq': {
      'en': 'This field is required.',
      'ar': 'هذا الحقل مطلوب.',
      'fr': 'Ce champ est requis.'
    },
    'submitreq': {
      'en': 'Submit Request',
      'ar': 'إرسال الطلب',
      'fr': 'Envoyer la demande'
    },
    'cancel': {'en': 'Cancel', 'ar': 'إلغاء', 'fr': 'Annuler'},
    'reqsent': {
      'en': 'Request sent! Waiting for confirmation.',
      'ar': 'تم إرسال الطلب! في انتظار التأكيد.',
      'fr': 'Demande envoyée ! En attente de confirmation.'
    },
    'gotnum': {
      'en': 'Successfully got a number!',
      'ar': 'تم الحصول على رقم بنجاح!',
      'fr': 'Numéro obtenu avec succès !'
    },
    'alrdyappt': {
      'en': 'You already have an appointment for this day.',
      'ar': 'لديك بالفعل موعد في هذا اليوم.',
      'fr': 'Vous avez déjà un rendez-vous pour ce jour.'
    },
    'slottaken': {
      'en': 'This slot may have just been taken. Please try another.',
      'ar': 'ربما تم حجز هذه الفترة للتو. يرجى محاولة فترة أخرى.',
      'fr':
          'Ce créneau vient peut-être d\'être pris. Veuillez en essayer un autre.'
    },
  },
  // Dashboards
  {
    'myapts': {
      'en': 'My Appointments',
      'ar': 'مواعيدي',
      'fr': 'Mes rendez-vous'
    },
    'upcoming': {'en': 'UPCOMING', 'ar': 'القادمة', 'fr': 'À VENIR'},
    'completed': {'en': 'COMPLETED', 'ar': 'المكتملة', 'fr': 'TERMINÉS'},
    'canceled': {'en': 'CANCELED', 'ar': 'الملغاة', 'fr': 'ANNULÉS'},
    'noapts': {
      'en': 'No Appointments',
      'ar': 'لا توجد مواعيد',
      'fr': 'Aucun rendez-vous'
    },
    'noaptsmsg': {
      'en': 'You don\'t have any appointments in this category yet.',
      'ar': 'ليس لديك أي مواعيد في هذه الفئة بعد.',
      'fr': 'Vous n\'avez aucun rendez-vous dans cette catégorie.'
    },
    'yournum': {'en': 'Your Number:', 'ar': 'رقمك:', 'fr': 'Votre numéro :'},
    'lvrvw': {
      'en': 'Leave a Review',
      'ar': 'اترك تقييمًا',
      'fr': 'Laisser un avis'
    },
    'cnclapt': {
      'en': 'Cancel Appointment',
      'ar': 'إلغاء الموعد',
      'fr': 'Annuler le rendez-vous'
    },
    'cnclaptq': {
      'en': 'Cancel Appointment?',
      'ar': 'هل تريد إلغاء الموعد؟',
      'fr': 'Annuler le rendez-vous ?'
    },
    'cnclaptsure': {
      'en': 'Are you sure you want to cancel your appointment with',
      'ar': 'هل أنت متأكد من أنك تريد إلغاء موعدك مع',
      'fr': 'Êtes-vous sûr de vouloir annuler votre rendez-vous avec'
    },
    'back': {'en': 'Back', 'ar': 'رجوع', 'fr': 'Retour'},
    'cnclconfirm': {
      'en': 'Confirm Cancellation',
      'ar': 'تأكيد الإلغاء',
      'fr': 'Confirmer l\'annulation'
    },
    'aptcnld': {
      'en': 'Appointment canceled successfully.',
      'ar': 'تم إلغاء الموعد بنجاح.',
      'fr': 'Rendez-vous annulé avec succès.'
    },
    'cnclfail': {
      'en': 'Failed to cancel',
      'ar': 'فشل الإلغاء',
      'fr': 'Échec de l\'annulation'
    },
    'ratevisit': {
      'en': 'Rate your visit with',
      'ar': 'قيّم زيارتك مع',
      'fr': 'Évaluez votre visite avec'
    },
    'commentsopt': {
      'en': 'Your comments (optional)',
      'ar': 'تعليقاتك (اختياري)',
      'fr': 'Vos commentaires (facultatif)'
    },
    'commentshint': {
      'en': 'Tell us more about your experience...',
      'ar': 'أخبرنا المزيد عن تجربتك...',
      'fr': 'Dites-nous en plus sur votre expérience...'
    },
    'submitrev': {
      'en': 'Submit Review',
      'ar': 'إرسال التقييم',
      'fr': 'Envoyer l\'avis'
    },
    'submittingrev': {
      'en': 'Submitting...',
      'ar': 'جاري الإرسال...',
      'fr': 'Envoi en cours...'
    },
    'thankrev': {
      'en': 'Thank you for your review!',
      'ar': 'شكرًا لك على تقييمك!',
      'fr': 'Merci pour votre avis !'
    },
    'revfail': {
      'en': 'Submission failed',
      'ar': 'فشل الإرسال',
      'fr': 'Échec de l\'envoi'
    },
    'yourdash': {
      'en': 'Your Dashboard',
      'ar': 'لوحة التحكم الخاصة بك',
      'fr': 'Votre tableau de bord'
    },
    'loadptrfail': {
      'en': 'Could not load partner information.',
      'ar': 'تعذر تحميل معلومات الشريك.',
      'fr': 'Impossible de charger les informations du partenaire.'
    },
    'schedule': {'en': 'Schedule', 'ar': 'الجدول الزمني', 'fr': 'Planning'},
    'analytics': {'en': 'Analytics', 'ar': 'التحليلات', 'fr': 'Statistiques'},
    'allapts': {
      'en': 'All Appointments',
      'ar': 'كل المواعيد',
      'fr': 'Tous les RDV'
    },
    'clncanalytics': {
      'en': 'Clinic Analytics',
      'ar': 'تحليلات العيادة',
      'fr': 'Statistiques de la clinique'
    },
    'ptfullname': {
      'en': 'Patient\'s Full Name',
      'ar': 'اسم المريض الكامل',
      'fr': 'Nom complet du patient'
    },
    'ptphone': {
      'en': 'Patient\'s Phone',
      'ar': 'هاتف المريض',
      'fr': 'Téléphone du patient'
    },
    'apptcreated': {
      'en': 'Appointment created successfully!',
      'ar': 'تم إنشاء الموعد بنجاح!',
      'fr': 'Rendez-vous créé avec succès !'
    },
    'fltrdoc': {
      'en': 'Filter by Doctor',
      'ar': 'التصفية حسب الطبيب',
      'fr': 'Filtrer par médecin'
    },
    'alldocs': {
      'en': 'All Doctors',
      'ar': 'كل الأطباء',
      'fr': 'Tous les médecins'
    },
    'noaptsfound': {
      'en': 'No Appointments Found',
      'ar': 'لم يتم العثور على مواعيد',
      'fr': 'Aucun rendez-vous trouvé'
    },
    'noaptsfltr': {
      'en': 'There are no appointments matching your filter.',
      'ar': 'لا توجد مواعيد تطابق الفلتر الخاص بك.',
      'fr': 'Aucun rendez-vous ne correspond à votre filtre.'
    },
    'loadanalyticsfail': {
      'en': 'Could not load analytics.',
      'ar': 'تعذر تحميل التحليلات.',
      'fr': 'Impossible de charger les statistiques.'
    },
    'nowserving': {
      'en': 'Now Serving',
      'ar': 'يتم خدمة الآن',
      'fr': 'En consultation'
    },
    'upnext': {
      'en': 'Up Next in Queue',
      'ar': 'التالي في الطابور',
      'fr': 'Prochains dans la file'
    },
    'qready': {
      'en': 'The queue is ready.',
      'ar': 'الطابور جاهز.',
      'fr': 'La file d\'attente est prête.'
    },
    'callnext': {
      'en': 'Press "Call Next Patient" to begin.',
      'ar': 'اضغط على "استدعاء المريض التالي" للبدء.',
      'fr': 'Appuyez sur "Appeler le patient suivant" pour commencer.'
    },
    'callnextbtn': {
      'en': 'Call Next Patient',
      'ar': 'استدعاء المريض التالي',
      'fr': 'Appeler le patient suivant'
    },
    'noshow': {'en': 'No-Show', 'ar': 'لم يحضر', 'fr': 'Absent'},
    'markcomp': {
      'en': 'Mark as Completed',
      'ar': 'وضع علامة كمكتمل',
      'fr': 'Marquer comme terminé'
    },
  },
  // Settings & Profile
  {
    'settings': {'en': 'Settings', 'ar': 'الإعدادات', 'fr': 'Paramètres'},
    'yourprof': {
      'en': 'Your Profile',
      'ar': 'ملفك الشخصي',
      'fr': 'Votre profil'
    },
    'notifications': {
      'en': 'Notifications',
      'ar': 'الإشعارات',
      'fr': 'Notifications'
    },
    'pushnotif': {
      'en': 'Push Notifications',
      'ar': 'الإشعارات',
      'fr': 'Notifications Push'
    },
    'rcvalerts': {
      'en': 'Receive alerts for your appointments',
      'ar': 'استقبال تنبيهات لمواعيدك',
      'fr': 'Recevoir des alertes pour vos rendez-vous'
    },
    'general': {'en': 'General', 'ar': 'عام', 'fr': 'Général'},
    'language': {'en': 'Language', 'ar': 'اللغة', 'fr': 'Langue'},
    'darkmode': {'en': 'Dark Mode', 'ar': 'الوضع الداكن', 'fr': 'Mode sombre'},
    'contactus': {'en': 'Contact Us', 'ar': 'اتصل بنا', 'fr': 'Nous contacter'},
    'acctlegal': {
      'en': 'Account & Legal',
      'ar': 'الحساب والقانون',
      'fr': 'Compte et juridique'
    },
    'becomeptr': {
      'en': 'Become a Partner',
      'ar': 'كن شريكًا',
      'fr': 'Devenir partenaire'
    },
    'listservices': {
      'en': 'List your services on Maouidi',
      'ar': 'أدرج خدماتك في موعدي',
      'fr': 'Référencez vos services sur Maouidi'
    },
    'privpolicy': {
      'en': 'Privacy Policy',
      'ar': 'سياسة الخصوصية',
      'fr': 'Politique de confidentialité'
    },
    'termsserv': {
      'en': 'Terms of Service',
      'ar': 'شروط الخدمة',
      'fr': 'Conditions d\'utilisation'
    },
    'delacct': {
      'en': 'Delete Account',
      'ar': 'حذف الحساب',
      'fr': 'Supprimer le compte'
    },
    'logout': {'en': 'Log Out', 'ar': 'تسجيل الخروج', 'fr': 'Se déconnecter'},
    'saving': {
      'en': 'Saving...',
      'ar': 'جاري الحفظ...',
      'fr': 'Enregistrement...'
    },
    'saveall': {
      'en': 'Save All Settings',
      'ar': 'حفظ كل الإعدادات',
      'fr': 'Enregistrer tout'
    },
    'dob': {
      'en': 'Date of Birth',
      'ar': 'تاريخ الميلاد',
      'fr': 'Date de naissance'
    },
    'gender': {'en': 'Gender', 'ar': 'الجنس', 'fr': 'Genre'},
    'selectgender': {
      'en': 'Select Gender',
      'ar': 'اختر الجنس',
      'fr': 'Sélectionner le genre'
    },
    'male': {'en': 'Male', 'ar': 'ذكر', 'fr': 'Homme'},
    'female': {'en': 'Female', 'ar': 'أنثى', 'fr': 'Femme'},
    'phnumreq': {
      'en': 'Phone number is required.',
      'ar': 'رقم الهاتف مطلوب.',
      'fr': 'Le numéro de téléphone est requis.'
    },
    'phnumvalid': {
      'en': 'Must be a 10-digit number starting with 05, 06, or 07.',
      'ar': 'يجب أن يكون رقمًا مكونًا من 10 أرقام ويبدأ بـ 05 أو 06 أو 07.',
      'fr': 'Doit être un numéro à 10 chiffres commençant par 05, 06 ou 07.'
    },
    'selectstate': {
      'en': 'Select State',
      'ar': 'اختر الولاية',
      'fr': 'Sélectionner l\'État'
    },
    'prof saved': {
      'en': 'Profile saved successfully!',
      'ar': 'تم حفظ الملف الشخصي بنجاح!',
      'fr': 'Profil enregistré avec succès !'
    },
    'proferr': {
      'en': 'Error saving profile:',
      'ar': 'خطأ في حفظ الملف الشخصي:',
      'fr': 'Erreur lors de l\'enregistrement du profil :'
    },
  },
  {
    'i_agree_to': {
      'en': 'I agree to the ',
      'ar': 'أوافق على ',
      'fr': 'J\'accepte la '
    },
    'and': {'en': ' and ', 'ar': ' و ', 'fr': ' et les '},
    'dialog_close': {'en': 'Close', 'ar': 'إغلاق', 'fr': 'Fermer'},
    'privacy_policy_content': {
      'en': '''Last updated: September 13, 2025

Please replace this placeholder text with your own Privacy Policy.

1. Introduction
   Welcome to Maouidi. We are committed to protecting your personal information and your right to privacy...

2. Information We Collect
   We may collect personal information that you voluntarily provide to us when you register on the application...

3. How We Use Your Information
   We use personal information collected via our application for a variety of business purposes described below...

...''',
      'ar': '''آخر تحديث: 13 سبتمبر 2025

يرجى استبدال هذا النص بسياسة الخصوصية الخاصة بك.

1. مقدمة
   مرحبًا بك في موعدي. نحن ملتزمون بحماية معلوماتك الشخصية وحقك في الخصوصية...

2. المعلومات التي نجمعها
   قد نقوم بجمع معلومات شخصية تقدمها لنا طواعية عند التسجيل في التطبيق...

3. كيف نستخدم معلوماتك
   نستخدم المعلومات الشخصية التي تم جمعها عبر تطبيقنا لمجموعة متنوعة من أغراض العمل الموضحة أدناه...

...''',
      'fr': '''Dernière mise à jour : 13 septembre 2025

Veuillez remplacer ce texte par votre propre politique de confidentialité.

1. Introduction
   Bienvenue sur Maouidi. Nous nous engageons à protéger vos informations personnelles et votre droit à la vie privée...

2. Informations que nous collectons
   Nous pouvons collecter des informations personnelles que vous nous fournissez volontairement lorsque vous vous inscrivez sur l'application...

3. Comment nous utilisons vos informations
   Nous utilisons les informations personnelles collectées via notre application à diverses fins commerciales décrites ci-dessous...

...''',
    },
    'terms_of_service_content': {
      'en': '''Last updated: September 13, 2025

Please replace this placeholder text with your own Terms of Service.

1. Agreement to Terms
   By using our application, you agree to be bound by these Terms of Service...

2. User Accounts
   When you create an account with us, you must provide us with information that is accurate, complete, and current at all times...

3. Prohibited Uses
   You may use the application only for lawful purposes and in accordance with the Terms...

...''',
      'ar': '''آخر تحديث: 13 سبتمبر 2025

يرجى استبدال هذا النص بشروط الخدمة الخاصة بك.

1. الموافقة على الشروط
   باستخدام تطبيقنا، فإنك توافق على الالتزام بشروط الخدمة هذه...

2. حسابات المستخدمين
   عند إنشاء حساب معنا، يجب عليك تزويدنا بمعلومات دقيقة وكاملة وحديثة في جميع الأوقات...

3. الاستخدامات المحظورة
   يجوز لك استخدام التطبيق فقط للأغراض المشروعة ووفقًا للشروط...

...''',
      'fr': '''Dernière mise à jour : 13 septembre 2025

Veuillez remplacer ce texte par vos propres conditions d'utilisation.

1. Acceptation des conditions
   En utilisant notre application, vous acceptez d'être lié par ces conditions d'utilisation...

2. Comptes d'utilisateurs
   Lorsque vous créez un compte chez nous, vous devez nous fournir des informations exactes, complètes et à jour en tout temps...

3. Utilisations interdites
   Vous ne pouvez utiliser l'application qu'à des fins légales et conformément aux conditions...

...''',
    },
  },
  {
    'payment_emergency_warning': {
      'en':
          'Note: This service is not for emergencies. If your case is critical, please contact the nearest emergency service to your location.',
      'ar':
          'ملاحظة: هذه الخدمة ليست للحالات الطارئة. إذا كانت حالتك حرجة، يرجى الاتصال بأقرب خدمة طوارئ لموقعك.',
      'fr':
          'Remarque : Ce service n\'est pas destiné aux urgences. Si votre cas est critique, veuillez contacter le service d\'urgence le plus proche.'
    }
  },
// Make sure this reduce function is at the end
].reduce((a, b) => a..addAll(b));
