import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/helpers/sunmi_helper.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_barcode_style.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_qrcode_style.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_text_style.dart';
import 'package:sunmi_printer_plus/core/types/sunmi_column.dart';
import 'package:sunmi_printer_plus/core/types/sunmi_text.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus_example/src/cash_drawer.dart';
import 'package:sunmi_printer_plus_example/src/lcd_controller.dart';
import 'package:sunmi_printer_plus_example/src/printer_controller.dart';
import 'package:sunmi_printer_plus_example/src/status_controller.dart';

void main() {
  runApp(const AppWrapper());
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunmi Printer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyApp(), // ⬅️ your stateful app goes here
    );
  }
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  PrinterStatus statusPrinter = PrinterStatus.UNKNOWN;
  String version = "";
  String idPrinter = "";
  String paperPrinter = "";
  String typePrinter = "";
  String cashDrawerStatus = "Close";
  bool isLoading = true;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();
  late final PrinterController printerController;
  late final StatusController statusController;
  late final LcdController lcdController;
  late final CashDrawer cashDrawer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final SunmiPrinterPlus sunmiPrinterPlus = SunmiPrinterPlus();
    printerController = PrinterController(printer: sunmiPrinterPlus);
    statusController = StatusController(printer: sunmiPrinterPlus);
    lcdController = LcdController(printer: sunmiPrinterPlus);
    cashDrawer = CashDrawer(printer: sunmiPrinterPlus);

    _initializePrinter();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializePrinter() async {
    try {
      final results = await Future.wait([
        statusController.getVersion(),
        statusController.getPaper(),
        statusController.getId(),
        statusController.getType(),
        statusController.getStatus(),
      ]);
      log(results.toString(), name: "initialize printer");
      setState(() {
        version = results[0].toString();
        paperPrinter = results[1].toString();
        idPrinter = results[2].toString();
        typePrinter = results[3].toString();
        statusPrinter = results[4] as PrinterStatus;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printSelectedImage() async {
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final Uint8List imageBytes = await selectedImage!.readAsBytes();
      await printerController.printImage(
        image: imageBytes,
        align: SunmiPrintAlign.CENTER,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image printed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (statusPrinter) {
      case PrinterStatus.READY:
        return Colors.green;
      case PrinterStatus.ERR_STEP:
        return Colors.red;
      case PrinterStatus.ERR_PAPER_OUT:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (statusPrinter) {
      case PrinterStatus.READY:
        return Icons.check_circle;
      case PrinterStatus.ERR_STEP:
        return Icons.error;
      case PrinterStatus.ERR_PAPER_OUT:
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunmi Printer Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Sunmi Printer Pro',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF8B5FBF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: isLoading
            ? _buildLoadingScreen()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 24),
              _buildPrinterInfoCard(),
              const SizedBox(height: 24),
              _buildActionsSection(),
              const SizedBox(height: 24),
              _buildTextPrintingSection(),
              const SizedBox(height: 24),
              _buildImagePrintingSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.print,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Initializing Printer...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _statusIcon,
                    color: _statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Printer Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusPrinter.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: _statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final status = await statusController.getStatus();
                    setState(() {
                      statusPrinter = status;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Printer Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.info_outline, 'Version', version),
            _buildInfoRow(Icons.fingerprint, 'ID', idPrinter),
            _buildInfoRow(Icons.description, 'Paper', paperPrinter),
            _buildInfoRow(Icons.print, 'Type', typePrinter),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildActionButton(
                  icon: Icons.qr_code,
                  label: 'QR Code',
                  color: Colors.blue,
                  onPressed: () async {
                    await printerController.printQRCode(
                      "I love flutter",
                      style: SunmiQrcodeStyle(
                        align: SunmiPrintAlign.LEFT,
                        errorLevel: SunmiQrcodeLevel.LEVEL_H,
                        qrcodeSize: 3,
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Barcode',
                  color: Colors.green,
                  onPressed: () async {
                    await printerController.printBarcode(
                      text: "1234567890",
                      style: SunmiBarcodeStyle(
                        align: SunmiPrintAlign.RIGHT,
                        height: 100,
                        size: 2,
                        type: SunmiBarcodeType.CODABAR,
                        textPos: SunmiBarcodeTextPos.NO_TEXT,
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.horizontal_rule,
                  label: 'Print Line',
                  color: Colors.orange,
                  onPressed: () async {
                    await printerController.line(style: SunmiPrintLine.SOLID);
                  },
                ),
                _buildActionButton(
                  icon: Icons.content_cut,
                  label: 'Cut Paper',
                  color: Colors.red,
                  onPressed: () async {
                    await printerController.cutPaper();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPrintingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Printing Options',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildTextButton('Left Align', () async {
                  await printerController.printCustomText(
                    sunmiText: SunmiText(
                      text: 'I love flutter',
                      style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
                    ),
                  );
                }),
                _buildTextButton('Right Align', () async {
                  await printerController.printCustomText(
                    sunmiText: SunmiText(
                      text: 'I love flutter',
                      style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
                    ),
                  );
                }),
                _buildTextButton('Bold Text', () async {
                  await printerController.printCustomText(
                    sunmiText: SunmiText(
                      text: 'I love flutter',
                      style: SunmiTextStyle(bold: true),
                    ),
                  );
                }),
                _buildTextButton('Reversed', () async {
                  await printerController.printCustomText(
                    sunmiText: SunmiText(
                      text: 'I love flutter',
                      style: SunmiTextStyle(reverse: true),
                    ),
                  );
                }),
                _buildTextButton('Small Font', () async {
                  await printerController.printCustomText(
                    sunmiText: SunmiText(
                      text: 'I love flutter',
                      style: SunmiTextStyle(fontSize: 1),
                    ),
                  );
                }),
                _buildTextButton('Large Font', () async {
                  await printerController.printCustomText(
                    sunmiText: SunmiText(
                      text: 'Flutter',
                      style: SunmiTextStyle(fontSize: 96),
                    ),
                  );
                }),
                _buildReceiptButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
      ),
      child: Text(label),
    );
  }

  Widget _buildReceiptButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        await _printReceipt();
      },
      icon: const Icon(Icons.receipt_long),
      label: const Text('Print Receipt'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _printReceipt() async {
    await printerController.printText(
      'Payment Receipt',
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
      ),
    );
    await printerController.line();
    await printerController.lineWrap(2);

    // Print receipt items...
    final items = [
      {'name': 'Fries', 'qty': '4x', 'price': '3.00', 'total': '12.00'},
      {'name': 'Strawberry', 'qty': '1x', 'price': '24.44', 'total': '24.44'},
      {'name': 'Soda', 'qty': '1x', 'price': '1.99', 'total': '1.99'},
    ];

    // Header
    await printerController.printRow(cols: [
      SunmiColumn(text: 'Name', width: 12),
      SunmiColumn(text: 'Qty', width: 6),
      SunmiColumn(text: 'Price', width: 6),
      SunmiColumn(text: 'Total', width: 6),
    ]);

    // Items
    for (final item in items) {
      await printerController.printRow(cols: [
        SunmiColumn(text: item['name']!, width: 12),
        SunmiColumn(text: item['qty']!, width: 6),
        SunmiColumn(text: item['price']!, width: 6),
        SunmiColumn(text: item['total']!, width: 6),
      ]);
    }

    await printerController.line();
    await printerController.printRow(cols: [
      SunmiColumn(text: 'TOTAL', width: 25),
      SunmiColumn(text: '38.43', width: 5),
    ]);

    await printerController.printText(
      'Transaction QR Code',
      style: SunmiTextStyle(
        align: SunmiPrintAlign.CENTER,
        bold: true,
        fontSize: 30,
      ),
    );
    await printerController.printQRCode('https://github.com/brasizza/sunmi_printer');
    await printerController.lineWrap(2);
  }

  Widget _buildImagePrintingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image Printing',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Image preview section
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      selectedImage!,
                      fit: BoxFit.contain,
                    ),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No image selected',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Select Image" to choose a photo',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showImageSourceDialog(context);
                          },
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Select Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:(){
                          if(  selectedImage != null) {
                            _printSelectedImage();
                        }
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Print Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Web image printing option
                const Divider(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    String url = 'https://avatars.githubusercontent.com/u/14101776?s=100';
                    try {
                      Uint8List assetImage = (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
                      await printerController.printImage(
                        image: assetImage,
                        align: SunmiPrintAlign.CENTER,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Web image printed successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error printing web image: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.language),
                  label: const Text('Print Sample Web Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                if (selectedImage != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedImage = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Selection'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}