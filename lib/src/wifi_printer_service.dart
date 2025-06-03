import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_barcode_style.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_qrcode_style.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_text_style.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_printer.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus_example/src/printer_controller.dart';

class WiFiPrintService {
  static const String defaultServerUrl =
      'http://192.168.1.100:5050'; // Fixed port to match server

  String _serverUrl = defaultServerUrl;
  String? _deviceId;
  String? _deviceName;
  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  bool _isRegistered = false;
  PrinterController? printerController; // Made nullable and properly initialized

  String get serverUrl => _serverUrl;
  String? get deviceId => _deviceId;
  bool get isRegistered => _isRegistered;

  // Set custom server URL
  void setServerUrl(String url) {
    log("url changed to $url");
    _serverUrl = url.replaceAll(RegExp(r'/$'), ''); // Remove trailing slash
  }

  // Initialize the service
  Future<bool> initialize() async {
    try {
      // Initialize printer controller
      // printerController = PrinterController(printer: SunmiPrinterPlus());
      await checkServerUrl();
      await _generateDeviceId();
      await _registerDevice();
      _startHeartbeat();
      _startPolling();
      return true;
    } catch (e) {
      print('Failed to initialize WiFi print service: $e');
      return false;
    }
  }

  Future<void> checkServerUrl() async {
    if (_serverUrl.isEmpty) {
      throw Exception('Server URL is not set. Please set the server URL before initializing.');
    }
    final response = await http.get(
      Uri.parse('$_serverUrl/api/check-url'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      log("url is not valid", name: "checkServerUrl");
      throw Exception('Failed to connect to server: ${response.statusCode}');
    }
    // Validate URL format
    final uri = Uri.tryParse(_serverUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw Exception('Invalid server URL: $_serverUrl');
    }
  }

  // Generate unique device ID
  Future<void> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    final networkInfo = NetworkInfo();

    try {
      final androidInfo = await deviceInfo.androidInfo;
      final wifiIP = await networkInfo.getWifiIP();

      _deviceId = '${androidInfo.model}_${androidInfo.id}'.replaceAll(' ', '_');
      _deviceName = '${androidInfo.model} (${wifiIP ?? 'Unknown IP'})';
    } catch (e) {
      // Fallback if device info fails
      _deviceId = 'sunmi_device_${DateTime.now().millisecondsSinceEpoch}';
      _deviceName = 'Sunmi Device';
    }
  }

