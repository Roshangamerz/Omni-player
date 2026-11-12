import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  final AppTheme theme;
  final bool isTerms;

  const PrivacyScreen({super.key, required this.theme, this.isTerms = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textPrimary,
        title: Text(
          isTerms ? 'Terms of Use' : 'Privacy Policy',
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: isTerms ? _buildTerms(theme) : _buildPrivacy(theme),
      ),
    );
  }

  Widget _buildPrivacy(AppTheme t) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Privacy Policy', t),
      _body('Last updated: August 2025', t, isSmall: true),
      const SizedBox(height: 20),
      _heading('What We Collect', t),
      _body(
        'Omni Music does not collect, store, or transmit any personal data to our servers. '
        'All data (liked songs, playlists, settings, themes) is stored locally on your device using Android\'s SharedPreferences.',
        t,
      ),
      _heading('Music Repositories', t),
      _body(
        'Omni Music is a music player framework. It does not host or distribute any music content. '
        'All music content is accessed via third-party repository URLs that YOU choose to add. '
        'We are not responsible for the content, legality, or availability of any user-added repository.',
        t,
      ),
      _heading('Network Access', t),
      _body(
        'The app uses the internet only to:\n'
        '• Fetch track listings from repositories you have manually added\n'
        '• Stream audio from URLs provided by those repositories\n'
        '• Load artwork images from repository-provided URLs\n\n'
        'No data is sent to Omni Music servers (there are none).',
        t,
      ),
      _heading('Third-Party Services', t),
      _body(
        'Repository providers you connect to may have their own privacy policies. '
        'Please review the privacy policy of any repository you add.',
        t,
      ),
      _heading('Contact', t),
      _body('For privacy questions, contact us via the app store listing.', t),
    ],
  );

  Widget _buildTerms(AppTheme t) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Terms of Use', t),
      _body('Last updated: August 2025', t, isSmall: true),
      const SizedBox(height: 20),
      _heading('1. Acceptance', t),
      _body('By using Omni Music, you agree to these terms.', t),
      _heading('2. The App', t),
      _body(
        'Omni Music is a music player application that plays audio from user-provided repository URLs. '
        'The app itself contains no music and does not host any copyrighted content.',
        t,
      ),
      _heading('3. Your Responsibility', t),
      _body(
        'You are solely responsible for:\n'
        '• The repository links you choose to add\n'
        '• Ensuring you have the right to access content from those repositories\n'
        '• Complying with the terms of any repository service you connect\n\n'
        'Do not add repositories that distribute copyrighted content without authorization.',
        t,
      ),
      _heading('4. No Warranty', t),
      _body(
        'The app is provided "as is" without warranty. We are not responsible for content accessed through user-added repositories.',
        t,
      ),
      _heading('5. Changes', t),
      _body('We may update these terms. Continued use constitutes acceptance.', t),
    ],
  );

  Widget _heading(String text, AppTheme t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text,
        style: TextStyle(
            color: t.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
  );

  Widget _body(String text, AppTheme t, {bool isSmall = false}) => Text(
    text,
    style: TextStyle(
      color: t.textSecondary,
      fontSize: isSmall ? 12 : 14,
      height: 1.7,
    ),
  );
}
