import 'package:flutter/material.dart';

class TermsOfService extends StatefulWidget {
  final bool isDialog;
  final VoidCallback? onAccept;

  const TermsOfService({
    Key? key,
    this.isDialog = false,
    this.onAccept,
  }) : super(key: key);

  @override
  State<TermsOfService> createState() => _TermsOfServiceState();
}

class _TermsOfServiceState extends State<TermsOfService> {
  final Color primaryColor = const Color(0xFF0E6B6F);
  final Color backgroundColor = Colors.white;


  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return _buildContent(context);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: primaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildPageContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/icon/eco_splash.png',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Terms of Service & Privacy Policy',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Last Updated: ${DateTime.now().toString().split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            _buildContent(context),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'By using our application, you agree to these terms and conditions.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (widget.onAccept != null) {
                          widget.onAccept!();
                        }
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Accept Terms & Conditions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: '1. Data Collection',
          content:
              'We collect personal information necessary to provide our services, including name, contact details, and location. Your information is used solely for service delivery and improving user experience. You can review and update your information at any time through your account settings.',
          icon: Icons.data_usage,
          context: context,
        ),
        _buildSection(
          title: '2. Collection Schedules',
          content:
              'Our waste collection schedules follow segregation protocols. Users must adhere to the designated collection days for different waste types. Non-compliance may result in penalties according to local regulations. Schedule notifications are provided as a courtesy and may occasionally be subject to change.',
          icon: Icons.schedule,
          context: context,
        ),
        _buildSection(
          title: '3. Communication Policies',
          content:
              'We send essential service notifications only. You will not receive marketing communications without explicit consent. You can adjust notification preferences in settings. We commit to not sharing your contact information with third parties for marketing purposes.',
          icon: Icons.email_outlined,
          context: context,
        ),
        _buildSection(
          title: '4. User Conduct & Abuse Prevention',
          content:
              'Users must not abuse the platform, submit false reports, or engage in harassment. Points or rewards may be revoked for violation of these terms. Multiple violations may result in account suspension. We reserve the right to report illegal activities to appropriate authorities.',
          icon: Icons.security,
          context: context,
        ),
        _buildSection(
          title: '5. Data Security & Privacy',
          content:
              'We implement industry-standard security measures to protect your data. Information is stored securely and accessed only by authorized personnel. We do not sell your personal data to third parties. In case of data breach, we will notify affected users promptly as required by law.',
          icon: Icons.lock_outline,
          context: context,
        ),
        _buildSection(
          title: '6. Modifications to Terms',
          content:
              'We reserve the right to modify these terms with reasonable notice. Continued use of the service after changes constitutes acceptance of updated terms. Major changes will be communicated through the app and/or email.',
          icon: Icons.update,
          context: context,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            backgroundColor: backgroundColor,
            collapsedBackgroundColor: backgroundColor,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor, size: 20),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: primaryColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
