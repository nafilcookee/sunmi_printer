import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sunmi_printer_demo/src/printer_controller.dart';
import 'package:sunmi_printer_demo/src/status_controller.dart';
import 'package:sunmi_printer_demo/src/wifi_printer_service.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_barcode_style.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_qrcode_style.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_printer.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunmi Printer with WiFi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PrinterHomePage(),
    );
  }
}

class PrinterHomePage extends StatefulWidget {
  @override
  _PrinterHomePageState createState() => _PrinterHomePageState();
}

class _PrinterHomePageState extends State<PrinterHomePage> {
  bool _isConnected = false;
  bool _wifiServiceRunning = false;
  String _serverUrl = 'http://192.168.29.177:5050';
  final WiFiPrintService _wifiService = WiFiPrintService();
  late final StatusController statusController;
  late final PrinterController printerController;


  final TextEditingController _textController = TextEditingController();
  final TextEditingController _qrController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    statusController = StatusController(printer: SunmiPrinterPlus());
    printerController = PrinterController(printer: SunmiPrinterPlus());
    _serverUrlController.text = _serverUrl;
    _initializePrinter();
  }

  @override
  void dispose() {
    _wifiService.dispose();
    _textController.dispose();
    _qrController.dispose();
    _barcodeController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _initializePrinter() async {
    await SunmiPrinter.bindingPrinter();
    await _checkPrinterStatus();
  }

  Future<void> _checkPrinterStatus() async {
    try {
      final result = await statusController.getStatus();
      setState(() {
        _isConnected = result == 1;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _startWiFiService() async {
    _wifiService.setServerUrl(_serverUrl);
    final success = await _wifiService.initialize();

    setState(() {
      _wifiServiceRunning = success;
    });

    if (success) {
      _showSnackBar('WiFi service started successfully', Colors.green);
    } else {
      _showSnackBar('Failed to start WiFi service', Colors.red);
    }
  }

  Future<void> _stopWiFiService() async {
    _wifiService.dispose();
    setState(() {
      _wifiServiceRunning = false;
    });
    _showSnackBar('WiFi service stopped', Colors.orange);
  }

  Future<void> _testServerConnection() async {
    _wifiService.setServerUrl(_serverUrl);
    final connected = await _wifiService.testConnection();

    if (connected) {
      _showSnackBar('Server connection successful', Colors.green);
    } else {
      _showSnackBar('Server connection failed', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _printText() async {
    if (_textController.text.isEmpty) {
      _showSnackBar('Please enter text to print', Colors.orange);
      return;
    }

    try {
      await SunmiPrinter.printText(_textController.text);
      await SunmiPrinter.lineWrap(2);
      _showSnackBar('Text printed successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to print text: $e', Colors.red);
    }
  }

  Future<void> _printQRCode() async {
    if (_qrController.text.isEmpty) {
      _showSnackBar('Please enter QR code data', Colors.orange);
      return;
    }

    try {
      // await SunmiPrinter.printQRCode(
      //   _qrController.text,
      //   size: 200,
      //   align: SunmiPrintAlign.CENTER,
      // );
      await printerController.printQRCode(
          _qrController.text,
          style: SunmiQrcodeStyle(
              qrcodeSize: 200,
              align: SunmiPrintAlign.CENTER
          )
      );
      await printerController.lineWrap(1);
      await SunmiPrinter.lineWrap(2);
      _showSnackBar('QR code printed successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to print QR code: $e', Colors.red);
    }
  }

  Future<void> _printBarcode() async {
    if (_barcodeController.text.isEmpty) {
      _showSnackBar('Please enter barcode data', Colors.orange);
      return;
    }

    try {
      // await SunmiPrinter.printBarCode(
      //   _barcodeController.text,
      //   barcodeType: SunmiBarcodeType.CODE128,
      //   height: 100,
      //   width: 2,
      //   textPosition: SunmiBarcodeTextPos.TEXT_UNDER,
      // );
      // await SunmiPrinter.lineWrap(2);
      await printerController.printBarcode(text: _barcodeController.text,
          style: SunmiBarcodeStyle(
              height: 100, size: 2, textPos: SunmiBarcodeTextPos.TEXT_UNDER));
      _showSnackBar('Barcode printed successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to print barcode: $e', Colors.red);
    }
  }

  Future<void> _printImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();

      await SunmiPrinter.printImage(imageBytes);
      await SunmiPrinter.lineWrap(2);
      _showSnackBar('Image printed successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to print image: $e', Colors.red);
    }
  }

  Future<void> _printLine() async {
    try {
      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);
      _showSnackBar('Line printed successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to print line: $e', Colors.red);
    }
  }

  void _updateServerUrl() {
    setState(() {
      _serverUrl = _serverUrlController.text;
    });
    _showSnackBar('Server URL updated', Colors.blue);
  }

  Widget _buildConnectionStatus() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text('Printer: ${_isConnected ? 'Connected' : 'Disconnected'}'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _wifiServiceRunning ? Icons.wifi : Icons.wifi_off,
                  color: _wifiServiceRunning ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text('WiFi Service: ${_wifiServiceRunning
                    ? 'Running'
                    : 'Stopped'}'),
              ],
            ),
            if (_wifiServiceRunning && _wifiService.deviceId != null) ...[
              SizedBox(height: 4),
              Text(
                'Device ID: ${_wifiService.deviceId}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWiFiControls() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WiFi Print Server',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.29.177:5050',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.save),
                  onPressed: _updateServerUrl,
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _wifiServiceRunning
                        ? _stopWiFiService
                        : _startWiFiService,
                    icon: Icon(
                        _wifiServiceRunning ? Icons.stop : Icons.play_arrow),
                    label: Text(
                        _wifiServiceRunning ? 'Stop Service' : 'Start Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _wifiServiceRunning ? Colors.red : Colors
                          .green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _testServerConnection,
                  icon: Icon(Icons.network_check),
                  label: Text('Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintControls() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Direct Print Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Text to Print',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.print),
                  onPressed: _printText,
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _qrController,
              decoration: InputDecoration(
                labelText: 'QR Code Data',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.qr_code),
                  onPressed: _printQRCode,
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode Data',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  onPressed: _printBarcode,
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _printImage,
                    icon: Icon(Icons.image),
                    label: Text('Print Image'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _printLine,
                    icon: Icon(Icons.horizontal_rule),
                    label: Text('Print Line'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sunmi Printer with WiFi'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _checkPrinterStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildConnectionStatus(),
            SizedBox(height: 16),
            _buildWiFiControls(),
            SizedBox(height: 16),
            _buildPrintControls(),
          ],
        ),
      ),
    );
  }
}