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
  // Password predefinita per l'eliminazione
  final String _passwordEliminazione = 'Ticino-2026';

  // Coordinate simulate della squadra AIB (Parco del Ticino)
  double posizioneCorrenteLat = 45.6512;
  double posizioneCorrenteLng = 8.7123;

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
      stato: 'Non Funzionante',
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
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _codiceController.dispose();
    _ubicazioneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _simulaSpostamentoGPS() {
    setState(() {
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

  Color _getColoreStato(String stato) {
    switch (stato) {
      case 'Non Funzionante':
        return Colors.red[700]!;
      case 'Da Verificare':
        return Colors.orange[800]!;
      case 'Funzionante':
      default:
        return Colors.green[700]!;
    }
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

  void _cambiaStatoIdrante(PuntoIdrico idrante, String nuovoStato) {
    setState(() {
      idrante.stato = nuovoStato;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stato idrante ${idrante.codice} aggiornato in: $nuovoStato'),
        backgroundColor: _getColoreStato(nuovoStato),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confermaEliminazioneIdrante(PuntoIdrico idrante) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.security, color: Colors.red),
            SizedBox(width: 8),
            Text('Protezione Eliminazione'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Per eliminare l\'idrante ${idrante.codice}, inserisci la password della squadra:'),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_passwordController.text == _passwordEliminazione) {
                setState(() {
                  listaIdranti.removeWhere((item) => item.id == idrante.id);
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Idrante ${idrante.codice} eliminato con successo.'),
                    backgroundColor: Colors.orange[800],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password errata! Eliminazione annullata.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Conferma Eliminazione', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostraDettaglioIdrante(PuntoIdrico idrante, double distanzaKm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[800]),
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
            Row(
              children: [
                const Text('Stato: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getColoreStato(idrante.stato),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    idrante.stato,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Ubicazione: ${idrante.ubicazione}'),
            const SizedBox(height: 6),
            Text('Distanza dalla squadra: ${distanzaKm.toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 6),
            Text('Coordinate GPS: ${idrante.latitudine}, ${idrante.longitudine}'),
            const Divider(height: 20),
            const Text('Mezzi Accessibili / Compatibili:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            idrante.mezziCompatibili.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: idrante.mezziCompatibili
                        .map((m) => Padding(
                              padding: const EdgeInsets.only(left: 4.0, top: 2.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text(m, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ))
                        .toList(),
                  )
                : const Text('Nessun mezzo specificato', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
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
    String statoSelezionato = 'Funzionante';
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
                DropdownButtonFormField<String>(
                  value: statoSelezionato,
                  decoration: const InputDecoration(labelText: 'Stato Idrante'),
                  items: ['Funzionante', 'Non Funzionante', 'Da Verificare'].map((st) {
                    return DropdownMenuItem(
                      value: st,
                      child: Text(st, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (valore) {
                    if (valore != null) {
                      setDialogState(() => statoSelezionato = valore);
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
                      stato: statoSelezionato,
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
              height: 70,
              width: double.infinity,
              color: Colors.blue[900],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Censimento Punti Idrici AIB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Punti Idrici Censiti',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

                bool isGuasto = idrante.stato == 'Non Funzionante';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  elevation: 2,
                  color: isGuasto ? Colors.red[50] : Colors.white,
                  child: InkWell(
                    onTap: () => _mostraDettaglioIdrante(idrante, dist),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: isGuasto
                                    ? Colors.red[100]
                                    : (idrante.stato == 'Da Verificare' ? Colors.orange[100] : Colors.blue[100]),
                                child: Icon(
                                  isGuasto
                                      ? Icons.warning_amber_rounded
                                      : (idrante.tipo.contains('Vasca') || idrante.tipo.contains('Presa')
                                          ? Icons.waves
                                          : Icons.water_drop),
                                  color: isGuasto
                                      ? Colors.red[800]
                                      : (idrante.stato == 'Da Verificare' ? Colors.orange[900] : Colors.blue[800]),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${idrante.codice} - ${idrante.tipo}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isGuasto ? Colors.red[900] : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getColoreStato(idrante.stato),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            idrante.stato,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Ubicazione: ${idrante.ubicazione}', style: const TextStyle(fontSize: 12)),
                                    Text(
                                      'Distanza: ${dist.toStringAsFixed(2)} km',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isGuasto ? Colors.red[700] : Colors.blueGrey,
                                      ),
                                    ),
                                    if (idrante.mezziCompatibili.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Mezzi: ${idrante.mezziCompatibili.join(', ')}',
                                        style: TextStyle(fontSize: 11, color: Colors.blueGrey[800], fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Elimina Idrante (Richiede Password)',
                                onPressed: () => _confermaEliminazioneIdrante(idrante),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.info_outline, color: Colors.blue),
                                tooltip: 'Vedi Dettaglio',
                                onPressed: () => _mostraDettaglioIdrante(idrante, dist),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _avviaNavigatoreReale(idrante.latitudine, idrante.longitudine),
                                icon: const Icon(Icons.navigation, size: 14, color: Colors.white),
                                label: const Text('Naviga', style: TextStyle(fontSize: 11, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isGuasto ? Colors.grey[700] : Colors.green[700],
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                              ),
                            ],
                          )
                        ],
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
  String stato;
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