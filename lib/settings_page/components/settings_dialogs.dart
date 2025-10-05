// lib/settings_page/components/settings_dialogs.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:maouidi/auth/supabase_auth/auth_util.dart';
import 'package:maouidi/flutter_flow/flutter_flow_theme.dart';
import 'package:maouidi/flutter_flow/flutter_flow_util.dart';
import 'package:maouidi/ui/welcome_screen/welcome_screen_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void showContactUsDialog(BuildContext context) {
  final theme = FlutterFlowTheme.of(context);
  final contactInfo = {
    'Email': 'Maouidi06@gmail.com',
    'Phone': '+213658846728',
    'Address':
        'Wilaya de Tebessa, Tebessa ville, devant la wilaya à côté de stade bestanji',
  };

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: theme.secondaryBackground,
      title: Text(FFLocalizations.of(context).getText('contactus'),
          style: theme.headlineSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContactRow(
            icon: Icons.email_outlined,
            text: contactInfo['Email']!,
            onTap: () => launchUrl(Uri.parse('mailto:${contactInfo['Email']}')),
          ),
          const SizedBox(height: 12),
          _ContactRow(
            icon: Icons.phone_outlined,
            text: contactInfo['Phone']!,
            onTap: () => launchUrl(Uri.parse('tel:${contactInfo['Phone']}')),
          ),
          const SizedBox(height: 12),
          _ContactRow(
            icon: Icons.location_on_outlined,
            text: contactInfo['Address']!,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('Close', style: TextStyle(color: theme.primaryText)),
        ),
      ],
    ),
  );
}

void showDeleteAccountDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(FFLocalizations.of(context).getText('delacct')),
      content: const Text(
          'Are you sure? This action is permanent and cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(FFLocalizations.of(context).getText('cancel')),
        ),
        TextButton(
          onPressed: () async {
            try {
              await Supabase.instance.client.rpc('delete_user_account');
              if (context.mounted) {
                await authManager.signOut();
                context.go(WelcomeScreenWidget.routePath);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error deleting account: ${e.toString()}'),
                      backgroundColor: Colors.red),
                );
              }
            }
          },
          child: Text(FFLocalizations.of(context).getText('delacct'),
              style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FlutterFlowTheme.of(context).primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: SelectableText(text,
                  style: FlutterFlowTheme.of(context).bodyMedium)),
        ],
      ),
    );
  }
}
