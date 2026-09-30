import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/print_bridge_config.dart';
import '../core/constants/api_constant.dart';
import '../provider/print_bridge_form_provider.dart';
import '../resources/custom_color.dart';
import '../resources/custom_widgets.dart';


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

  Future<void> _discoverPrinters() async {
    final provider = context.read<PrintBridgeProvider>();
    await provider.saveConfig(_configFromFields());
    await provider.discoverPrinters();
    if (!mounted) return;
    if (provider.discoveredPrinters.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Found ${provider.discoveredPrinters.length} printer(s). Tap a chip to select.'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printers found on local network.'),
        ),
      );
    }
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

  // ===========================================================================
  // BUILD (UI only below this line)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrintBridgeProvider>();

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            if (!_initializedFromProvider) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    children: [
                      const AppHeader(),
                      const SizedBox(height: 24),
                      if (isWide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  flex: 5, child: _buildFormCard(provider)),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 4,
                                child: _buildStatusColumn(provider,
                                    expandLog: true),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            _buildFormCard(provider),
                            const SizedBox(height: 16),
                            _buildStatusColumn(provider, expandLog: false),
                          ],
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'RestroSanjalBridge',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard(PrintBridgeProvider provider) {
    // Poll interval and log level are fixed at their defaults (3000ms,
    // info) and are never user-editable.
    const behaviorFieldsEnabled = false;

    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionTitle('Server'),
            const SizedBox(height: 14),
            AppLabeledField(
              label: 'Server URL',
              required: true,
              hint: ApiConstant.baseUrl,
              controller: _serverUrlCtrl,
              icon: Icons.dns_outlined,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Server URL is required'
                  : null,
            ),
            const SizedBox(height: 16),
            AppLabeledField(
              label: 'Bridge Token',
              required: true,
              hint: 'paste token ',
              controller: _bridgeTokenCtrl,
              icon: Icons.vpn_key_outlined,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Bridge Token is required'
                  : null,
            ),
            const SizedBox(height: 16),
            AppLabeledField(
              label: 'Client ID',
              labelHint: '(Optional — defaults to device)',
              hint: 'Optional — defaults to device name',
              controller: _clientIdCtrl,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),
            const AppSectionTitle('Printer'),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppLabeledField(
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
                  child: AppLabeledField(
                    label: 'Port',
                    hint: '9100',
                    controller: _printerPortCtrl,
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppPillButton(
                  onPressed: provider.isDiscovering ? null : _discoverPrinters,
                  icon: provider.isDiscovering
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.green),
                  )
                      : const Icon(Icons.radar, size: 16),
                  label: provider.isDiscovering
                      ? 'Scanning...'
                      : 'Discover printers',
                ),
                AppPillButton(
                  onPressed: _testPrinter,
                  icon: const Icon(Icons.wifi_tethering, size: 16),
                  label: 'Test connection',
                ),
                AppPillButton(
                  onPressed: _testPrintSample,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: 'Test print',
                ),
              ],
            ),
            if (provider.isDiscovering &&
                provider.discoveryProgress.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                provider.discoveryProgress,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.progress,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (provider.discoveredPrinters.isNotEmpty) ...[
              const SizedBox(height: 12),
              DiscoveredPrintersBox(
                printers: provider.discoveredPrinters,
                onSelected: (ip) {
                  setState(() {
                    _printerIpCtrl.text = ip;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Selected printer IP: $ip'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),
            const AppSectionTitle('Behavior'),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppLabeledField(
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
                  child: AppLogLevelField(
                    controller: _logLevelCtrl,
                    presets: _logLevelPresets,
                    enabled: behaviorFieldsEnabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const AppInfoNote(
              'Poll interval and log level are fixed at their defaults',
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    onPressed: provider.isBusy ? null : _saveOnly,
                    label: 'Save',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppGradientButton(
                    onPressed: provider.isBusy
                        ? null
                        : (provider.isConnected
                        ? () => provider.disconnect()
                        : _connect),
                    colors: provider.isConnected
                        ? AppColors.disconnectGradient
                        : AppColors.connectGradient,
                    icon: provider.isBusy
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : Icon(
                      provider.isConnected
                          ? Icons.link_off
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    label: provider.isConnected ? 'Disconnect' : 'Connect',
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
        StatusTile(
          status: provider.status,
          jobsPrinted: provider.jobsPrinted,
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
    final logs = provider.logs;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, size: 20, color: AppColors.green),
              const SizedBox(width: 8),
              const Text(
                'Activity Log',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.muted),
                onPressed: () => provider.clearLogs(),
              ),
            ],
          ),
          const Divider(height: 8, color: AppColors.border),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.terminalBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: logs.isEmpty
                  ? const Center(
                child: Text(
                  'No activity yet',
                  style: TextStyle(color: AppColors.subtle),
                ),
              )
                  : ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, i) => LogTile(entry: logs[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}