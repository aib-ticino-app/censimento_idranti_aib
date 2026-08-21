import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idranti AIB',
      debugShowCheckedModeBanner: false,
      locale: const Locale('it', 'IT'),
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // DATI SUPABASE SQUADRA AIB
  final String _supabaseUrl = 'https://srielrbjejggxvpeshfd.supabase.co';
  final String _supabaseApiKey = 'sb_publishable_Uz96ih6QR0FVRzJyV3HjqA_RtpIOSN7';

  final String _passwordEliminazione = 'AIB2026';
  String _filtroSelezionato = 'Tutti';

  double posizioneCorrenteLat = 45.6512;
  double posizioneCorrenteLng = 8.7123;
  bool _caricamentoGPS = false;
  bool _caricamentoCloud = false;

  final MapController _mapController = MapController();

  final List<String> mezziDisponibili = [
    'Pickup Modulo AIB',
    'Autobotte AIB',
    'Elicottero / Bambi Bucket',
  ];

  final List<String> tipologieDisponibili = [
    'Idrante Soprasuolo',
    'Idrante Sottosuolo',
    'Vasca AIB di Riserva',
    'Presa d\'Acqua Naturale',
  ];

  List<PuntoIdrico> listaIdranti = [];

  final _codiceController = TextEditingController();
  final _ubicazioneController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ottieniPosizioneGPSNativaWeb();
    _caricaIdrantiDaSupabase();
  }

  @override
  void dispose() {
    _codiceController.dispose();
    _ubicazioneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'apikey': _supabaseApiKey,
        'Authorization': 'Bearer $_supabaseApiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  // --- CARICAMENTO DATI DA SUPABASE ---
  Future<void> _caricaIdrantiDaSupabase() async {
    setState(() => _caricamentoCloud = true);
    try {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/idranti?select=*'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          listaIdranti = data.map((item) => PuntoIdrico.fromMap(item)).toList();
        });
        _mostraMessaggio('Dati aggiornati dal Cloud Supabase!');
      } else {
        _mostraMessaggio('Errore ${response.statusCode} durante il caricamento.', isError: true);
      }
    } catch (e) {
      _mostraMessaggio('Errore di connessione a Supabase.', isError: true);
    } finally {
      setState(() => _caricamentoCloud = false);
    }
  }

  // --- SALVATAGGIO SU SUPABASE ---
  Future<void> _salvaIdranteSuSupabase(PuntoIdrico idrante) async {
    setState(() => _caricamentoCloud = true);
    try {
      final response = await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/idranti'),
        headers: _headers,
        body: json.encode(idrante.toMap()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0]['id'] != null) {
          idrante.id = data[0]['id'].toString();
        }
        setState(() {
          listaIdranti.add(idrante);
        });
        _mostraMessaggio('Punto idrico salvato in Supabase!');
      } else {
        _mostraMessaggio('Errore ${response.statusCode}: Verifica la tabella idranti.', isError: true);
      }
    } catch (e) {
      _mostraMessaggio('Impossibile salvare su Supabase: $e', isError: true);
    } finally {
      setState(() => _caricamentoCloud = false);
    }
  }

  // --- AGGIORNAMENTO STATO SU SUPABASE ---
  Future<void> _cambiaStatoIdrante(PuntoIdrico idrante, String nuovoStato) async {
    setState(() {
      idrante.stato = nuovoStato;
    });
    try {
      await http.patch(
        Uri.parse('$_supabaseUrl/rest/v1/idranti?id=eq.${idrante.id}'),
        headers: _headers,
        body: json.encode({'stato': nuovoStato}),
      );
      _mostraMessaggio('Stato aggiornato nel Cloud!');
    } catch (e) {
      _mostraMessaggio('Errore aggiornamento Supabase.', isError: true);
    }
  }

  // --- ELIMINAZIONE DA SUPABASE ---
  Future<void> _eliminaIdranteDaSupabase(PuntoIdrico idrante) async {
    try {
      await http.delete(
        Uri.parse('$_supabaseUrl/rest/v1/idranti?id=eq.${idrante.id}'),
        headers: _headers,
      );
      setState(() {
        listaIdranti.removeWhere((item) => item.id == idrante.id);
      });
      _mostraMessaggio('Punto idrico eliminato da Supabase.');
    } catch (e) {
      _mostraMessaggio('Errore eliminazione Supabase.', isError: true);
    }
  }

  void _ottieniPosizioneGPSNativaWeb() {
    setState(() => _caricamentoGPS = true);
    if (html.window.navigator.geolocation != null) {
      html.window.navigator.geolocation!.getCurrentPosition().then((pos) {
        if (pos.coords != null) {
          setState(() {
            posizioneCorrenteLat = pos.coords!.latitude!.toDouble();
            posizioneCorrenteLng = pos.coords!.longitude!.toDouble();
            _caricamentoGPS = false;
          });
          _mapController.move(LatLng(posizioneCorrenteLat, posizioneCorrenteLng), 14.0);
        }
      }).catchError((_) {
        setState(() => _caricamentoGPS = false);
      });
    } else {
      setState(() => _caricamentoGPS = false);
    }
  }

  void _mostraMessaggio(String testo, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testo),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _convertiInWGS84GMS(double coordinate, bool isLat) {
    int gradi = coordinate.abs().floor();
    double minutiDecimali = (coordinate.abs() - gradi) * 60;
    int minuti = minutiDecimali.floor();
    double secondi = (minutiDecimali - minuti) * 60;

    String direzione = isLat ? (coordinate >= 0 ? 'N' : 'S') : (coordinate >= 0 ? 'E' : 'W');
    String gradiStr = gradi.toString().padLeft(isLat ? 2 : 3, '0');
    String minutiStr = minuti.toString().padLeft(2, '0');
    String secondiStr = secondi.toStringAsFixed(1).padLeft(4, '0');

    return '$gradiStr° $minutiStr\' $secondiStr" $direzione';
  }

  void _condividiPuntoIdrico(PuntoIdrico idrante) {
    String latGMS = _convertiInWGS84GMS(idrante.latitudine, true);
    String lngGMS = _convertiInWGS84GMS(idrante.longitudine, false);

    List<String> attacchi = [];
    if (idrante.hasUni45) attacchi.add('UNI 45');
    if (idrante.hasUni70) attacchi.add('UNI 70');
    String attacchiStr = attacchi.isNotEmpty ? attacchi.join(', ') : 'Nessuno';

    String testoCondivisione = '''
🚨 *PUNTO IDRICO AIB*
📌 *Codice:* ${idrante.codice} (${idrante.tipo})
📍 *Ubicazione:* ${idrante.ubicazione}
🟢 *Stato:* ${idrante.stato}
⚙️ *Attacchi:* $attacchiStr

🌐 *WGS84 (GMS):*
$latGMS - $lngGMS

🧭 *Decimali:*
${idrante.latitudine.toStringAsFixed(6)}, ${idrante.longitudine.toStringAsFixed(6)}

🗺️ *Mappa:*
https://www.google.com/maps/search/?api=1&query=${idrante.latitudine},${idrante.longitudine}
''';

    try {
      html.window.navigator.share({
        'title': 'Punto Idrico ${idrante.codice}',
        'text': testoCondivisione,
      });
    } catch (_) {
      html.window.navigator.clipboard?.writeText(testoCondivisione);
      _mostraMessaggio('Dati del punto idrico copiati negli appunti!');
    }
  }

  String _generaCodiceProgressivo(String tipo) {
    String prefisso = 'IDR-S';
    if (tipo == 'Idrante Sottosuolo') prefisso = 'IDR-U';
    if (tipo == 'Vasca AIB di Riserva') prefisso = 'VAS';
    if (tipo == 'Presa d\'Acqua Naturale') prefisso = 'PRE';

    int conteggio = listaIdranti.where((item) => item.tipo == tipo).length + 1;
    return '$prefisso-${conteggio.toString().padLeft(2, '0')}';
  }

  double _calcolaDistanzaKm(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  List<PuntoIdrico> get _idrantiFiltratiEVicini {
    List<PuntoIdrico> listaFiltrata = listaIdranti.where((item) {
      if (_filtroSelezionato == 'Idranti') return item.tipo.contains('Idrante');
      if (_filtroSelezionato == 'Vasche') return item.tipo.contains('Vasca');
      if (_filtroSelezionato == 'Prese d\'Acqua') return item.tipo.contains('Presa');
      return true;
    }).toList();

    listaFiltrata.sort((a, b) {
      double distA = _calcolaDistanzaKm(posizioneCorrenteLat, posizioneCorrenteLng, a.latitudine, a.longitudine);
      double distB = _calcolaDistanzaKm(posizioneCorrenteLat, posizioneCorrenteLng, b.latitudine, b.longitudine);
      return distA.compareTo(distB);
    });

    return listaFiltrata;
  }

  Color _getColoreStato(String stato) {
    switch (stato) {
      case 'Non Funzionante': return Colors.red[700]!;
      case 'Da Verificare': return Colors.orange[800]!;
      default: return Colors.green[700]!;
    }
  }

  Widget _buildIconaSimbolo(String tipo, {double size = 22, Color? overrideColor}) {
    if (tipo.contains('Vasca')) return IconaVascaAIB(size: size);
    if (tipo.contains('Presa')) return Icon(Icons.waves, size: size, color: overrideColor ?? Colors.blue[800]);
    return Icon(Icons.fire_hydrant_alt, size: size, color: overrideColor ?? Colors.blue[800]);
  }

  Future<void> _avviaNavigatoreReale(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _confermaEliminazioneIdrante(PuntoIdrico idrante) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Protezione Eliminazione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Inserisci password per eliminare ${idrante.codice}:'),
            const SizedBox(height: 12),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              if (_passwordController.text == _passwordEliminazione) {
                Navigator.of(ctx).pop();
                _eliminaIdranteDaSupabase(idrante);
              } else {
                _mostraMessaggio('Password errata!', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostraDettaglioIdrante(PuntoIdrico idrante, double distanzaKm) {
    String latGMS = _convertiInWGS84GMS(idrante.latitudine, true);
    String lngGMS = _convertiInWGS84GMS(idrante.longitudine, false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            _buildIconaSimbolo(idrante.tipo, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('Dettaglio ${idrante.codice}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipologia: ${idrante.tipo}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Ubicazione: ${idrante.ubicazione}'),
            const SizedBox(height: 6),
            Text('Distanza: ${distanzaKm.toStringAsFixed(2)} km', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(height: 16),
            Text('WGS84: $latGMS - $lngGMS', style: const TextStyle(fontSize: 12)),
            Text('Decimali: ${idrante.latitudine.toStringAsFixed(6)}, ${idrante.longitudine.toStringAsFixed(6)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const Divider(height: 16),
            Row(
              children: [
                Chip(label: Text('UNI 45', style: TextStyle(color: idrante.hasUni45 ? Colors.green : Colors.grey))),
                const SizedBox(width: 8),
                Chip(label: Text('UNI 70', style: TextStyle(color: idrante.hasUni70 ? Colors.green : Colors.grey))),
              ],
            ),
            if (idrante.mezziCompatibili.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Mezzi: ${idrante.mezziCompatibili.join(', ')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.green), onPressed: () => _condividiPuntoIdrico(idrante)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Chiudi')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _avviaNavigatoreReale(idrante.latitudine, idrante.longitudine);
            },
            icon: const Icon(Icons.turn_right, color: Colors.white),
            label: const Text('Naviga'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _mostraDialogoNuovoIdrante() {
    _latController.text = posizioneCorrenteLat.toStringAsFixed(4);
    _lngController.text = posizioneCorrenteLng.toStringAsFixed(4);
    _ubicazioneController.clear();
    String tipoSelezionato = tipologieDisponibili.first;
    String statoSelezionato = 'Funzionante';
    bool hasUni45 = true;
    bool hasUni70 = true;

    _codiceController.text = _generaCodiceProgressivo(tipoSelezionato);
    Map<String, bool> mezziSelezionati = {for (var m in mezziDisponibili) m: false};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Inserisci Nuovo Idrante'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tipoSelezionato,
                  decoration: const InputDecoration(labelText: 'Tipologia'),
                  items: tipologieDisponibili.map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (valore) {
                    if (valore != null) {
                      setDialogState(() {
                        tipoSelezionato = valore;
                        _codiceController.text = _generaCodiceProgressivo(tipoSelezionato);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: _codiceController, decoration: const InputDecoration(labelText: 'Codice Progressivo')),
                const SizedBox(height: 8),
                TextField(controller: _ubicazioneController, decoration: const InputDecoration(labelText: 'Ubicazione')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _latController, decoration: const InputDecoration(labelText: 'Latitudine'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _lngController, decoration: const InputDecoration(labelText: 'Longitudine'))),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(title: const Text('UNI 45'), value: hasUni45, onChanged: (v) => setDialogState(() => hasUni45 = v ?? false)),
                CheckboxListTile(title: const Text('UNI 70'), value: hasUni70, onChanged: (v) => setDialogState(() => hasUni70 = v ?? false)),
                const SizedBox(height: 8),
                const Text('Mezzi Compatibili:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...mezziDisponibili.map((mezzo) {
                  return CheckboxListTile(
                    title: Text(mezzo, style: const TextStyle(fontSize: 13)),
                    value: mezziSelezionati[mezzo] ?? false,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (bool? selezionato) {
                      setDialogState(() {
                        mezziSelezionati[mezzo] = selezionato ?? false;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () {
                if (_codiceController.text.isEmpty || _ubicazioneController.text.isEmpty) {
                  _mostraMessaggio('Inserisci codice e ubicazione.', isError: true);
                  return;
                }

                List<String> selezionati = mezziSelezionati.entries.where((e) => e.value).map((e) => e.key).toList();

                PuntoIdrico nuovo = PuntoIdrico(
                  id: '',
                  codice: _codiceController.text,
                  tipo: tipoSelezionato,
                  ubicazione: _ubicazioneController.text,
                  stato: statoSelezionato,
                  latitudine: double.tryParse(_latController.text) ?? posizioneCorrenteLat,
                  longitudine: double.tryParse(_lngController.text) ?? posizioneCorrenteLng,
                  mezziCompatibili: selezionati,
                  hasUni45: hasUni45,
                  hasUni70: hasUni70,
                );

                Navigator.of(ctx).pop();
                _salvaIdranteSuSupabase(nuovo);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
              child: const Text('Salva in Supabase'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String etichetta) {
    bool isSelected = _filtroSelezionato == etichetta;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(etichetta, style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
        selected: isSelected,
        selectedColor: Colors.blue[800],
        onSelected: (bool selected) => setState(() => _filtroSelezionato = etichetta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idrantiMostrati = _idrantiFiltratiEVicini;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        title: const Text('Idranti AIB Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _caricaIdrantiDaSupabase, tooltip: 'Ricarica da Supabase'),
          IconButton(icon: const Icon(Icons.my_location), onPressed: _ottieniPosizioneGPSNativaWeb, tooltip: 'Aggiorna GPS'),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_caricamentoCloud) const LinearProgressIndicator(color: Colors.orange),
            Container(
              height: 40,
              color: Colors.blue[900],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Parco Ticino - Supabase Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('GPS: ${posizioneCorrenteLat.toStringAsFixed(4)}, ${posizioneCorrenteLng.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            SizedBox(
              height: 240,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: LatLng(posizioneCorrenteLat, posizioneCorrenteLng), initialZoom: 13.5),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.idranti_aib'),
                  MarkerLayer(
                    markers: [
                      Marker(point: LatLng(posizioneCorrenteLat, posizioneCorrenteLng), child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 32)),
                      ...idrantiMostrati.map((idrante) {
                        return Marker(
                          point: LatLng(idrante.latitudine, idrante.longitudine),
                          child: GestureDetector(
                            onTap: () => _mostraDettaglioIdrante(idrante, _calcolaDistanzaKm(posizioneCorrenteLat, posizioneCorrenteLng, idrante.latitudine, idrante.longitudine)),
                            child: CircleAvatar(
                              backgroundColor: _getColoreStato(idrante.stato),
                              child: _buildIconaSimbolo(idrante.tipo, size: 18, overrideColor: Colors.white),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Punti Censiti (${listaIdranti.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _mostraDialogoNuovoIdrante,
                    icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                    label: const Text('+ Idrante Cloud', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(children: [_buildFilterChip('Tutti'), _buildFilterChip('Idranti'), _buildFilterChip('Vasche'), _buildFilterChip('Prese d\'Acqua')]),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: idrantiMostrati.length,
              itemBuilder: (ctx, index) {
                final idrante = idrantiMostrati[index];
                double dist = _calcolaDistanzaKm(posizioneCorrenteLat, posizioneCorrenteLng, idrante.latitudine, idrante.longitudine);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: _buildIconaSimbolo(idrante.tipo),
                    title: Text('${idrante.codice} - ${idrante.tipo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${idrante.ubicazione}\nDistanza: ${dist.toStringAsFixed(2)} km'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.build_circle, color: Colors.blueGrey),
                          tooltip: 'Cambia Stato',
                          onSelected: (String nuovoStato) {
                            _cambiaStatoIdrante(idrante, nuovoStato);
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'Funzionante',
                              child: Text('Segna come: Funzionante', style: TextStyle(color: Colors.green)),
                            ),
                            const PopupMenuItem(
                              value: 'Non Funzionante',
                              child: Text('Segna come: Non Funzionante', style: TextStyle(color: Colors.red)),
                            ),
                            const PopupMenuItem(
                              value: 'Da Verificare',
                              child: Text('Segna come: Da Verificare', style: TextStyle(color: Colors.orange)),
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.share, color: Colors.green), onPressed: () => _condividiPuntoIdrico(idrante)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confermaEliminazioneIdrante(idrante)),
                      ],
                    ),
                    onTap: () => _mostraDettaglioIdrante(idrante, dist),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class IconaVascaAIB extends StatelessWidget {
  final double size;
  const IconaVascaAIB({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue[300],
        border: Border.all(color: Colors.red[700]!, width: 2.5),
      ),
      child: Center(child: Icon(Icons.waves, size: size * 0.5, color: Colors.white)),
    );
  }
}

class PuntoIdrico {
  String id;
  final String codice;
  final String tipo;
  final String ubicazione;
  String stato;
  final double latitudine;
  final double longitudine;
  final List<String> mezziCompatibili;
  final bool hasUni45;
  final bool hasUni70;

  PuntoIdrico({
    required this.id,
    required this.codice,
    required this.tipo,
    required this.ubicazione,
    required this.stato,
    required this.latitudine,
    required this.longitudine,
    this.mezziCompatibili = const [],
    this.hasUni45 = false,
    this.hasUni70 = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'codice': codice,
      'tipo': tipo,
      'ubicazione': ubicazione,
      'stato': stato,
      'latitudine': latitudine,
      'longitudine': longitudine,
      'mezziCompatibili': mezziCompatibili.join(','),
      'hasUni45': hasUni45,
      'hasUni70': hasUni70,
    };
  }

  factory PuntoIdrico.fromMap(Map<String, dynamic> map) {
    String mezziRaw = map['mezziCompatibili']?.toString() ?? '';
    List<String> mezzi = mezziRaw.isNotEmpty ? mezziRaw.split(',') : [];

    return PuntoIdrico(
      id: map['id']?.toString() ?? '',
      codice: map['codice']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? '',
      ubicazione: map['ubicazione']?.toString() ?? '',
      stato: map['stato']?.toString() ?? 'Funzionante',
      latitudine: map['latitudine'] != null ? (map['latitudine'] as num).toDouble() : 0.0,
      longitudine: map['longitudine'] != null ? (map['longitudine'] as num).toDouble() : 0.0,
      mezziCompatibili: mezzi,
      hasUni45: map['hasUni45'] == true,
      hasUni70: map['hasUni70'] == true,
    );
  }
}