import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIB - Censimento Idranti',
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
  // Coordinate simulate della squadra AIB (Parco del Ticino)
  double posizioneCorrenteLat = 45.6512;
  double posizioneCorrenteLng = 8.7123;
  bool _gpsSimulato = false;

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

  List<PuntoIdrico> listaIdranti = [
    PuntoIdrico(
      id: '1',
      codice: 'IDR-01',
      tipo: 'Idrante Soprasuolo',
      ubicazione: 'Via Parco Ticino 12',
      stato: 'Funzionante',
      latitudine: 45.6520,
      longitudine: 8.7130,
      mezziCompatibili: ['Pickup Modulo AIB', 'Autobotte AIB'],
    ),
    PuntoIdrico(
      id: '2',
      codice: 'VAS-01',
      tipo: 'Vasca AIB di Riserva',
      ubicazione: 'Loc. Sottobosco - Sentiero 3',
      stato: 'Funzionante',
      latitudine: 45.6589,
      longitudine: 8.7201,
      mezziCompatibili: ['Pickup Modulo AIB', 'Elicottero / Bambi Bucket'],
    ),
    PuntoIdrico(
      id: '3',
      codice: 'IDR-02',
      tipo: 'Idrante Sottosuolo',
      ubicazione: 'Via Centrale / Ang. Via Roma',
      stato: 'Funzionante',
      latitudine: 45.6480,
      longitudine: 8.7050,
      mezziCompatibili: ['Pickup Modulo AIB', 'Autobotte AIB'],
    ),
    PuntoIdrico(
      id: '4',
      codice: 'PRE-01',
      tipo: 'Presa d\'Acqua Naturale',
      ubicazione: 'Torrente Ticino - Ansa Nord',
      stato: 'Da Verificare',
      latitudine: 45.6700,
      longitudine: 8.7300,
      mezziCompatibili: ['Elicottero / Bambi Bucket'],
    ),
  ];

  final _codiceController = TextEditingController();
  final _ubicazioneController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  @override
  void dispose() {
    _codiceController.dispose();
    _ubicazioneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _simulaSpostamentoGPS() {
    setState(() {
      _gpsSimulato = true;
      posizioneCorrenteLat += 0.005;
      posizioneCorrenteLng += 0.005;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Posizione squadra aggiornata (Simulazione GPS)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  double _calcolaDistanzaKm(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  List<PuntoIdrico> get _idrantiPiuVicini {
    List<PuntoIdrico> listaOrdinata = List.from(listaIdranti);
    listaOrdinata.sort((a, b) {
      double distA = _calcolaDistanzaKm(
          posizioneCorrenteLat, posizioneCorrenteLng, a.latitudine, a.longitudine);
      double distB = _calcolaDistanzaKm(
          posizioneCorrenteLat, posizioneCorrenteLng, b.latitudine, b.longitudine);
      return distA.compareTo(distB);
    });
    return listaOrdinata;
  }

  Future<void> _avviaNavigatoreReale(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        final Uri geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
        await launchUrl(geoUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire il navigatore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostraDialogoNavigazione(PuntoIdrico idrante, double distanzaKm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.navigation, color: Colors.blue[800]),
            const SizedBox(width: 8),
            Expanded(child: Text('Naviga verso ${idrante.codice}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distanza: ${distanzaKm.toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 6),
            Text('Coordinate GPS: ${idrante.latitudine}, ${idrante.longitudine}'),
            if (idrante.mezziCompatibili.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Mezzi compatibili:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(idrante.mezziCompatibili.join(', '), style: const TextStyle(fontSize: 12)),
            ],
            const Divider(height: 20),
            const Text(
              'Premendo "Avvia Navigatore", verrà aperta l\'applicazione di mappe predefinita.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _avviaNavigatoreReale(idrante.latitudine, idrante.longitudine);
            },
            icon: const Icon(Icons.turn_right, color: Colors.white),
            label: const Text('Avvia Navigatore'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _mostraDialogoNuovoIdrante() {
    _latController.text = posizioneCorrenteLat.toStringAsFixed(4);
    _lngController.text = posizioneCorrenteLng.toStringAsFixed(4);
    String tipoSelezionato = tipologieDisponibili.first;
    Map<String, bool> mezziSelezionati = {
      for (var m in mezziDisponibili) m: false
    };

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
                TextField(
                  controller: _codiceController,
                  decoration: const InputDecoration(
                    labelText: 'Codice / Sigla Idrante',
                    hintText: 'es. IDR-05',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tipoSelezionato,
                  decoration: const InputDecoration(labelText: 'Tipologia'),
                  items: tipologieDisponibili.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(tipo, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (valore) {
                    if (valore != null) {
                      setDialogState(() => tipoSelezionato = valore);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ubicazioneController,
                  decoration: const InputDecoration(
                    labelText: 'Ubicazione / Riferimento',
                    hintText: 'es. Via Roma, ang. Via Verdi',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Latitudine'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Longitudine'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mezzi Compatibili:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
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
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_codiceController.text.isEmpty || _ubicazioneController.text.isEmpty) {
                  return;
                }

                List<String> selezionati = mezziSelezionati.entries
                    .where((entry) => entry.value)
                    .map((entry) => entry.key)
                    .toList();

                setState(() {
                  listaIdranti.add(
                    PuntoIdrico(
                      id: DateTime.now().toString(),
                      codice: _codiceController.text,
                      tipo: tipoSelezionato,
                      ubicazione: _ubicazioneController.text,
                      stato: 'Funzionante',
                      latitudine: double.tryParse(_latController.text) ?? posizioneCorrenteLat,
                      longitudine: double.tryParse(_lngController.text) ?? posizioneCorrenteLng,
                      mezziCompatibili: selezionati,
                    ),
                  );
                });

                _codiceController.clear();
                _ubicazioneController.clear();
                _latController.clear();
                _lngController.clear();
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Salva Idrante'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idrantiVicini = _idrantiPiuVicini;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mappatura & Navigatore AIB'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _simulaSpostamentoGPS,
            tooltip: 'Simula Spostamento GPS',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              width: double.infinity,
              color: Colors.blue[900],
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Censimento Punti Idrici AIB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'GPS: ${posizioneCorrenteLat.toStringAsFixed(3)}, ${posizioneCorrenteLng.toStringAsFixed(3)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.map, color: Colors.green[800]),
                            const SizedBox(width: 8),
                            const Text(
                              'Stato Posizione Squadra',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        Chip(
                          avatar: const Icon(Icons.my_location, size: 14, color: Colors.white),
                          label: Text(
                            _gpsSimulato ? 'GPS Aggiornato' : 'GPS Attivo',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.green[700],
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (idrantiVicini.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade400, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('IDRANTE PIÙ VICINO:',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                  Text(
                                    '${idrantiVicini.first.codice} (${idrantiVicini.first.tipo})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(idrantiVicini.first.ubicazione, style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                double dist = _calcolaDistanzaKm(
                                  posizioneCorrenteLat,
                                  posizioneCorrenteLng,
                                  idrantiVicini.first.latitudine,
                                  idrantiVicini.first.longitudine,
                                );
                                _mostraDialogoNavigazione(idrantiVicini.first, dist);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              child: const Text('Naviga subito', style: TextStyle(fontSize: 11, color: Colors.white)),
                            )
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Punti Idrici nelle Vicinanze',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _mostraDialogoNuovoIdrante,
                    icon: const Icon(Icons.add_location_alt, color: Colors.white, size: 18),
                    label: const Text('+ Idrante', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: idrantiVicini.length,
              itemBuilder: (ctx, index) {
                final idrante = idrantiVicini[index];
                double dist = _calcolaDistanzaKm(
                  posizioneCorrenteLat,
                  posizioneCorrenteLng,
                  idrante.latitudine,
                  idrante.longitudine,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: index == 0 ? Colors.green[100] : Colors.blue[100],
                      child: Icon(
                        idrante.tipo.contains('Vasca') || idrante.tipo.contains('Presa')
                            ? Icons.waves
                            : Icons.water_drop,
                        color: index == 0 ? Colors.green[800] : Colors.blue[800],
                      ),
                    ),
                    title: Text(
                      '${idrante.codice} - ${idrante.tipo}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ubicazione: ${idrante.ubicazione}', style: const TextStyle(fontSize: 12)),
                        Text(
                          'Distanza: ${dist.toStringAsFixed(2)} km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: index == 0 ? Colors.green[800] : Colors.blueGrey,
                          ),
                        ),
                        if (idrante.mezziCompatibili.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              'Mezzi: ${idrante.mezziCompatibili.join(', ')}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _mostraDialogoNavigazione(idrante, dist),
                      icon: const Icon(Icons.navigation, size: 14, color: Colors.white),
                      label: const Text('Naviga', style: TextStyle(fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: index == 0 ? Colors.green[700] : Colors.blue[700],
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class PuntoIdrico {
  final String id;
  final String codice;
  final String tipo;
  final String ubicazione;
  final String stato;
  final double latitudine;
  final double longitudine;
  final List<String> mezziCompatibili;

  PuntoIdrico({
    required this.id,
    required this.codice,
    required this.tipo,
    required this.ubicazione,
    required this.stato,
    required this.latitudine,
    required this.longitudine,
    this.mezziCompatibili = const [],
  });
}