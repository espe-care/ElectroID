import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ===== Modelo JSON =====
class Activo {
  final String id;
  final String codOrg;
  final String? descripcion;
  final String? modelo;
  final String? numeroSerie;        // "NUMERO SERIE" o "NUMERO_SERIE"
  final String? fechaAlta;
  final String? fechaPlanificada;
  final String? departamento;
  final String? fechaUltimoPreventivo;

  Activo({
    required this.id,
    required this.codOrg,
    this.descripcion,
    this.modelo,
    this.numeroSerie,
    this.fechaAlta,
    this.fechaPlanificada,
    this.departamento,
    this.fechaUltimoPreventivo,
  });

   factory Activo.fromJson(Map<String, dynamic> json) {
    String? pickAny(Map<String, dynamic> j, List<String> keys) {
      for (final k in keys) {
        if (j.containsKey(k) && j[k] != null) return j[k].toString();
      }
      return null;
    }

    return Activo(
      id: (json['ID'] ?? '').toString(),
      codOrg: (json['COD_ORG'] ?? '').toString(),
      descripcion: json['DESCRIPCION']?.toString(),
      modelo: json['MODELO']?.toString(),
      numeroSerie: (json['NUMERO SERIE'] ?? json['NUMERO_SERIE'])?.toString(),
      fechaAlta: json['FECHA_ALTA']?.toString(),
      fechaPlanificada: json['FECHA_PLANIFICADA']?.toString(),
      departamento: json['DEPARTAMENTO']?.toString(),
      // Acepta variantes y el typo "RPEVENTIVO"
      fechaUltimoPreventivo: pickAny(json, [
        'FECHA_ULTIMO_PREVENTIVO',
        'FECHA ULTIMO PREVENTIVO',
        'FECHA ULTIMO RPEVENTIVO', // typo del ejemplo
        'FECHA_ULTIMO_RPEVENTIVO',
      ]),
    );
  }
}

void main() => runApp(const ElectroNFCApp());

