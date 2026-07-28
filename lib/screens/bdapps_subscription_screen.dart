import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/bdapps_models.dart';
import '../services/bdapps_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class BdAppsSubscriptionScreen extends StatefulWidget {
  const BdAppsSubscriptionScreen({super.key});

  @override
  State<BdAppsSubscriptionScreen> createState() =>
      _BdAppsSubscriptionScreenState();
}

class _BdAppsSubscriptionScreenState extends State<BdAppsSubscriptionScreen> {
  final _phoneController = TextEditingController(text: '01812345678');
  final _otpController = TextEditingController();
  final _refNoController = TextEditingController();

  final _serverUrlController = TextEditingController(text: ApiConfig.bdAppsServerUrl);
  final _appIdController = TextEditingController(text: ApiConfig.bdAppsAppId);
  final _passwordController = TextEditingController(text: ApiConfig.bdAppsPassword);
  final _baseUrlController = TextEditingController(text: 'https://developer.bdapps.com');

  late BdAppsService _service;
  bool _isLoading = false;
  String? _statusMessage;
  String? _subscriptionStatus;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  void _initService() {
    final config = BdAppsConfig(
      applicationId: _appIdController.text.trim(),
      password: _passwordController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
    );
    _service = BdAppsService(
      config: config,
      serverUrl: _serverUrlController.text.trim(),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _refNoController.dispose();
    _serverUrlController.dispose();
    _appIdController.dispose();
    _passwordController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackbar('Please enter a phone number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    _initService();
    final res = await _service.checkSubscriptionStatus(phoneNumber: phone);

    setState(() {
      _isLoading = false;
      _isSuccess = res.isSuccess;
      _subscriptionStatus = res.subscriptionStatus;
      _statusMessage =
          'Status Code: ${res.statusCode}\nDetails: ${res.statusDetail}\nStatus: ${res.subscriptionStatus ?? "N/A"}';
    });
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackbar('Please enter a phone number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    _initService();
    final res = await _service.requestOtp(phoneNumber: phone);

    setState(() {
      _isLoading = false;
      _isSuccess = res.isSuccess;
      if (res.isSuccess && res.referenceNo != null) {
        _refNoController.text = res.referenceNo!;
        _statusMessage =
            'OTP Requested Successfully!\nReference No: ${res.referenceNo}';
        _showSnackbar('OTP Sent! Enter code to verify.');
      } else {
        _statusMessage =
            'OTP Request Failed!\nCode: ${res.statusCode}\nDetails: ${res.statusDetail}';
        _showSnackbar('OTP request failed: ${res.statusDetail}', isError: true);
      }
    });
  }

  Future<void> _verifyOtp() async {
    final refNo = _refNoController.text.trim();
    final otp = _otpController.text.trim();

    if (refNo.isEmpty || otp.isEmpty) {
      _showSnackbar('Please enter both Reference No and OTP code',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    _initService();
    final res = await _service.verifyOtp(referenceNo: refNo, otp: otp);

    setState(() {
      _isLoading = false;
      _isSuccess = res.isSuccess;
      _subscriptionStatus = res.subscriptionStatus;
      _statusMessage =
          'OTP Verification Result:\nStatus Code: ${res.statusCode}\nSubscription Status: ${res.subscriptionStatus ?? "N/A"}\nDetails: ${res.statusDetail}';
      if (res.isSuccess) {
        _showSnackbar('OTP Verified successfully!');
      } else {
        _showSnackbar('OTP Verification failed: ${res.statusDetail}',
            isError: true);
      }
    });
  }

  Future<void> _subscribe() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackbar('Please enter a phone number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    _initService();
    final res = await _service.subscribeUser(phoneNumber: phone);

    setState(() {
      _isLoading = false;
      _isSuccess = res.isSuccess;
      _subscriptionStatus = res.subscriptionStatus;
      _statusMessage =
          'Subscription Request Result:\nCode: ${res.statusCode}\nSubscription Status: ${res.subscriptionStatus ?? "N/A"}\nDetails: ${res.statusDetail}';
    });
  }

  Future<void> _unsubscribe() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackbar('Please enter a phone number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    _initService();
    final res = await _service.unsubscribeUser(phoneNumber: phone);

    setState(() {
      _isLoading = false;
      _isSuccess = res.isSuccess;
      _subscriptionStatus = res.subscriptionStatus;
      _statusMessage =
          'Unsubscription Result:\nCode: ${res.statusCode}\nSubscription Status: ${res.subscriptionStatus ?? "N/A"}\nDetails: ${res.statusDetail}';
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primaryGreen,
      ),
    );
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('BDApps Connection Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PHP Proxy Server Mode (Recommended)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'PHP Backend Server URL',
                  hintText: 'e.g. https://your-server.com/api',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Direct BDApps TAP API Mode (Fallback)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _appIdController,
                decoration: const InputDecoration(
                  labelText: 'Application ID',
                  hintText: 'APP_000000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password / API Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Direct BDApps Base URL',
                  hintText: 'https://developer.bdapps.com',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _initService();
              });
              Navigator.pop(ctx);
              _showSnackbar('BDApps Settings updated.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedPreview =
        BdAppsService.formatSubscriberId(_phoneController.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Text(
          'BDApps Integration',
          style: AppTypography.headingMedium.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'API Credentials',
            onPressed: _showConfigDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _service.isServerProxyMode
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _service.isServerProxyMode
                      ? AppColors.primaryGreen
                      : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _service.isServerProxyMode ? Icons.dns : Icons.cloud_outlined,
                    color: _service.isServerProxyMode
                        ? AppColors.primaryGreen
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _service.isServerProxyMode
                          ? 'PHP Proxy Server Mode: ${_service.effectiveServerUrl}'
                          : 'Direct BDApps TAP API Mode (https://developer.bdapps.com)',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Header card
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phonelink_ring,
                            color: AppColors.primaryGreen, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Subscriber MSISDN',
                          style: AppTypography.headingSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. 01812345678',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'BDApps Payload Format: $formattedPreview',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Subscription & Status Actions
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Operations',
                      style: AppTypography.headingSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _checkStatus,
                          icon: const Icon(Icons.verified_user),
                          label: const Text('Check Status'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _requestOtp,
                          icon: const Icon(Icons.sms),
                          label: const Text('Request OTP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreenLight,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _subscribe,
                          icon: const Icon(Icons.add_task),
                          label: const Text('Direct Subscribe'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _unsubscribe,
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Unsubscribe'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // OTP Verification Card
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.password,
                            color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          'OTP Verification',
                          style: AppTypography.headingSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _refNoController,
                      decoration: InputDecoration(
                        labelText: 'Reference Number',
                        hintText: 'e.g. 213561321321613',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'OTP Code',
                        hintText: '6-digit OTP code',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _verifyOtp,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Verify OTP & Activate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress / Status Output
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              )
            else if (_statusMessage != null)
              Card(
                elevation: 0,
                color: _isSuccess
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : AppColors.danger.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _isSuccess ? AppColors.primaryGreen : AppColors.danger,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isSuccess
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: _isSuccess
                                ? AppColors.primaryGreen
                                : AppColors.danger,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isSuccess ? 'Response Success' : 'Response Error',
                            style: AppTypography.headingSmall.copyWith(
                              color: _isSuccess
                                  ? AppColors.primaryGreen
                                  : AppColors.danger,
                            ),
                          ),
                          const Spacer(),
                          if (_subscriptionStatus != null)
                            Chip(
                              label: Text(
                                _subscriptionStatus!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: _subscriptionStatus!
                                      .toUpperCase()
                                      .startsWith('REGISTERED')
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage!,
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
