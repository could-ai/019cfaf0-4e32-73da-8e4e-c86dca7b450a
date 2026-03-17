import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'जन्म विवरण (Birth Details)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const BirthDetailsScreen(),
      },
    );
  }
}

class BirthDetailsScreen extends StatefulWidget {
  const BirthDetailsScreen({super.key});

  @override
  State<BirthDetailsScreen> createState() => _BirthDetailsScreenState();
}

class _BirthDetailsScreenState extends State<BirthDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _cardKey = GlobalKey();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  bool _isSaved = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // लोड गर्ने फङ्सन (Load saved data)
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name');
    final place = prefs.getString('place');
    final dateStr = prefs.getString('date');
    final timeStr = prefs.getString('time');

    if (name != null && place != null && dateStr != null && timeStr != null) {
      setState(() {
        _nameController.text = name;
        _placeController.text = place;
        _selectedDate = DateTime.parse(dateStr);
        
        final timeParts = timeStr.split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(timeParts[0]), 
          minute: int.parse(timeParts[1])
        );
        _isSaved = true;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  // सेभ गर्ने फङ्सन (Save data)
  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('कृपया जन्म मिति र समय छान्नुहोस्!')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameController.text);
      await prefs.setString('place', _placeController.text);
      await prefs.setString('date', _selectedDate!.toIso8601String());
      await prefs.setString('time', '${_selectedTime!.hour}:${_selectedTime!.minute}');

      setState(() {
        _isSaved = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('तपाईंको विवरण सुरक्षित भयो!')),
        );
      }
    }
  }

  // परिमार्जन गर्ने फङ्सन (Edit data)
  void _editData() {
    setState(() {
      _isSaved = false;
    });
  }

  // मिति छान्ने (Pick Date)
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // समय छान्ने (Pick Time)
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // कार्डलाई फोटोमा परिणत गर्ने (Capture Card as Image)
  Future<Uint8List?> _captureCard() async {
    try {
      RenderRepaintBoundary boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing image: $e");
      return null;
    }
  }

  // PDF डाउनलोड गर्ने (Download PDF)
  Future<void> _downloadPDF() async {
    final Uint8List? imageBytes = await _captureCard();
    if (imageBytes == null) return;

    final doc = pw.Document();
    final imagePdf = pw.MemoryImage(imageBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(imagePdf),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Janma_Bibaran.pdf',
    );
  }

  // PNG डाउनलोड/सेयर गर्ने (Download/Share PNG)
  Future<void> _downloadPNG() async {
    final Uint8List? imageBytes = await _captureCard();
    if (imageBytes == null) return;

    await Printing.sharePdf(
      bytes: imageBytes, 
      filename: 'Janma_Bibaran.png',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('जन्म विवरण', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepOrange.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: _isSaved ? _buildDisplayCard() : _buildInputForm(),
            ),
          ),
        ),
      ),
    );
  }

  // विवरण भर्ने फारम (Input Form)
  Widget _buildInputForm() {
    return Card(
      elevation: 8,
      shadowColor: Colors.deepOrange.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepOrange, size: 40),
              const SizedBox(height: 16),
              const Text(
                'आफ्नो विवरण भर्नुहोस्',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
              const SizedBox(height: 24),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'पूरा नाम',
                  prefixIcon: const Icon(Icons.person, color: Colors.deepOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty ? 'कृपया नाम लेख्नुहोस्' : null,
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'जन्म मिति',
                    prefixIcon: const Icon(Icons.calendar_month, color: Colors.deepOrange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _selectedDate == null 
                        ? 'मिति छान्नुहोस्' 
                        : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                    style: TextStyle(color: _selectedDate == null ? Colors.grey.shade600 : Colors.black, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time Picker
              InkWell(
                onTap: _pickTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'जन्म समय',
                    prefixIcon: const Icon(Icons.access_time, color: Colors.deepOrange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _selectedTime == null 
                        ? 'समय छान्नुहोस्' 
                        : _selectedTime!.format(context),
                    style: TextStyle(color: _selectedTime == null ? Colors.grey.shade600 : Colors.black, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Place Field
              TextFormField(
                controller: _placeController,
                decoration: InputDecoration(
                  labelText: 'जन्म स्थान',
                  prefixIcon: const Icon(Icons.location_on, color: Colors.deepOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty ? 'कृपया जन्म स्थान लेख्नुहोस्' : null,
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text('सेभ गर्नुहोस्', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // सुन्दर कार्ड देखाउने (Display Card)
  Widget _buildDisplayCard() {
    return Column(
      children: [
        // The RepaintBoundary wraps the widget we want to capture as an image
        RepaintBoundary(
          key: _cardKey,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.deepOrange.shade300, width: 6),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 5,
                )
              ],
              image: DecorationImage(
                image: const NetworkImage('https://www.transparenttextures.com/patterns/cream-paper.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.9), BlendMode.lighten),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("ॐ", style: TextStyle(fontSize: 50, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  "जन्म विवरण",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
                const SizedBox(height: 8),
                Divider(color: Colors.deepOrange.shade200, thickness: 2),
                const SizedBox(height: 20),
                
                _buildDetailRow(Icons.person, "नाम", _nameController.text),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.calendar_month, "जन्म मिति", DateFormat('yyyy-MM-dd').format(_selectedDate!)),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.access_time, "जन्म समय", _selectedTime!.format(context)),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.location_on, "जन्म स्थान", _placeController.text),
                
                const SizedBox(height: 30),
                Divider(color: Colors.deepOrange.shade200, thickness: 2),
                const SizedBox(height: 10),
                const Text(
                  "शुभम भवतु",
                  style: TextStyle(fontSize: 22, color: Colors.deepOrange, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 30),
        
        // Action Buttons
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildActionButton(
              icon: Icons.edit,
              label: 'सच्याउनुहोस्',
              color: Colors.blue.shade700,
              onPressed: _editData,
            ),
            _buildActionButton(
              icon: Icons.picture_as_pdf,
              label: 'PDF डाउनलोड',
              color: Colors.red.shade700,
              onPressed: _downloadPDF,
            ),
            _buildActionButton(
              icon: Icons.image,
              label: 'PNG डाउनलोड',
              color: Colors.green.shade700,
              onPressed: _downloadPNG,
            ),
          ],
        ),
      ],
    );
  }

  // कार्ड भित्रको विवरण देखाउने डिजाइन (Detail Row UI)
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.deepOrange, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  // तलका बटनहरूको डिजाइन (Action Button UI)
  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 3,
      ),
    );
  }
}