class ElectroNFCApp extends StatelessWidget {
  const ElectroNFCApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0033A0);
    const bgBlue = Color(0xFFC8D7EA);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElectroID',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bgBlue,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 20),
          bodyMedium: TextStyle(fontSize: 18),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const double kSpinnerFontSize = 22;
  static const double kHeaderFontSize = 18;
  static const double kFieldLabelFontSize = 16;

  final String jsonUrl =
      'https://raw.githubusercontent.com/espe-care/activos-nfc/main/activos_visa.json';

  List<Activo> _activos = [];
  List<String> _organizaciones = [];
  String? _orgSeleccionada;
  bool _isLoading = true;
  String? _error;

  // NFC
  bool _isNfcReading = false;

  String encabezadoText = 'Esperando acción...';
  String descripcionText = 'Descripción:';
  String modeloText = 'Modelo:';
  String serieText = 'N° Serie:';
  String altaText = 'Fecha de Alta:';
  String departamentoText = 'Departamento:';
  String planificadaText = 'Fecha Planificada:';
  String ultimoPrevText = 'Fecha Último Preventivo:';


  @override
  void initState() {
    super.initState();
    _cargarActivos();
  }

  Future<void> _cargarActivos() async {
    try {
      final resp = await http.get(Uri.parse(jsonUrl));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final data = json.decode(resp.body) as List<dynamic>;
      final parsed = data
          .map((e) => Activo.fromJson(e as Map<String, dynamic>))
          .where((a) => a.id.isNotEmpty && a.codOrg.isNotEmpty)
          .toList();

      final orgs = parsed.map((a) => a.codOrg.trim()).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() {
        _activos = parsed;
        _organizaciones = orgs;
        _orgSeleccionada = orgs.isNotEmpty ? orgs.first : null;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'No se pudieron cargar los datos ($e)';
      });
    }
  }

  void _buscarPorIdYOrg(String idLeido) {
    final id = idLeido.trim();
    final org = _orgSeleccionada?.trim().toLowerCase();

    final encontrado = _activos.firstWhere(
      (a) => a.id.trim() == id && a.codOrg.trim().toLowerCase() == org,
      orElse: () => Activo(id: '', codOrg: ''),
    );

    if (encontrado.id.isEmpty) {
      setState(() {
        descripcionText =
            'Descripción: ID no encontrado para organización ${_orgSeleccionada ?? '-'}';
        modeloText = 'Modelo:';
        serieText = 'N° Serie:';
        altaText = 'Fecha de Alta:';
        departamentoText = 'Departamento:';
        planificadaText = 'Fecha Planificada:';
        ultimoPrevText = 'Fecha Último Preventivo:';
      });
      return;
    }

    setState(() {
      descripcionText = 'Descripción: ${_safe(encontrado.descripcion)}';
      modeloText = 'Modelo: ${_safe(encontrado.modelo)}';
      serieText = 'N° Serie: ${_safe(encontrado.numeroSerie)}';
      altaText = 'Fecha de Alta: ${_fecha(encontrado.fechaAlta)}';
      departamentoText = 'Departamento: ${_safe(encontrado.departamento)}';
      planificadaText = 'Fecha Planificada: ${_fecha(encontrado.fechaPlanificada)}';
      ultimoPrevText = 'Fecha Último Preventivo: ${_fecha(encontrado.fechaUltimoPreventivo)}';
    });
  }

  String _safe(String? v) =>
      (v == null || v.trim().isEmpty) ? 'No disponible' : v.trim();

  String _fecha(String? iso) {
    if (iso == null || iso.isEmpty) return 'No disponible';
    try {
      final base = iso.split('T').first;
      final p = base.split('-');
      return (p.length == 3) ? '${p[2]}/${p[1]}/${p[0]}' : iso;
    } catch (_) {
      return iso;
    }
  }

  // ---------- Reutiliza misma búsqueda al leer un ID por NFC
  void _onIdRead(String id) {
    setState(() => encabezadoText = 'ID Activo (NFC): $id');
    _buscarPorIdYOrg(id);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('NFC leído: $id')));
    }
  }

  // ---------- LECTURA NFC: NDEF Text
  Future<void> _scanNfc() async {
    if (_isNfcReading) return;
    setState(() => _isNfcReading = true);

    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      if (availability == NFCAvailability.not_supported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('NFC no soportado en este dispositivo')),
          );
        }
        return;
      }
      if (availability == NFCAvailability.disabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activa NFC para leer etiquetas')),
          );
        }
        return;
      }

      setState(() => encabezadoText = 'Leyendo NFC… acerca la etiqueta');

      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosAlertMessage: 'Acerca la etiqueta NFC',
      );

      if (tag.ndefAvailable == true) {
        final recs = await FlutterNfcKit.readNDEFRecords(cached: false);
        String? idText;
        for (final r in recs) {
          idText = _extractTextFromNdef(r); // r es dinámico
          if (idText != null && idText.trim().isNotEmpty) {
            idText = idText.trim();
            break;
          }
        }

        if (idText != null && idText.isNotEmpty) {
          _onIdRead(idText);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('La etiqueta NDEF no contiene texto')),
            );
          }
          setState(() => encabezadoText = 'NFC detectado (sin texto)');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La etiqueta no expone NDEF')),
          );
        }
        setState(() => encabezadoText = 'NFC detectado (sin NDEF)');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error NFC: $e')));
      }
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      if (mounted) setState(() => _isNfcReading = false);
    }
  }

  // ---------- Decodificador NDEF Text (UTF-8 / UTF-16) sin tipos del plugin
  String? _extractTextFromNdef(dynamic r) {
    final typeField = r?.type;
    final payloadField = r?.payload;

    if (typeField is! List && typeField is! Uint8List) return null;
    if (payloadField is! List && payloadField is! Uint8List) return null;

    // Solo registros Well-Known 'T' (Text)
    final List<int> typeBytes =
        typeField is Uint8List ? typeField : List<int>.from(typeField as List);
    if (String.fromCharCodes(typeBytes) != 'T') return null;

    final List<int> p = payloadField is Uint8List
        ? payloadField
        : List<int>.from(payloadField as List);
    if (p.isEmpty) return null;

    final status = p[0];
    final isUtf16 = (status & 0x80) != 0; // bit 7
    final langLen = status & 0x3F; // bits 0..5
    if (p.length <= 1 + langLen) return null;

    final textBytes = p.sublist(1 + langLen);

    if (!isUtf16) {
      // UTF-8
      return utf8.decode(textBytes, allowMalformed: true);
    }

    // UTF-16 con/sin BOM
    if (textBytes.length >= 2 &&
        textBytes[0] == 0xFE &&
        textBytes[1] == 0xFF) {
      // BE con BOM
      final cu = Uint16List((textBytes.length - 2) ~/ 2);
      for (int i = 2, j = 0; i + 1 < textBytes.length; i += 2, j++) {
        cu[j] = (textBytes[i] << 8) | textBytes[i + 1];
      }
      return String.fromCharCodes(cu);
    }
    if (textBytes.length >= 2 &&
        textBytes[0] == 0xFF &&
        textBytes[1] == 0xFE) {
      // LE con BOM
      final cu = Uint16List((textBytes.length - 2) ~/ 2);
      for (int i = 2, j = 0; i + 1 < textBytes.length; i += 2, j++) {
        cu[j] = textBytes[i] | (textBytes[i + 1] << 8);
      }
      return String.fromCharCodes(cu);
    }

    // Sin BOM → asumimos big endian
    final cu = Uint16List(textBytes.length ~/ 2);
    for (int i = 0, j = 0; i + 1 < textBytes.length; i += 2, j++) {
      cu[j] = (textBytes[i] << 8) | textBytes[i + 1];
    }
    return String.fromCharCodes(cu);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0033A0);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            children: [
              // Cabecera
              Container(
                width: double.infinity,
                color: const Color(0xFFC8D7EA),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/drager_logo.svg',
                      width: 190,
                      height: 86,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    const Text(
                      'ElectroID',
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, width: double.infinity, color: primaryBlue),

              // Contenido
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona la organización:',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Spinner dinámico
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          alignment: Alignment.center,
                          initialValue: _orgSeleccionada,
                          icon: const Icon(Icons.arrow_drop_down),
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            fontSize: kSpinnerFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.black,
                          ),
                          items: _organizaciones.map((org) {
                            return DropdownMenuItem<String>(
                              value: org,
                              child: Center(
                                child: Text(
                                  org,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: kSpinnerFontSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _orgSeleccionada = v),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    Text(
                      encabezadoText,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: kHeaderFontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const SizedBox(height: 22),

                    _dato(descripcionText),
                    _sp(),
                    _dato(modeloText),
                    _sp(),
                    _dato(serieText),
                    _sp(),
                    _dato(altaText),
                    _sp(),
                    _dato(departamentoText),
                    _sp(),
                    _dato(planificadaText),
                    _sp(),_dato(ultimoPrevText),

                    const SizedBox(height: 28),

                    // Botón: ESCANEAR QR (intacto)
                    SizedBox(
                      width: double.infinity,
                      height: 68,
                      child: ElevatedButton(
                        onPressed: _organizaciones.isEmpty
                            ? null
                            : () async {
                                final result = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const QRScannerPage(),
                                  ),
                                );
                                if (!mounted) return;
                                if (result != null && result.isNotEmpty) {
                                  setState(() => encabezadoText =
                                      'ID Activo (QR): $result');
                                  _buscarPorIdYOrg(result);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('QR leído: $result')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ESCANEAR QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ESCANEAR NFC 
                    SizedBox(
                      width: double.infinity,
                      height: 68,
                      child: ElevatedButton.icon(
                        onPressed: (kIsWeb || _organizaciones.isEmpty || _isNfcReading) ? null : _scanNfc,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isNfcReading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                              )
                            : const Icon(Icons.nfc, color: Colors.white),
                        label: Text(
                          _isNfcReading ? 'LEYENDO NFC…' : 'ESCANEAR NFC',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    // FIN ESCANEAR NFC
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dato(String texto) => Text(
        texto,
        style: const TextStyle(
          color: Color(0xFF2F2F2F),
          fontSize: kFieldLabelFontSize,
          fontWeight: FontWeight.w800,
        ),
      );

  SizedBox _sp() => const SizedBox(height: 16);
}

// ===== Pantalla de escaneo QR =====
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});
  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Cambiar cámara',
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Linterna',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        placeholderBuilder: (context) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No se puede iniciar la cámara.\nDetalle: ${error.errorCode.name}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
