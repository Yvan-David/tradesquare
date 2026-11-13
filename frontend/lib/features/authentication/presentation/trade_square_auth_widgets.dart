import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/branding/trade_square_logo.dart';

class TradeSquareAuthFrame extends StatelessWidget {
  const TradeSquareAuthFrame({
    required this.child,
    required this.locale,
    required this.onLocaleChanged,
    this.progress,
    this.onBack,
    this.backLabel,
    super.key,
  });

  final Widget child;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final int? progress;
  final VoidCallback? onBack;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 980;
    final compact = width < 600;
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width < 600 ? 18 : 32,
                vertical: 12,
              ),
              child: Row(
                children: [
                  TradeSquareAuthBrand(compact: compact),
                  const Spacer(),
                  if (onBack != null)
                    compact
                        ? IconButton(
                            tooltip: backLabel ?? localizations.authBack,
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back, size: 18),
                          )
                        : TextButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: Text(backLabel ?? ''),
                          ),
                  const SizedBox(width: 8),
                  _LanguageSelector(
                    locale: locale,
                    onChanged: onLocaleChanged,
                    compact: compact,
                  ),
                ],
              ),
            ),
            if (progress != null)
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: width < 600 ? 18 : 32),
                child: TradeSquareAuthProgress(value: progress!),
              ),
            Expanded(
              child: desktop
                  ? _desktopLayout(context)
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        width < 600 ? 18 : 36,
                        20,
                        width < 600 ? 18 : 36,
                        32,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: child,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              const Expanded(flex: 5, child: _AuthStoryPanel()),
              const SizedBox(width: 32),
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: child,
                    ),
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

class TradeSquareAuthBrand extends StatelessWidget {
  const TradeSquareAuthBrand({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TradeSquareLogo(size: 40, borderRadius: 12),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localizations.appTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            if (!compact)
              Text(
                localizations.authBrandSubtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class TradeSquareAuthProgress extends StatelessWidget {
  const TradeSquareAuthProgress({required this.value, super.key});

  final int value;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 100);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 4,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class TradeSquareAuthField extends StatelessWidget {
  const TradeSquareAuthField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.maxLines = 1,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.autofillHints,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class TradeSquarePasswordField extends StatefulWidget {
  const TradeSquarePasswordField({
    required this.controller,
    required this.label,
    required this.showLabel,
    required this.hideLabel,
    this.validator,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String showLabel;
  final String hideLabel;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  State<TradeSquarePasswordField> createState() =>
      _TradeSquarePasswordFieldState();
}

class _TradeSquarePasswordFieldState extends State<TradeSquarePasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      validator: widget.validator,
      onChanged: widget.onChanged,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _obscureText ? widget.showLabel : widget.hideLabel,
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class TradeSquareAuthPrimaryButton extends StatelessWidget {
  const TradeSquareAuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TradeSquareAuthCard extends StatelessWidget {
  const TradeSquareAuthCard({
    required this.child,
    this.padding = const EdgeInsets.all(28),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.outlineVariant
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class TradeSquareAuthHeading extends StatelessWidget {
  const TradeSquareAuthHeading({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class TradeSquareAuthInfoPanel extends StatelessWidget {
  const TradeSquareAuthInfoPanel({
    required this.title,
    required this.body,
    this.icon = Icons.info_outline,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TradeSquareAuthSelect<T> extends StatelessWidget {
  const TradeSquareAuthSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.validator,
    super.key,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> options;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      validator: validator,
      decoration: InputDecoration(labelText: label),
      items: options,
      onChanged: onChanged,
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.locale,
    required this.onChanged,
    required this.compact,
  });

  final Locale locale;
  final ValueChanged<Locale> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final entries = {
      'en': localizations.languageEnglish,
      'rw': localizations.languageKinyarwanda,
      'sw': localizations.languageKiswahili,
      'fr': localizations.languageFrench,
    };
    return PopupMenuButton<String>(
      tooltip: localizations.authLanguage,
      initialValue: locale.languageCode,
      onSelected: (code) => onChanged(Locale(code)),
      itemBuilder: (context) => entries.entries
          .map(
            (entry) => PopupMenuItem(
              value: entry.key,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: locale.languageCode == entry.key
                        ? const Icon(Icons.check, size: 16)
                        : null,
                  ),
                  Text(entry.value),
                ],
              ),
            ),
          )
          .toList(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, size: 18),
              SizedBox(width: compact ? 4 : 6),
              Text(compact
                  ? locale.languageCode.toUpperCase()
                  : entries[locale.languageCode] ?? entries['en']!),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthStoryPanel extends StatelessWidget {
  const _AuthStoryPanel();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TradeSquareLogo(size: 48, borderRadius: 14),
          const Spacer(),
          Text(
            localizations.authStoryTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            localizations.authStoryBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          for (final (index, label) in [
            localizations.authStoryItemOne,
            localizations.authStoryItemTwo,
            localizations.authStoryItemThree,
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: Text('${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}
