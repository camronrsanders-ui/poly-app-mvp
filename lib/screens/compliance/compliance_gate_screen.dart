import 'package:flutter/material.dart';

import '../../config/compliance_policy.dart';
import '../../services/age_assurance_service.dart';
import '../../services/compliance_service.dart';

class ComplianceGateScreen extends StatefulWidget {
  const ComplianceGateScreen({
    super.key,
    required this.uid,
    required this.onSignOut,
  });

  final String uid;
  final Future<void> Function() onSignOut;

  @override
  State<ComplianceGateScreen> createState() => _ComplianceGateScreenState();
}

class _ComplianceGateScreenState extends State<ComplianceGateScreen> {
  final _ageAssurance = AgeAssuranceService();
  final _compliance = ComplianceService();

  DateTime? _birthDate;
  bool _acceptTerms = false;
  bool _acceptGuidelines = false;
  bool _busy = false;
  bool _blocked = false;
  String? _message;

  Future<void> _chooseBirthDate() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 25, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? initial,
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: now,
      helpText: 'Confirm your date of birth',
    );
    if (selected != null && mounted) {
      setState(() {
        _birthDate = selected;
        _message = null;
        _blocked = false;
      });
    }
  }

  Future<void> _continue() async {
    if (_busy) return;
    final birthDate = _birthDate;
    if (birthDate == null) {
      setState(() => _message = 'Choose your date of birth to continue.');
      return;
    }
    final age = ageOnDate(birthDate, DateTime.now());
    if (age < polycircleMinimumAge) {
      setState(() {
        _blocked = true;
        _message = 'Polycircle is only available to adults age 18 and older.';
      });
      return;
    }
    if (!_acceptTerms || !_acceptGuidelines) {
      setState(() {
        _message =
            'You must accept both the Terms of Use and Community Guidelines before creating or sharing content.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final signal = await _ageAssurance.requestAdultSignal();
      if (!mounted) return;

      if (signal.confirmsMinor) {
        setState(() {
          _busy = false;
          _blocked = true;
          _message =
              'Your device or app-store age signal indicates that this account is under 18, so Polycircle access is blocked.';
        });
        return;
      }

      if (signal.decision == AgeAssuranceDecision.verificationRequired) {
        setState(() {
          _busy = false;
          _message =
              'Your app store requires age verification before Polycircle can continue. Complete the age-verification step in your app-store account, then try again.';
        });
        return;
      }

      // In a regulated region, do not downgrade a required platform check to a
      // self-attested fallback merely because sharing failed or was declined.
      if (signal.regulatedRegion && !signal.confirmsAdult) {
        setState(() {
          _busy = false;
          _message =
              'Age assurance is required for this account or region. Complete the device age-sharing/verification step, then try again.';
        });
        return;
      }

      final method = signal.confirmsAdult
          ? signal.method
          : 'self_attested_dob_fallback';
      final statusParts = <String>[
        signal.decision.name,
        if (signal.platformStatus != null) signal.platformStatus!,
      ];
      final signalStatus = statusParts.join(':');

      await _compliance.recordAdultPolicyAcceptance(
        uid: widget.uid,
        ageAssuranceMethod: method,
        ageSignalStatus: signalStatus,
      );
      // The parent session gate watches the account document. Once the policy
      // fields are recorded it automatically advances to onboarding/app shell.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'We could not save your age and policy confirmation. Nothing was stored from your date of birth. Please try again.';
      });
    }
  }

  String _formattedBirthDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adult access & community rules'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () async => widget.onSignOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              _blocked ? Icons.no_accounts_outlined : Icons.verified_user_outlined,
              size: 58,
            ),
            const SizedBox(height: 14),
            Text(
              _blocked ? 'Adult-only access' : 'Before you enter Polycircle',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Polycircle is an 18+ dating and relationship community. We use your date of birth to check adult eligibility, but we do not save the exact date of birth to your Polycircle account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Date of birth'),
                subtitle: Text(
                  _birthDate == null
                      ? 'Required for the 18+ check'
                      : _formattedBirthDate(_birthDate!),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _chooseBirthDate,
              ),
            ),
            const SizedBox(height: 14),
            const Card(
              child: ExpansionTile(
                leading: Icon(Icons.gavel_outlined),
                title: Text('Terms of Use — pre-release summary'),
                childrenPadding: EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  Text(
                    'You must be 18 or older and provide truthful account information. You are responsible for content you post or send. Do not use Polycircle for illegal activity, exploitation, impersonation, scams, harassment, threats, hate, stalking, non-consensual sexual content, or content involving minors. Polycircle may review reports, restrict features, remove content, suspend accounts, preserve evidence when appropriate, and cooperate with lawful safety obligations. Blocking and reporting tools are available, but Polycircle is not an emergency service. Public release remains subject to final legal Terms and Privacy Policy review.',
                  ),
                ],
              ),
            ),
            const Card(
              child: ExpansionTile(
                leading: Icon(Icons.groups_outlined),
                title: Text('Community Guidelines'),
                childrenPadding: EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  Text(
                    'Consent is required. A match is not consent to sexual messages, intimate media, meeting, or continued contact. No harassment, hate, threats, coercion, scams, impersonation, doxxing, exploitation, or sexual content involving minors. Respect blocks and ended connections. Report concerning users or content so the moderation process can review it.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _acceptTerms,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _acceptTerms = value == true),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I am 18+ and accept the Terms of Use'),
              subtitle: const Text('Policy version $currentTermsVersion'),
            ),
            CheckboxListTile(
              value: _acceptGuidelines,
              onChanged: _busy
                  ? null
                  : (value) =>
                      setState(() => _acceptGuidelines = value == true),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I accept the Community Guidelines'),
              subtitle: const Text(
                  'Policy version $currentCommunityGuidelinesVersion'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _blocked ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy || _blocked ? null : _continue,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(_busy ? 'Checking…' : 'Verify & continue'),
            ),
            if (_blocked) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () async => widget.onSignOut(),
                child: const Text('Return to sign in'),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Platform age signals are privacy-preserving age ranges when supported. A fallback self-attestation may be used only where the platform does not require age sharing. Store-level minor restrictions and final legal/policy review remain separate release requirements.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
