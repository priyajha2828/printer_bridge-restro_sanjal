import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/print_bridge_config.dart';
import '../provider/print_bridge_form_provider.dart';
import '../services/print_bridge_services.dart';

class PrintBridgeFormPage extends StatefulWidget {
  const PrintBridgeFormPage({super.key});

  @override
  State<PrintBridgeFormPage> createState() => _PrintBridgeFormPageState();
}

class _PrintBridgeFormPageState extends State<PrintBridgeFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _serverUrlCtrl;
  late final TextEditingController _bridgeTokenCtrl;
  late final TextEditingController _clientIdCtrl;
  late final TextEditingController _printerIpCtrl;
  late final TextEditingController _printerPortCtrl;
  late final TextEditingController _pollIntervalCtrl;
  late final TextEditingController _logLevelCtrl;

  bool _obscureToken = true;
  bool _initializedFromProvider = false;

  static const List<String> _logLevelPresets = ['error', 'warn', 'info', 'debug'];

  @override
  void initState() {
    super.initState();
    _serverUrlCtrl = TextEditingController();
    _bridgeTokenCtrl = TextEditingController();
    _clientIdCtrl = TextEditingController();
    _printerIpCtrl = TextEditingController();
    _printerPortCtrl = TextEditingController();
    _pollIntervalCtrl = TextEditingController();
    _logLevelCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PrintBridgeProvider>();
      await provider.loadConfig();
      _applyConfigToFields(provider.config);
    });
  }

  void _applyConfigToFields(BridgeConfig c) {
    setState(() {
      _serverUrlCtrl.text = c.serverUrl;
      _bridgeTokenCtrl.text = c.bridgeToken;
      _clientIdCtrl.text = c.clientId;
      _printerIpCtrl.text = c.printerIp;
      _printerPortCtrl.text = c.printerPort;
      _pollIntervalCtrl.text = c.pollInterval.isEmpty ? '3000' : c.pollInterval;
      _logLevelCtrl.text = c.logLevel.isEmpty ? 'info' : c.logLevel;
      _initializedFromProvider = true;
    });
  }

  BridgeConfig _configFromFields() => BridgeConfig(
    serverUrl: _serverUrlCtrl.text.trim(),
    bridgeToken: _bridgeTokenCtrl.text.trim(),
    clientId: _clientIdCtrl.text.trim(),
    printerIp: _printerIpCtrl.text.trim(),
    printerPort: _printerPortCtrl.text.trim(),
    pollInterval: _pollIntervalCtrl.text.trim(),
    logLevel: _logLevelCtrl.text.trim().isEmpty
        ? 'info'
        : _logLevelCtrl.text.trim(),
  );

  Future<void> _saveOnly() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<PrintBridgeProvider>().saveConfig(_configFromFields());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuration saved')),
    );
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<PrintBridgeProvider>();
    await provider.saveConfig(_configFromFields());
    await provider.connect();
  }

  Future<void> _testPrinter() async {
    if (_printerIpCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a printer IP first')),
      );
      return;
    }
    final provider = context.read<PrintBridgeProvider>();
    await provider.saveConfig(_configFromFields());
    final ok = await provider.testPrinter();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Printer reachable ✓' : 'Could not reach printer'),
        backgroundColor: ok ? Colors.green.shade600 : Colors.red.shade600,
      ),
    );
  }

  Future<void> _testPrintSample() async {
    if (_printerIpCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a printer IP first')),
      );
      return;
    }
    final provider = context.read<PrintBridgeProvider>();
    await provider.saveConfig(_configFromFields());
    final ok = await provider.testPrintSample();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Test print sent ✓' : 'Test print failed'),
        backgroundColor: ok ? Colors.green.shade600 : Colors.red.shade600,
      ),
    );
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _bridgeTokenCtrl.dispose();
    _clientIdCtrl.dispose();
    _printerIpCtrl.dispose();
    _printerPortCtrl.dispose();
    _pollIntervalCtrl.dispose();
    _logLevelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrintBridgeProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Print Bridge'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFFF4F6F8),
        foregroundColor: const Color(0xFF1A1D1F),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final content = _initializedFromProvider
                ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isWide
                      ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 5,
                            child: _buildFormCard(provider)),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 4,
                          child: _buildStatusColumn(provider,
                              expandLog: true),
                        ),
                      ],
                    ),
                  )
                      : Column(
                    children: [
                      _buildFormCard(provider),
                      const SizedBox(height: 20),
                      _buildStatusColumn(provider,
                          expandLog: false),
                    ],
                  ),
                ),
              ),
            )
                : const Center(child: CircularProgressIndicator());
            return content;
          },
        ),
      ),
    );
  }

  Widget _buildFormCard(PrintBridgeProvider provider) {
    // Poll interval and log level are fixed at their defaults (3000ms,
    // info) and are never user-editable.
    const behaviorFieldsEnabled = false;

    return _Card(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Server'),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Server URL',
              required: true,
              hint: 'http://localhost',
              controller: _serverUrlCtrl,
              icon: Icons.dns_outlined,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Server URL is required'
                  : null,
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: 'Bridge Token',
              required: true,
              hint: 'Paste token from Settings > Printer Setup',
              controller: _bridgeTokenCtrl,
              icon: Icons.vpn_key_outlined,
              obscureText: _obscureToken,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Bridge token is required'
                  : null,
              suffixIcon: IconButton(
                icon: Icon(_obscureToken
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureToken = !_obscureToken),
              ),
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: 'Client ID',
              hint: 'Optional — defaults to device name',
              controller: _clientIdCtrl,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Printer'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _LabeledField(
                    label: 'Printer IP',
                    required: true,
                    hint: '192.168.1.50',
                    controller: _printerIpCtrl,
                    icon: Icons.print_outlined,
                    keyboardType: TextInputType.text,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Printer IP is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _LabeledField(
                    label: 'Port',
                    hint: '9100',
                    controller: _printerPortCtrl,
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _testPrinter,
                  icon: const Icon(Icons.wifi_tethering, size: 18),
                  label: const Text('Test printer connection'),
                ),
                TextButton.icon(
                  onPressed: _testPrintSample,
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text("Test print"),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle('Behavior'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'Poll Interval (ms)',
                    hint: '3000',
                    controller: _pollIntervalCtrl,
                    icon: Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                    enabled: behaviorFieldsEnabled,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LogLevelField(
                    controller: _logLevelCtrl,
                    presets: _logLevelPresets,
                    enabled: behaviorFieldsEnabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Poll interval and log level are fixed at their defaults',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: provider.isBusy ? null : _saveOnly,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: provider.isBusy
                        ? null
                        : (provider.isConnected
                        ? () => provider.disconnect()
                        : _connect),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: provider.isConnected
                          ? Colors.red.shade600
                          : const Color(0xFF2F6FED),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: provider.isBusy
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : Icon(provider.isConnected
                        ? Icons.link_off
                        : Icons.play_arrow_rounded),
                    label:
                    Text(provider.isConnected ? 'Disconnect' : 'Connect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusColumn(PrintBridgeProvider provider,
      {required bool expandLog}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Row(
            children: [
              _StatusDot(status: provider.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusLabel(provider.status),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${provider.jobsPrinted} job(s) printed this session',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (expandLog)
          Expanded(child: _buildLogCard(provider))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 260, maxHeight: 420),
            child: _buildLogCard(provider),
          ),
      ],
    );
  }

  Widget _buildLogCard(PrintBridgeProvider provider) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Activity Log',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => provider.clearLogs(),
              ),
            ],
          ),
          const Divider(height: 12),
          Expanded(
            child: provider.logs.isEmpty
                ? Center(
              child: Text('No activity yet',
                  style: TextStyle(color: Colors.grey.shade500)),
            )
                : ListView.builder(
              itemCount: provider.logs.length,
              itemBuilder: (context, i) {
                final log = provider.logs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 3, horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _logColor(log.level),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.message,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(BridgeStatus s) {
    switch (s) {
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

  Color _logColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Colors.red.shade400;
      case LogLevel.warn:
        return Colors.orange.shade400;
      case LogLevel.info:
        return Colors.blue.shade400;
      case LogLevel.debug:
        return Colors.grey.shade400;
    }
  }
}

class _StatusDot extends StatelessWidget {
  final BridgeStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case BridgeStatus.connected:
        color = Colors.green.shade500;
        break;
      case BridgeStatus.connecting:
        color = Colors.orange.shade500;
        break;
      case BridgeStatus.error:
        color = Colors.red.shade500;
        break;
      case BridgeStatus.disconnected:
        color = Colors.grey.shade400;
        break;
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.grey.shade500,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final bool required;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
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
              color: enabled ? const Color(0xFF1A1D1F) : Colors.grey.shade400,
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
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor:
            enabled ? const Color(0xFFF8F9FA) : Colors.grey.shade100,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
              const BorderSide(color: Color(0xFF2F6FED), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
          ),
        ),
      ],
    );
  }
}

/// Log level as an EDITABLE combo box: pick a preset from the dropdown, or
/// just type any value you want directly into the field (e.g. a custom
/// level your own backend understands). Backed by a plain TextEditingController
/// so whatever is typed is always the source of truth — nothing snaps back.
class _LogLevelField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> presets;
  final bool enabled;

  const _LogLevelField({
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
            color: enabled ? null : Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              controller: controller,
              width: constraints.maxWidth,
              enabled: enabled,
              enableFilter: false,
              requestFocusOnTap: true,
              leadingIcon: const Icon(Icons.tune, size: 20),
              hintText: 'info',
              textStyle: const TextStyle(fontSize: 14),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor:
                enabled ? const Color(0xFFF8F9FA) : Colors.grey.shade100,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                  const BorderSide(color: Color(0xFF2F6FED), width: 1.5),
                ),
              ),
              dropdownMenuEntries: presets
                  .map((p) => DropdownMenuEntry<String>(value: p, label: p))
                  .toList(),
              // Selecting a preset writes it into the controller; typing
              // freely also just writes into the same controller, so both
              // paths end up in the one place _configFromFields() reads from.
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