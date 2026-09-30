import 'package:flutter/material.dart';
import '../provider/print_bridge_form_provider.dart';
import '../services/print_bridge_services.dart';
import 'custom_color.dart';

/// Asset paths. Must match the folder name on disk AND pubspec.yaml.
class AppAssets {
  AppAssets._();
  static const String logo = 'asset/images/logo.png';
  static const String splash = 'asset/images/splash_logo.png';
}

// =============================================================================
// CARD
// =============================================================================

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// HEADER (logo + title)
// =============================================================================

class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AppHeader({
    super.key,
    this.title = 'restroSanjalPrinterBridge',
    this.subtitle = 'Connect your server to your restaurant printer',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.deepGreen, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepGreen.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              AppAssets.logo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.room_service_outlined,
                    size: 44, color: AppColors.copper),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.deepGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Container(
          width: 60,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.copper,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SECTION TITLE / INFO NOTE
// =============================================================================

class AppSectionTitle extends StatelessWidget {
  final String text;
  const AppSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.subtle,
      ),
    );
  }
}

class AppInfoNote extends StatelessWidget {
  final String text;
  const AppInfoNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 14, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// FORM FIELDS
// =============================================================================

InputDecoration appFieldDecoration({
  required String hint,
  required IconData icon,
  required bool enabled,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: w),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.subtle, fontSize: 14),
    prefixIcon: Icon(icon, size: 20, color: AppColors.muted),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: enabled ? AppColors.inputBg : AppColors.inputDisabledBg,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    disabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.green, 1.5),
    errorBorder: border(Colors.red.shade300),
    focusedErrorBorder: border(Colors.red.shade400, 1.5),
  );
}

class AppLabeledField extends StatelessWidget {
  final String label;
  final String? labelHint;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final bool required;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const AppLabeledField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.labelHint,
    this.obscureText = false,
    this.required = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "*" goes IN FRONT of the label, in red, when the field is required.
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.text : Colors.grey.shade400,
            ),
            children: [
              if (required)
                TextSpan(
                  text: '* ',
                  style: TextStyle(
                    color: enabled
                        ? Theme.of(context).colorScheme.error
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              TextSpan(text: label),
              if (labelHint != null)
                TextSpan(
                  text: '  $labelHint',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.subtle,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          enabled: enabled,
          style: TextStyle(
            fontSize: 14,
            color: enabled ? AppColors.text : Colors.grey.shade500,
          ),
          decoration: appFieldDecoration(
            hint: hint,
            icon: icon,
            enabled: enabled,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Log level as an EDITABLE combo box: pick a preset from the dropdown, or
/// type any value directly. Backed by a plain TextEditingController so
/// whatever is typed is always the source of truth.
class AppLogLevelField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> presets;
  final bool enabled;

  const AppLogLevelField({
    super.key,
    required this.controller,
    required this.presets,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Log Level',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.text : Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            OutlineInputBorder border(Color c, [double w = 1]) =>
                OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c, width: w),
                );
            return DropdownMenu<String>(
              controller: controller,
              width: constraints.maxWidth,
              enabled: enabled,
              enableFilter: false,
              requestFocusOnTap: true,
              leadingIcon:
              const Icon(Icons.tune, size: 20, color: AppColors.muted),
              hintText: 'info',
              textStyle: TextStyle(
                fontSize: 14,
                color: enabled ? AppColors.text : Colors.grey.shade500,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor:
                enabled ? AppColors.inputBg : AppColors.inputDisabledBg,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                border: border(AppColors.border),
                enabledBorder: border(AppColors.border),
                disabledBorder: border(AppColors.border),
                focusedBorder: border(AppColors.green, 1.5),
              ),
              dropdownMenuEntries: presets
                  .map((p) => DropdownMenuEntry<String>(value: p, label: p))
                  .toList(),
              onSelected: (value) {
                if (value != null) controller.text = value;
              },
            );
          },
        ),
      ],
    );
  }
}

// =============================================================================
// BUTTONS
// =============================================================================

class AppPillButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  const AppPillButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green,
        backgroundColor:
        onPressed == null ? Colors.grey.shade100 : AppColors.pillBg,
        side: BorderSide(
          color: onPressed == null ? AppColors.border : AppColors.pillBorder,
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class AppOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const AppOutlinedButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green,
          side: BorderSide(
            color: onPressed == null ? AppColors.border : AppColors.green,
            width: 2,
          ),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class AppGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final List<Color> colors;
  final Widget icon;
  final String label;

  const AppGradientButton({
    super.key,
    required this.onPressed,
    required this.colors,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DISCOVERED PRINTERS BOX
// =============================================================================

class DiscoveredPrintersBox extends StatelessWidget {
  final List<String> printers;
  final ValueChanged<String> onSelected;

  const DiscoveredPrintersBox({
    super.key,
    required this.printers,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.creamBox,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Discovered on network:',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ip in printers)
                ActionChip(
                  avatar: const Icon(Icons.print,
                      size: 14, color: AppColors.brown),
                  label: Text(
                    ip,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brown,
                    ),
                  ),
                  backgroundColor: AppColors.cream,
                  side: const BorderSide(color: AppColors.creamBorder),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onPressed: () => onSelected(ip),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATUS TILE
// =============================================================================

class AppStatusDot extends StatelessWidget {
  final BridgeStatus status;
  const AppStatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case BridgeStatus.connected:
        color = AppColors.statusConnected;
        break;
      case BridgeStatus.connecting:
        color = AppColors.statusConnecting;
        break;
      case BridgeStatus.error:
        color = AppColors.statusError;
        break;
      case BridgeStatus.disconnected:
        color = AppColors.statusDisconnected;
        break;
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
        ],
      ),
    );
  }
}

class StatusTile extends StatelessWidget {
  final BridgeStatus status;
  final int jobsPrinted;

  const StatusTile({
    super.key,
    required this.status,
    required this.jobsPrinted,
  });

  String get _label {
    switch (status) {
      case BridgeStatus.connected:
        return 'Connected — polling for jobs';
      case BridgeStatus.connecting:
        return 'Connecting…';
      case BridgeStatus.error:
        return 'Connection error';
      case BridgeStatus.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          AppStatusDot(status: status),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$jobsPrinted job(s) printed this session',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LOG TILE (one line in the terminal)
// =============================================================================

class LogTile extends StatelessWidget {
  final LogEntry entry;
  const LogTile({super.key, required this.entry});

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  String get _tag {
    switch (entry.level) {
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.debug:
        return 'DEBUG';
    }
  }

  Color get _color {
    switch (entry.level) {
      case LogLevel.error:
        return AppColors.logError;
      case LogLevel.warn:
        return AppColors.logWarn;
      case LogLevel.info:
        return AppColors.logInfo;
      case LogLevel.debug:
        return AppColors.logDebug;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            fontFamily: 'monospace',
            height: 1.4,
            color: AppColors.terminalText,
          ),
          children: [
            TextSpan(
              text: '[${_fmtTime(entry.time)}] ',
              style: const TextStyle(color: AppColors.terminalTime),
            ),
            TextSpan(
              text: '[$_tag] ',
              style: TextStyle(color: _color, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: entry.message),
          ],
        ),
      ),
    );
  }
}
