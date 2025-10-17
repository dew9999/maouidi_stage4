// lib/partner_dashboard_page/components/dashboard_helpers.dart

import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';

// Helper function to consistently get patient display info
(String, String) getPatientDisplayInfo(Map<String, dynamic> appointmentData) {
  final onBehalfOfName =
      appointmentData['on_behalf_of_patient_name'] as String?;
  final onBehalfOfPhone =
      appointmentData['on_behalf_of_patient_phone'] as String?;

  final patientFirstName = appointmentData['patient_first_name'] as String?;
  final patientLastName = appointmentData['patient_last_name'] as String?;
  final patientPhone = appointmentData['patient_phone'] as String?;

  final bookingUserName =
      ('${patientFirstName ?? ''} ${patientLastName ?? ''}').trim();

  // Use 'on behalf of' info first for manually added patients.
  final displayName = onBehalfOfName ??
      (bookingUserName.isNotEmpty ? bookingUserName : 'A Patient');
  final displayPhone = onBehalfOfPhone ?? patientPhone ?? 'No phone provided';

  return (displayName, displayPhone);
}

// This function shows a styled confirmation dialog
Future<bool> showStyledConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmText,
}) async {
  final theme = FlutterFlowTheme.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: theme.secondaryBackground,
      title: Text(title, style: theme.titleLarge),
      content: Text(content, style: theme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Cancel', style: TextStyle(color: theme.secondaryText)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.error,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

// Reusable function for user-friendly error messages
void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: FlutterFlowTheme.of(context).error,
  ));
}