  // Register device with server
  Future<bool> _registerDevice() async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/register-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': _deviceId,
          'deviceName': _deviceName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isRegistered = data['success'] == true;
        print('Device registered: $_deviceName ($_deviceId)');
        return _isRegistered;
      } else {
        print('Failed to register device: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error registering device: $e');
      return false;
    }
  }

  // Start heartbeat to keep device alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _sendHeartbeat();
    });
  }

  // Send heartbeat to server
  Future<void> _sendHeartbeat() async {
    if (!_isRegistered || _deviceId == null) return;

    try {
      await http.post(
        Uri.parse('$_serverUrl/api/heartbeat/$_deviceId'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Heartbeat failed: $e');
    }
  }

  // Start polling for print jobs
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForPrintJobs();
    });
  }

  // Check for pending print jobs
  Future<void> _checkForPrintJobs() async {
    if (!_isRegistered || _deviceId == null) {
      print('❌ Not registered or no device ID');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/print-jobs/$_deviceId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['jobs'] != null) {
          final jobs = List<Map<String, dynamic>>.from(data['jobs']);
          for (final job in jobs) {
            await _processPrintJob(job);
          }
        }
      }
    } catch (e) {
      print('Error checking for print jobs: $e');
    }
  }

  // Process individual print job
  Future<void> _processPrintJob(Map<String, dynamic> job) async {
    log("Processing print job");
    try {
      final String type = job['type'];
      log(job.toString());
      final Map<String, dynamic> data = job['data'];
      final String source = job['source'] ?? 'unknown';

      print('Processing $type print job from $source');

      // Add "Print from WiFi" label
      if (source == 'wifi') {
        // await printerController?.printText(
        //   '--- Print from WiFi ---',
        //   style: SunmiTextStyle(
        //     fontSize: 16,
        //     align: SunmiPrintAlign.CENTER,
        //     bold: true,
        //   ),
        // );
        // await printerController?.lineWrap(1);

      }

      switch (type) {
        case 'text':
          await _printText(data);
          break;
        case 'qrcode':
          await _printQRCode(data);
          break;
        case 'barcode':
          await _printBarcode(data);
          break;
        case 'image':
          await _printImage(data);
          break;
        default:
          print('Unknown print job type: $type');
      }

      // Add separator line after WiFi prints
      if (source == 'wifi') {
        await printerController?.lineWrap(1);
        await printerController?.printText(
          '------------------------',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
        );
        await printerController?.lineWrap(2);
      }
    } catch (e) {
      print('Error processing print job: $e');
    }
  }

  // Print text job
  Future<void> _printText(Map<String, dynamic> data) async {
    final String text = data['text'] ?? '';
    final int fontSize = data['fontSize'] ?? 24;
    final String alignment = data['alignment'] ?? 'left';

    SunmiPrintAlign sunmiAlign;
    switch (alignment.toLowerCase()) {
      case 'center':
        sunmiAlign = SunmiPrintAlign.CENTER;
        break;
      case 'right':
        sunmiAlign = SunmiPrintAlign.RIGHT;
        break;
      default:
        sunmiAlign = SunmiPrintAlign.LEFT;
    }

    await printerController?.printText(
      text,
      style: SunmiTextStyle(
        fontSize: fontSize,
        align: sunmiAlign,
      ),
    );
    await printerController?.lineWrap(1);
  }

  // Print QR code job
  Future<void> _printQRCode(Map<String, dynamic> data) async {
    final String qrData = data['data'] ?? '';
    final int size = data['size'] ?? 10;
    log(qrData.toString(), name: "qrcode data");

    await printerController?.printQRCode(
        qrData,
        style: SunmiQrcodeStyle(
            align: SunmiPrintAlign.CENTER,
            qrcodeSize: size
        )
    );
    await printerController?.lineWrap(1);
  }

  // Print barcode job
  Future<void> _printBarcode(Map<String, dynamic> data) async {
    final String barcodeData = data['data'] ?? '';
    final String barcodeType = data['type'] ?? 'CODE128';
    final int width = data['width'] ?? 2;
    final int height = data['height'] ?? 100;
    // Convert string type to enum
    SunmiBarcodeType type;
    switch (barcodeType.toUpperCase()) {
      case 'CODE128':
        type = SunmiBarcodeType.CODE128;
        break;
      case 'CODE39':
        type = SunmiBarcodeType.CODE39;
        break;
      case 'UPCA':
        type = SunmiBarcodeType.UPCA;
        break;
      case 'UPCE':
        type = SunmiBarcodeType.UPCE;
        break;
      default:
        type = SunmiBarcodeType.CODE128;
    }

    await printerController?.printBarcode(
        text: barcodeData,
        style: SunmiBarcodeStyle(
            size: width,
            height: height,
            align: SunmiPrintAlign.CENTER,
            textPos: SunmiBarcodeTextPos.TEXT_UNDER
        )
    );
    await printerController?.lineWrap(1);
  }

  // Print image job
  Future<void> _printImage(Map<String, dynamic> data) async {
    final String filename = data['filename'] ?? '';

    if (filename.isEmpty) return;

    try {
      // Download image from server
      final response = await http.get(
        Uri.parse('$_serverUrl/uploads/$filename'),
      );

      if (response.statusCode == 200) {
        final Uint8List imageBytes = response.bodyBytes;
        await SunmiPrinter.printImage(imageBytes);
        await printerController?.lineWrap(1);
      } else {
        print('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error printing image: $e');
    }
  }

  // Test server connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Server connection test failed: $e');
      return false;
    }
  }

  // Get server status
  Future<Map<String, dynamic>?> getServerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to get server status: $e');
    }
    return null;
  }

  // Dispose of resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _pollTimer?.cancel();
    _isRegistered = false;
  }

  // Restart the service (useful for reconnection)
  Future<bool> restart() async {
    dispose();
    await Future.delayed(const Duration(seconds: 2));
    return await initialize();
  }
}