// lib/core/localization_helpers.dart

import 'package:flutter/material.dart';
import 'package:maouidi/flutter_flow/flutter_flow_util.dart';

// Helper to translate appointment status
String getLocalizedStatus(BuildContext context, String status) {
  final statusMap = {
    'Pending': FFLocalizations.of(context).getText('status_pending'),
    'Confirmed': FFLocalizations.of(context).getText('status_confirmed'),
    'Completed': FFLocalizations.of(context).getText('status_completed'),
    'Cancelled_ByUser':
        FFLocalizations.of(context).getText('status_cancelled_by_user'),
    'Cancelled_ByPartner':
        FFLocalizations.of(context).getText('status_cancelled_by_partner'),
    'NoShow': FFLocalizations.of(context).getText('status_no_show'),
    'Rescheduled': FFLocalizations.of(context).getText('status_rescheduled'),
  };
  return statusMap[status] ??
      status; // Fallback to the original string if not found
}

// Helper to translate medical specialties
String getLocalizedSpecialty(BuildContext context, String specialty) {
  // We'll generate a key from the specialty name
  final key =
      'specialty_${specialty.replaceAll(' ', '_').replaceAll('/', '').replaceAll('-', '_').toLowerCase()}';
  final translated = FFLocalizations.of(context).getText(key);

  // If a translation for the key doesn't exist, return the original specialty name
  return translated.isEmpty ? specialty : translated;
}
