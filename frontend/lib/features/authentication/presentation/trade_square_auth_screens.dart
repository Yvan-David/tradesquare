import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/trade_square_auth_models.dart';
import 'trade_square_auth_widgets.dart';

class TradeSquareLoginScreen extends StatefulWidget {
  const TradeSquareLoginScreen({
    required this.locale,
    required this.onLocaleChanged,
    required this.onRegister,
    required this.onSubmit,
    required this.onForgotPassword,
    this.errorMessage,
    super.key,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onRegister;
  final Future<void> Function(String email, String password) onSubmit;
  final VoidCallback onForgotPassword;
  final String? errorMessage;

  @override
  State<TradeSquareLoginScreen> createState() => _TradeSquareLoginScreenState();
}

class _TradeSquareLoginScreenState extends State<TradeSquareLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.onSubmit(_email.text.trim(), _password.text);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return TradeSquareAuthFrame(
      locale: widget.locale,
      onLocaleChanged: widget.onLocaleChanged,
      child: TradeSquareAuthCard(
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TradeSquareAuthHeading(
                  title: localizations.authLoginWelcome,
                  subtitle: localizations.authLoginSubtitle,
                ),
                const SizedBox(height: 28),
                TradeSquareAuthField(
                  controller: _email,
                  label: localizations.authEmail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  prefix: const Icon(Icons.mail_outline),
                  validator: (value) => _validateEmail(value, localizations),
                ),
                const SizedBox(height: 16),
                TradeSquarePasswordField(
                  controller: _password,
                  label: localizations.authPassword,
                  showLabel: localizations.authShowPassword,
                  hideLabel: localizations.authHidePassword,
                  validator: (value) => _required(value, localizations),
                ),
                if (widget.errorMessage != null &&
                    widget.errorMessage!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          localizations.authRememberMe,
                          style: theme.textTheme.bodySmall,
                        ),
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onForgotPassword,
                      child: Text(localizations.authForgotPassword),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TradeSquareAuthPrimaryButton(
                  label: localizations.authSignIn,
                  onPressed: _signIn,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 22),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(localizations.authNoAccount),
                      TextButton(
                        onPressed: widget.onRegister,
                        child: Text(localizations.authCreateAccount),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TradeSquareRegistrationScreen extends StatefulWidget {
  const TradeSquareRegistrationScreen({
    required this.locale,
    required this.onLocaleChanged,
    required this.onLogin,
    required this.onContinue,
    this.errorMessage,
    super.key,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onLogin;
  final Future<void> Function(TradeSquareAuthDraft draft) onContinue;
  final String? errorMessage;

  @override
  State<TradeSquareRegistrationScreen> createState() =>
      _TradeSquareRegistrationScreenState();
}

class _TradeSquareRegistrationScreenState
    extends State<TradeSquareRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String _phoneCode = '+250';
  bool _acceptedTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.onContinue(
        TradeSquareAuthDraft(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          phone: '$_phoneCode ${_phone.text.trim()}',
          password: _password.text,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final strength = _passwordScore(_password.text);
    final strengthLabel = switch (strength) {
      0 || 1 => localizations.authPasswordWeak,
      2 => localizations.authPasswordFair,
      _ => localizations.authPasswordStrong,
    };
    return TradeSquareAuthFrame(
      locale: widget.locale,
      onLocaleChanged: widget.onLocaleChanged,
      onBack: widget.onLogin,
      backLabel: localizations.authSignIn,
      child: TradeSquareAuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TradeSquareAuthHeading(
                title: localizations.authRegistrationTitle,
                subtitle: localizations.authRegistrationSubtitle,
              ),
              const SizedBox(height: 24),
              TradeSquareAuthField(
                controller: _name,
                label: localizations.authFullName,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: (value) => _required(value, localizations),
              ),
              const SizedBox(height: 14),
              TradeSquareAuthField(
                controller: _email,
                label: localizations.authEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (value) => _validateEmail(value, localizations),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 124,
                    child: DropdownButtonFormField<String>(
                      value: _phoneCode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: localizations.authPhoneCountryCode,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '+250',
                          child: Text(localizations.authPhoneRwanda),
                        ),
                        DropdownMenuItem(
                          value: '+254',
                          child: Text(localizations.authPhoneKenya),
                        ),
                        DropdownMenuItem(
                          value: '+256',
                          child: Text(localizations.authPhoneUganda),
                        ),
                        DropdownMenuItem(
                          value: '+255',
                          child: Text(localizations.authPhoneTanzania),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _phoneCode = value ?? '+250'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TradeSquareAuthField(
                      controller: _phone,
                      label: localizations.authPhoneNumber,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      validator: (value) => _required(value, localizations),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TradeSquarePasswordField(
                controller: _password,
                label: localizations.authPassword,
                showLabel: localizations.authShowPassword,
                hideLabel: localizations.authHidePassword,
                onChanged: (_) => setState(() {}),
                validator: (value) => (value?.length ?? 0) < 8
                    ? localizations.authPasswordMin
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LinearProgressIndicator(
                        value: strength / 4,
                        minHeight: 5,
                        color: _strengthColor(strength),
                        backgroundColor: AppColors.border,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '${localizations.authPasswordStrength}: $strengthLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TradeSquarePasswordField(
                controller: _confirmation,
                label: localizations.authConfirmPassword,
                showLabel: localizations.authShowPassword,
                hideLabel: localizations.authHidePassword,
                validator: (value) => value != _password.text
                    ? localizations.authPasswordsMismatch
                    : null,
              ),
              const SizedBox(height: 10),
              FormField<bool>(
                initialValue: _acceptedTerms,
                validator: (value) =>
                    value == true ? null : localizations.authAcceptTermsError,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: _acceptedTerms,
                      onChanged: (value) {
                        setState(() => _acceptedTerms = value ?? false);
                        field.didChange(_acceptedTerms);
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        localizations.authAcceptTerms,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (field.errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.errorMessage != null &&
                  widget.errorMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TradeSquareAuthPrimaryButton(
                label: localizations.authContinue,
                onPressed: _continue,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 14),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(localizations.authHaveAccount),
                    TextButton(
                      onPressed: widget.onLogin,
                      child: Text(localizations.authSignIn),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TradeSquareEligibilityScreen extends StatefulWidget {
  const TradeSquareEligibilityScreen({
    required this.locale,
    required this.onLocaleChanged,
    required this.draft,
    required this.onBack,
    required this.onContinue,
    super.key,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final TradeSquareAuthDraft draft;
  final VoidCallback onBack;
  final ValueChanged<TradeSquareAuthDraft> onContinue;

  @override
  State<TradeSquareEligibilityScreen> createState() =>
      _TradeSquareEligibilityScreenState();
}

class _TradeSquareEligibilityScreenState
    extends State<TradeSquareEligibilityScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.draft.businessName);
  late final _number =
      TextEditingController(text: widget.draft.registrationNumber);
  late final _location = TextEditingController(text: widget.draft.location);
  String? _country;
  TradeSquareBusinessType? _businessType;
  TradeSquareRegistrationStatus? _status;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return TradeSquareAuthFrame(
      locale: widget.locale,
      onLocaleChanged: widget.onLocaleChanged,
      progress: 18,
      onBack: widget.onBack,
      backLabel: localizations.authBack,
      child: TradeSquareAuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TradeSquareAuthHeading(
                title: localizations.authTellBusiness,
                subtitle: localizations.authEligibilitySubtitle,
              ),
              const SizedBox(height: 22),
              TradeSquareAuthSelect<String>(
                label: localizations.authCountryOfRegistration,
                value: _country,
                options: [
                  _option(localizations.authCountryRwanda, 'Rwanda'),
                  _option(localizations.authCountryKenya, 'Kenya'),
                  _option(localizations.authCountryUganda, 'Uganda'),
                  _option(localizations.authCountryTanzania, 'Tanzania'),
                  _option(localizations.authCountryOther, 'Other'),
                ],
                onChanged: (value) => setState(() => _country = value),
                validator: (value) =>
                    value == null ? localizations.authRequired : null,
              ),
              const SizedBox(height: 14),
              TradeSquareAuthField(
                controller: _name,
                label: localizations.authBusinessName,
                textCapitalization: TextCapitalization.words,
                validator: (value) => _required(value, localizations),
              ),
              const SizedBox(height: 14),
              TradeSquareAuthSelect<TradeSquareBusinessType>(
                label: localizations.authBusinessType,
                value: _businessType,
                options: [
                  _option(localizations.authTypeLimitedCompany,
                      TradeSquareBusinessType.limitedCompany),
                  _option(localizations.authTypeSoleProprietorship,
                      TradeSquareBusinessType.soleProprietorship),
                  _option(localizations.authTypePartnership,
                      TradeSquareBusinessType.partnership),
                  _option(localizations.authTypeCooperative,
                      TradeSquareBusinessType.cooperative),
                  _option(localizations.authTypeRegisteredEnterprise,
                      TradeSquareBusinessType.registeredEnterprise),
                  _option(localizations.authTypeOther,
                      TradeSquareBusinessType.other),
                ],
                onChanged: (value) => setState(() => _businessType = value),
                validator: (value) =>
                    value == null ? localizations.authRequired : null,
              ),
              const SizedBox(height: 14),
              TradeSquareAuthSelect<TradeSquareRegistrationStatus>(
                label: localizations.authRegistrationStatus,
                value: _status,
                options: [
                  _option(localizations.authRegistered,
                      TradeSquareRegistrationStatus.registered),
                  _option(localizations.authRegistrationPending,
                      TradeSquareRegistrationStatus.pending),
                  _option(localizations.authNotRegistered,
                      TradeSquareRegistrationStatus.notRegistered),
                ],
                onChanged: (value) => setState(() => _status = value),
                validator: (value) =>
                    value == null ? localizations.authRequired : null,
              ),
              const SizedBox(height: 14),
              TradeSquareAuthField(
                controller: _number,
                label:
                    '${localizations.authRegistrationNumber} (${localizations.authOptional})',
                prefix: const Icon(Icons.numbers_outlined),
              ),
              const SizedBox(height: 14),
              TradeSquareAuthField(
                controller: _location,
                label: localizations.authBusinessLocation,
                textCapitalization: TextCapitalization.words,
                validator: (value) => _required(value, localizations),
              ),
              const SizedBox(height: 18),
              TradeSquareAuthInfoPanel(
                title: localizations.authEligibilityInfoTitle,
                body: localizations.authEligibilityInfoBody,
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(localizations.authAcceptedDocumentsTitle),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(localizations.authAcceptedDocumentsBody),
                  ),
                ],
              ),
              Text(
                localizations.authEligibilityHelp,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              TradeSquareAuthPrimaryButton(
                label: localizations.authContinue,
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.draft
                    ..country = _country!
                    ..businessName = _name.text.trim()
                    ..businessType = _businessType
                    ..registrationStatus = _status
                    ..registrationNumber = _number.text.trim()
                    ..location = _location.text.trim();
                  widget.onContinue(widget.draft);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TradeSquareCertificateScreen extends StatefulWidget {
  const TradeSquareCertificateScreen({
    required this.locale,
    required this.onLocaleChanged,
    required this.document,
    required this.documentType,
    required this.onDocumentChanged,
    required this.onDocumentTypeChanged,
    required this.onBack,
    required this.onContinue,
    super.key,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final TradeSquareLocalDocument? document;
  final String? documentType;
  final ValueChanged<TradeSquareLocalDocument?> onDocumentChanged;
  final ValueChanged<String?> onDocumentTypeChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<TradeSquareCertificateScreen> createState() =>
      _TradeSquareCertificateScreenState();
}

class _TradeSquareCertificateScreenState
    extends State<TradeSquareCertificateScreen> {
  static const _maxBytes = 10 * 1024 * 1024;
  bool _isPreparing = false;
  String? _errorMessage;
  Timer? _progressTimer;
  double _progress = 0;
  Uint8List? _imagePreview;

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final localizations = AppLocalizations.of(context)!;
    setState(() => _errorMessage = null);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
        allowMultiple: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final extension = (file.extension ?? '').toLowerCase();
      if (!const {'pdf', 'jpg', 'jpeg', 'png'}.contains(extension)) {
        setState(() => _errorMessage = localizations.authFileUnsupported);
        return;
      }
      if (file.size > _maxBytes) {
        setState(() => _errorMessage = localizations.authFileTooLarge);
        return;
      }

      widget.onDocumentChanged(TradeSquareLocalDocument(
        name: file.name,
        extension: extension,
        sizeBytes: file.size,
      ));
      _imagePreview =
          extension == 'jpg' || extension == 'jpeg' || extension == 'png'
              ? file.bytes
              : null;
      _progressTimer?.cancel();
      setState(() {
        _isPreparing = true;
        _progress = 0;
      });
      _progressTimer =
          Timer.periodic(const Duration(milliseconds: 70), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _progress = math.min(1, _progress + 0.2);
          if (_progress >= 1) {
            _isPreparing = false;
            timer.cancel();
          }
        });
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() => _errorMessage = localizations.authFilePickerError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final document = widget.document;
    return TradeSquareAuthFrame(
      locale: widget.locale,
      onLocaleChanged: widget.onLocaleChanged,
      progress: 32,
      onBack: widget.onBack,
      backLabel: localizations.authBack,
      child: TradeSquareAuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TradeSquareAuthHeading(
              title: localizations.authCertificateTitle,
              subtitle: localizations.authCertificateSubtitle,
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<String>(
              value: widget.documentType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: localizations.authDocumentType,
              ),
              items: [
                _option(localizations.authDocIncorporation, 'incorporation'),
                _option(localizations.authDocRegistration, 'registration'),
                _option(
                  localizations.authDocBusinessRegistration,
                  'business-registration',
                ),
                _option(localizations.authDocOther, 'other'),
              ],
              onChanged: widget.onDocumentTypeChanged,
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _pickDocument,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.4,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      localizations.authDropTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations.authDropSubtitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pickDocument,
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: Text(localizations.authBrowseFiles),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations.authFileGuidance,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: _errorMessage!),
            ],
            if (document != null) ...[
              const SizedBox(height: 14),
              _LocalDocumentPreview(
                document: document,
                imageBytes: _imagePreview,
                onReplace: _pickDocument,
                onRemove: () {
                  _progressTimer?.cancel();
                  widget.onDocumentChanged(null);
                  setState(() {
                    _imagePreview = null;
                    _isPreparing = false;
                    _progress = 0;
                  });
                },
              ),
              if (_isPreparing) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 6),
                Text(localizations.authPreparingDocument),
              ],
              if (!_isPreparing && _progress >= 1) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Text(localizations.authDocumentReady),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            TradeSquareAuthInfoPanel(
              title: localizations.authReviewNotice,
              body: localizations.authLocalOnly,
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 18),
            TradeSquareAuthPrimaryButton(
              label: localizations.authUploadSubmit,
              onPressed: widget.document == null ? null : widget.onContinue,
            ),
            Align(
              alignment: AlignmentDirectional.center,
              child: TextButton(
                onPressed: widget.onContinue,
                child: Text(localizations.authUploadContinueWithout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalDocumentPreview extends StatelessWidget {
  const _LocalDocumentPreview({
    required this.document,
    required this.onReplace,
    required this.onRemove,
    this.imageBytes,
  });

  final TradeSquareLocalDocument document;
  final Uint8List? imageBytes;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isPdf = document.extension == 'pdf';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                imageBytes!,
                width: 48,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.image_outlined,
                  size: 40,
                ),
              ),
            )
          else
            Container(
              width: 48,
              height: 54,
              decoration: BoxDecoration(
                color: isPdf
                    ? theme.colorScheme.error.withValues(alpha: 0.08)
                    : theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                color:
                    isPdf ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.authSelectedDocument,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  document.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${document.formattedSize} · ${document.extension.toUpperCase()}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: localizations.authReplaceFile,
            onSelected: (value) => value == 'remove' ? onRemove() : onReplace(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'replace',
                child: Text(localizations.authReplaceFile),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text(localizations.authRemoveFile),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TradeSquareBusinessOnboardingScreen extends StatefulWidget {
  const TradeSquareBusinessOnboardingScreen({
    required this.locale,
    required this.onLocaleChanged,
    required this.draft,
    required this.step,
    required this.onDraftChanged,
    required this.onBack,
    required this.onContinue,
    required this.onSubmit,
    super.key,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final TradeSquareAuthDraft draft;
  final int step;
  final ValueChanged<TradeSquareAuthDraft> onDraftChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onSubmit;

  @override
  State<TradeSquareBusinessOnboardingScreen> createState() =>
      _TradeSquareBusinessOnboardingScreenState();
}

class _TradeSquareBusinessOnboardingScreenState
    extends State<TradeSquareBusinessOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _businessName =
      TextEditingController(text: widget.draft.businessName);
  late final _registrationNumber =
      TextEditingController(text: widget.draft.registrationNumber);
  late final _location = TextEditingController(text: widget.draft.location);
  late final _description =
      TextEditingController(text: widget.draft.description);
  TradeSquareBusinessIndustry? _industry;
  String? _country;

  @override
  void dispose() {
    _businessName.dispose();
    _registrationNumber.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final title = localizations.authProfileTitle;
    final progress = 42 + (widget.step * 8);
    return TradeSquareAuthFrame(
      locale: widget.locale,
      onLocaleChanged: widget.onLocaleChanged,
      progress: progress,
      onBack: widget.onBack,
      backLabel: localizations.authBack,
      child: TradeSquareAuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TradeSquareAuthHeading(
                title: widget.step == 6 ? localizations.authReviewTitle : title,
                subtitle: widget.step == 6
                    ? localizations.authReviewSubtitle
                    : '${localizations.authProfileSubtitle}  ${widget.step + 1}/7',
              ),
              const SizedBox(height: 20),
              if (widget.step < 6) _OnboardingStepLabel(step: widget.step),
              const SizedBox(height: 16),
              _buildStepBody(context),
              const SizedBox(height: 22),
              Row(
                children: [
                  if (widget.step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onBack,
                        child: Text(localizations.authBack),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: TradeSquareAuthPrimaryButton(
                      label: widget.step == 6
                          ? localizations.authSubmitApplication
                          : localizations.authContinue,
                      onPressed:
                          widget.step == 6 ? widget.onSubmit : _saveAndContinue,
                    ),
                  ),
                ],
              ),
              if (widget.step == 6) ...[
                const SizedBox(height: 14),
                TradeSquareAuthInfoPanel(
                  title: localizations.authReviewNotice,
                  body: localizations.authSubmissionNotice,
                  icon: Icons.info_outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (widget.step) {
      case 0:
        return Column(
          children: [
            TradeSquareAuthField(
              controller: _businessName,
              label: localizations.authBusinessName,
              validator: (value) => _required(value, localizations),
            ),
            const SizedBox(height: 12),
            TradeSquareAuthField(
              controller: _registrationNumber,
              label:
                  '${localizations.authRegistrationNumber} (${localizations.authOptional})',
            ),
            const SizedBox(height: 12),
            TradeSquareAuthSelect<String>(
              label: localizations.authCountryOfRegistration,
              value: _country ?? _countryValue(widget.draft.country),
              options: _countryOptions(localizations),
              onChanged: (value) => setState(() => _country = value),
              validator: (value) =>
                  value == null ? localizations.authRequired : null,
            ),
            const SizedBox(height: 12),
            TradeSquareAuthField(
              controller: _location,
              label: localizations.authDistrictCity,
              validator: (value) => _required(value, localizations),
            ),
            const SizedBox(height: 12),
            TradeSquareAuthField(
              controller: _description,
              label: localizations.authBusinessDescription,
              hint: localizations.authBusinessDescriptionHint,
              maxLines: 4,
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.authChooseIndustry),
            const SizedBox(height: 12),
            DropdownButtonFormField<TradeSquareBusinessIndustry>(
              value: _industry ?? widget.draft.industry,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: localizations.authSearchOptions,
                prefixIcon: const Icon(Icons.search),
              ),
              items: TradeSquareBusinessIndustry.values
                  .map((industry) => _option(
                        _industryLabel(localizations, industry),
                        industry,
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _industry = value),
            ),
          ],
        );
      case 2:
        return _TagInput(
          title: localizations.authProductsOffered,
          hint: localizations.authListInputHint,
          initialValues: widget.draft.productsOffered,
          onChanged: (values) {
            widget.draft.productsOffered = values;
            widget.onDraftChanged(widget.draft);
          },
        );
      case 3:
        return _TagInput(
          title: localizations.authProductsNeeded,
          hint: localizations.authListInputHint,
          initialValues: widget.draft.productsNeeded,
          onChanged: (values) {
            widget.draft.productsNeeded = values;
            widget.onDraftChanged(widget.draft);
          },
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.authBusinessGoals),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TradeSquareBusinessGoal.values
                  .map(
                    (goal) => FilterChip(
                      label: Text(_goalLabel(localizations, goal)),
                      selected: widget.draft.goals.contains(goal),
                      onSelected: (selected) {
                        final goals = Set<TradeSquareBusinessGoal>.of(
                          widget.draft.goals,
                        );
                        selected ? goals.add(goal) : goals.remove(goal);
                        widget.draft.goals = goals;
                        widget.onDraftChanged(widget.draft);
                        setState(() {});
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case 5:
        return Column(
          children: [
            _TagInput(
              title: localizations.authInterests,
              hint: localizations.authInterestsHint,
              initialValues: widget.draft.interests,
              onChanged: (values) {
                widget.draft.interests = values;
                widget.onDraftChanged(widget.draft);
              },
            ),
            const SizedBox(height: 20),
            _TagInput(
              title: localizations.authTargetMarkets,
              hint: localizations.authTargetMarketsHint,
              initialValues: widget.draft.targetMarkets,
              onChanged: (values) {
                widget.draft.targetMarkets = values;
                widget.onDraftChanged(widget.draft);
              },
            ),
          ],
        );
      default:
        return _ReviewSummary(draft: widget.draft);
    }
  }

  void _saveAndContinue() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.step == 0) {
      widget.draft
        ..businessName = _businessName.text.trim()
        ..registrationNumber = _registrationNumber.text.trim()
        ..country = _country ?? widget.draft.country
        ..location = _location.text.trim()
        ..description = _description.text.trim();
    } else if (widget.step == 1) {
      widget.draft.industry = _industry ?? widget.draft.industry;
    }
    widget.onDraftChanged(widget.draft);
    widget.onContinue();
  }
}

class _OnboardingStepLabel extends StatelessWidget {
  const _OnboardingStepLabel({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final labels = [
      localizations.authStepBusinessInfo,
      localizations.authStepIndustry,
      localizations.authStepProductsOffered,
      localizations.authStepProductsNeeded,
      localizations.authStepGoals,
      localizations.authStepInterests,
    ];
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            '${step + 1}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            labels[step],
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _TagInput extends StatefulWidget {
  const _TagInput({
    required this.title,
    required this.hint,
    required this.initialValues,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final List<String> initialValues;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<_TagInput> {
  late final _controller = TextEditingController();
  late List<String> _values = List.of(widget.initialValues);

  @override
  void didUpdateWidget(covariant _TagInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValues != widget.initialValues) {
      _values = List.of(widget.initialValues);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty ||
        _values.any((item) => item.toLowerCase() == value.toLowerCase())) {
      return;
    }
    setState(() {
      _values = [..._values, value];
      _controller.clear();
    });
    widget.onChanged(List.unmodifiable(_values));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(hintText: widget.hint),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: localizations.authAddItem,
              onPressed: _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (_values.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _values
                .map(
                  (value) => InputChip(
                    label: Text(value),
                    onDeleted: () {
                      setState(() => _values.remove(value));
                      widget.onChanged(List.unmodifiable(_values));
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.draft});

  final TradeSquareAuthDraft draft;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final details = <(String, String)>[
      (localizations.authBusinessName, draft.businessName),
      (localizations.authRegistrationNumber, draft.registrationNumber),
      (localizations.authCountryOfRegistration, draft.country),
      (localizations.authDistrictCity, draft.location),
      (
        localizations.authStepIndustry,
        draft.industry == null
            ? ''
            : _industryLabel(localizations, draft.industry!),
      ),
      (localizations.authProductsOffered, draft.productsOffered.join(', ')),
      (localizations.authProductsNeeded, draft.productsNeeded.join(', ')),
      (
        localizations.authBusinessGoals,
        draft.goals.map((goal) => _goalLabel(localizations, goal)).join(', '),
      ),
      (localizations.authInterests, draft.interests.join(', ')),
      (localizations.authTargetMarkets, draft.targetMarkets.join(', ')),
    ];
    return Column(
      children: details
          .where((entry) => entry.$2.trim().isNotEmpty)
          .map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.$1),
              subtitle: Text(entry.$2),
            ),
          )
          .toList(),
    );
  }
}

class TradeSquareApplicationStatusScreen extends StatefulWidget {
  const TradeSquareApplicationStatusScreen({
    required this.locale,
    required this.onLocaleChanged,
    required this.status,
    required this.hasDocument,
    required this.onReturn,
    required this.onReviewCertificate,
    required this.onReviewProfile,
    super.key,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final TradeSquareApplicationStatus status;
  final bool hasDocument;
  final VoidCallback onReturn;
  final VoidCallback onReviewCertificate;
  final VoidCallback onReviewProfile;

  @override
  State<TradeSquareApplicationStatusScreen> createState() =>
      _TradeSquareApplicationStatusScreenState();
}

class _TradeSquareApplicationStatusScreenState
    extends State<TradeSquareApplicationStatusScreen> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return TradeSquareAuthFrame(
      locale: widget.locale,
      onLocaleChanged: widget.onLocaleChanged,
      progress: 100,
      child: TradeSquareAuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TradeSquareAuthHeading(
              title: localizations.authApplicationStatus,
              subtitle: localizations.authStatusDisclaimer,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _statusIcon(widget.status),
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(localizations, widget.status),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_statusBody(localizations, widget.status)),
                        const SizedBox(height: 12),
                        Text(
                          localizations.authStatusNextAction,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(_nextAction(localizations, widget.status)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!widget.hasDocument)
              OutlinedButton.icon(
                onPressed: widget.onReviewCertificate,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(localizations.authStatusCertificateAction),
              ),
            if (!widget.hasDocument) const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.onReviewProfile,
              icon: const Icon(Icons.business_outlined),
              label: Text(localizations.authStatusProfileAction),
            ),
            const SizedBox(height: 8),
            TradeSquareAuthPrimaryButton(
              label: localizations.authStatusReturnHome,
              onPressed: widget.onReturn,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

String? _required(String? value, AppLocalizations localizations) =>
    value == null || value.trim().isEmpty ? localizations.authRequired : null;

String? _validateEmail(String? value, AppLocalizations localizations) {
  final requiredError = _required(value, localizations);
  if (requiredError != null) return requiredError;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())
      ? null
      : localizations.authInvalidEmail;
}

int _passwordScore(String value) {
  if (value.isEmpty) return 0;
  var score = 0;
  if (value.length >= 8) score++;
  if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(value)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
  return score;
}

Color _strengthColor(int score) {
  if (score <= 1) return const Color(0xFFD92D20);
  if (score <= 2) return const Color(0xFFF79009);
  return const Color(0xFF039855);
}

DropdownMenuItem<T> _option<T>(String label, T value) => DropdownMenuItem<T>(
      value: value,
      child: Text(label, overflow: TextOverflow.ellipsis),
    );

List<DropdownMenuItem<String>> _countryOptions(
  AppLocalizations localizations,
) =>
    [
      _option(localizations.authCountryRwanda, 'Rwanda'),
      _option(localizations.authCountryKenya, 'Kenya'),
      _option(localizations.authCountryUganda, 'Uganda'),
      _option(localizations.authCountryTanzania, 'Tanzania'),
      _option(localizations.authCountryOther, 'Other'),
    ];

String? _countryValue(String country) => country.isEmpty
    ? null
    : const ['Rwanda', 'Kenya', 'Uganda', 'Tanzania', 'Other'].contains(country)
        ? country
        : 'Other';

String _industryLabel(
  AppLocalizations localizations,
  TradeSquareBusinessIndustry industry,
) =>
    switch (industry) {
      TradeSquareBusinessIndustry.agriculture =>
        localizations.authIndustryAgriculture,
      TradeSquareBusinessIndustry.informationTechnology =>
        localizations.authIndustryTechnology,
      TradeSquareBusinessIndustry.manufacturing =>
        localizations.authIndustryManufacturing,
      TradeSquareBusinessIndustry.retailWholesale =>
        localizations.authIndustryRetailWholesale,
      TradeSquareBusinessIndustry.construction =>
        localizations.authIndustryConstruction,
      TradeSquareBusinessIndustry.transportationLogistics =>
        localizations.authIndustryTransport,
      TradeSquareBusinessIndustry.foodBeverage =>
        localizations.authIndustryFood,
      TradeSquareBusinessIndustry.healthcare =>
        localizations.authIndustryHealthcare,
      TradeSquareBusinessIndustry.education =>
        localizations.authIndustryEducation,
      TradeSquareBusinessIndustry.tourismHospitality =>
        localizations.authIndustryTourism,
      TradeSquareBusinessIndustry.professionalServices =>
        localizations.authIndustryProfessional,
      TradeSquareBusinessIndustry.energy => localizations.authIndustryEnergy,
      TradeSquareBusinessIndustry.mining => localizations.authIndustryMining,
      TradeSquareBusinessIndustry.other => localizations.authIndustryOther,
    };

String _goalLabel(
  AppLocalizations localizations,
  TradeSquareBusinessGoal goal,
) =>
    switch (goal) {
      TradeSquareBusinessGoal.findBuyers => localizations.authGoalBuyers,
      TradeSquareBusinessGoal.findSuppliers => localizations.authGoalSuppliers,
      TradeSquareBusinessGoal.promoteProducts => localizations.authGoalPromote,
      TradeSquareBusinessGoal.findPartners => localizations.authGoalPartners,
      TradeSquareBusinessGoal.discoverOpportunities =>
        localizations.authGoalOpportunities,
      TradeSquareBusinessGoal.expandMarkets => localizations.authGoalMarkets,
    };

String _statusLabel(
  AppLocalizations localizations,
  TradeSquareApplicationStatus status,
) =>
    switch (status) {
      TradeSquareApplicationStatus.informationIncomplete =>
        localizations.authStatusIncomplete,
      TradeSquareApplicationStatus.certificateNotSubmitted =>
        localizations.authStatusCertificateMissing,
      TradeSquareApplicationStatus.submittedForReview =>
        localizations.authStatusSubmitted,
      TradeSquareApplicationStatus.underReview =>
        localizations.authStatusUnderReview,
      TradeSquareApplicationStatus.additionalInformationRequired =>
        localizations.authStatusAdditionalInfo,
      TradeSquareApplicationStatus.approved => localizations.authStatusApproved,
      TradeSquareApplicationStatus.notApproved =>
        localizations.authStatusNotApproved,
    };

String _statusBody(
  AppLocalizations localizations,
  TradeSquareApplicationStatus status,
) =>
    switch (status) {
      TradeSquareApplicationStatus.informationIncomplete =>
        localizations.authStatusIncompleteBody,
      TradeSquareApplicationStatus.certificateNotSubmitted =>
        localizations.authStatusCertificateMissingBody,
      TradeSquareApplicationStatus.submittedForReview =>
        localizations.authStatusSubmittedBody,
      TradeSquareApplicationStatus.underReview =>
        localizations.authStatusUnderReviewBody,
      TradeSquareApplicationStatus.additionalInformationRequired =>
        localizations.authStatusAdditionalInfoBody,
      TradeSquareApplicationStatus.approved =>
        localizations.authStatusApprovedBody,
      TradeSquareApplicationStatus.notApproved =>
        localizations.authStatusNotApprovedBody,
    };

String _nextAction(
  AppLocalizations localizations,
  TradeSquareApplicationStatus status,
) =>
    switch (status) {
      TradeSquareApplicationStatus.informationIncomplete =>
        localizations.authStatusProfileAction,
      TradeSquareApplicationStatus.certificateNotSubmitted =>
        localizations.authStatusCertificateAction,
      TradeSquareApplicationStatus.submittedForReview ||
      TradeSquareApplicationStatus.underReview =>
        localizations.authStatusReturnHome,
      TradeSquareApplicationStatus.additionalInformationRequired =>
        localizations.authStatusProfileAction,
      TradeSquareApplicationStatus.approved ||
      TradeSquareApplicationStatus.notApproved =>
        localizations.authStatusReturnHome,
    };

IconData _statusIcon(TradeSquareApplicationStatus status) => switch (status) {
      TradeSquareApplicationStatus.informationIncomplete =>
        Icons.pending_actions_outlined,
      TradeSquareApplicationStatus.certificateNotSubmitted =>
        Icons.upload_file_outlined,
      TradeSquareApplicationStatus.submittedForReview => Icons.outbox_outlined,
      TradeSquareApplicationStatus.underReview => Icons.hourglass_top_outlined,
      TradeSquareApplicationStatus.additionalInformationRequired =>
        Icons.info_outline,
      TradeSquareApplicationStatus.approved => Icons.verified_outlined,
      TradeSquareApplicationStatus.notApproved => Icons.highlight_off_outlined,
    };
