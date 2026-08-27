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
  final String _supabaseUrl = 'https://srielrbjejggxvpeshfd.supabase.co';
  final String _supabaseApiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNyaWVscmJqZWpnZ3h2cGVzaGZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczMjcwMzAsImV4cCI6MjEwMjkwMzAzMH0.3nX0meQZYEAIMEvuFSZVP0CTvgbTKES5bS5gDRDFa-c';

  final String _passwordSicurezza = 'Ticino2026';
  String _filtroSelezionato = 'Tutti';

  double posizioneCorrenteLat = 45.6512;
  double posizioneCorrenteLng = 8.7123;
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
  final _noteController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ottieniPosizioneGPS();
    _caricaIdrantiDaSupabase();
  }

  @override
  void dispose() {
    _codiceController.dispose();
    _ubicazioneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _noteController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _ottieniPosizioneGPS() {
    if (html.window.navigator.geolocation != null) {
      html.window.navigator.geolocation!.getCurrentPosition().then((pos) {
        if (pos.coords != null && mounted) {
          setState(() {
            posizioneCorrenteLat = pos.coords!.latitude?.toDouble() ?? posizioneCorrenteLat;
            posizioneCorrenteLng = pos.coords!.longitude?.toDouble() ?? posizioneCorrenteLng;
          });
          _mapController.move(LatLng(posizioneCorrenteLat, posizioneCorrenteLng), 14.0);
        }
      }).catchError((_) {});
    }
  }

  Map<String, String> get _headers => {
        'apikey': _supabaseApiKey,
        'Authorization': 'Bearer $_supabaseApiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

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

  Future<void> _salvaIdranteSuSupabase(PuntoIdrico idrante) async {
    setState(() => _caricamentoCloud = true);
    try {
      final response = await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/idranti'),
        headers: _headers,
        body: json.encode(idrante.toMap()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          idrante.id = data[0]['id'].toString();
        } else if (data is Map && data['id'] != null) {
          idrante.id = data['id'].toString();
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

  Future<void> _aggiornaIdranteSuSupabase(PuntoIdrico idrante) async {
    setState(() => _caricamentoCloud = true);
    try {
      final response = await http.patch(
        Uri.parse('$_supabaseUrl/rest/v1/idranti?id=eq.${idrante.id}'),
        headers: _headers,
        body: json.encode(idrante.toMap()),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          int index = listaIdranti.indexWhere((element) => element.id == idrante.id);
          if (index != -1) {
            listaIdranti[index] = idrante;
          }
        });
        _mostraMessaggio('Punto idrico aggiornato con successo!');
      } else {
        _mostraMessaggio('Errore ${response.statusCode} durante l\'aggiornamento.', isError: true);
      }
    } catch (e) {
      _mostraMessaggio('Errore aggiornamento Supabase: $e', isError: true);
    } finally {
      setState(() => _caricamentoCloud = false);
    }
  }

  Future<void> _cambiaStatoIdrante(PuntoIdrico idrante, String nuovoStato) async {
    setState(() {
      idrante.stato = nuovoStato;
    });

    try {
      final response = await http.patch(
        Uri.parse('$_supabaseUrl/rest/v1/idranti?id=eq.${idrante.id}'),
        headers: _headers,
        body: json.encode({'stato': nuovoStato}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _mostraMessaggio('Stato aggiornato a "$nuovoStato"!');
      } else {
        _mostraMessaggio('Errore ${response.statusCode} salvataggio stato.', isError: true);
      }
    } catch (e) {
      _mostraMessaggio('Errore di connessione a Supabase.', isError: true);
    }
  }

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
    if (idrante.hasUni45) attacchi.add('UNI 45 (SI)'); else attacchi.add('UNI 45 (NO)');
    if (idrante.hasUni70) attacchi.add('UNI 70 (SI)'); else attacchi.add('UNI 70 (NO)');
    String attacchiStr = attacchi.join(', ');
    String accessoStr = idrante.isH24 ? 'Accessibile H24' : 'Proprietà Privata';

    String pallinoStato = '🟢';
    if (idrante.stato == 'Non Funzionante') {
      pallinoStato = '🔴';
    } else if (idrante.stato == 'Da Verificare') {
      pallinoStato = '🟡';
    }

    String notaStr = idrante.note.isNotEmpty ? '\n📝 *Note:* ${idrante.note}' : '';

    String testoCondivisione = '''
🚨 *PUNTO IDRICO AIB*
📌 *Codice:* ${idrante.codice} (${idrante.tipo})
📍 *Ubicazione:* ${idrante.ubicazione}
🔑 *Accesso:* $accessoStr
$pallinoStato *Stato:* ${idrante.stato}
⚙️ *Attacchi:* $attacchiStr$notaStr

🌐 *WGS84 (GMS):*
$latGMS - $lngGMS

🧭 *Decimali:*
${idrante.latitudine.toStringAsFixed(6)}, ${idrante.longitudine.toStringAsFixed(6)}

🗺️ *Mappa:*
https://www.google.com/maps/search/?api=1&query=${idrante.latitudine},${idrante.longitudine}
''';

    if (html.window.navigator.share != null) {
      html.window.navigator.share({
        'title': 'Punto Idrico AIB ${idrante.codice}',
        'text': testoCondivisione,
      });
    } else {
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
      case 'Non Funzionante':
        return Colors.red[700]!;
      case 'Da Verificare':
        return Colors.orange[800]!;
      default:
        return Colors.green[700]!;
    }
  }

  Widget _buildIconaSimbolo(PuntoIdrico idrante, {double size = 22, Color? overrideColor}) {
    if (idrante.stato == 'Non Funzionante') {
      return Icon(Icons.close, size: size, color: overrideColor ?? Colors.white);
    }
    if (idrante.stato == 'Da Verificare') {
      return Icon(Icons.question_mark, size: size * 0.8, color: overrideColor ?? Colors.white);
    }

    if (idrante.tipo.contains('Vasca')) return IconaVascaAIB(size: size);
    if (idrante.tipo.contains('Presa')) return Icon(Icons.waves, size: size, color: overrideColor ?? Colors.blue[800]);
    return Icon(Icons.fire_hydrant_alt, size: size, color: overrideColor ?? Colors.blue[800]);
  }

  Widget _buildBadgeAttacco(String nome, bool disponibile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: disponibile ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: disponibile ? Colors.green[800]! : Colors.red[800]!,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            disponibile ? Icons.check_circle : Icons.cancel,
            size: 13,
            color: disponibile ? Colors.green[800] : Colors.red[800],
          ),
          const SizedBox(width: 3),
          Text(
            nome,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: disponibile ? Colors.green[900] : Colors.red[900],
              decoration: disponibile ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _avviaNavigatoreReale(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _richiediEAvviaNavigazione(PuntoIdrico idrante) {
    if (idrante.stato == 'Non Funzionante') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Expanded(child: Text('Punto Non Funzionante')),
            ],
          ),
          content: Text(
            'ATTENZIONE:\nIl punto idrico ${idrante.codice} è attualmente segnalato come "NON FUNZIONANTE".\n\nVuoi comunque avviare il navigatore verso questa posizione?',
            style: const TextStyle(fontSize: 14),
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
              icon: const Icon(Icons.navigation, color: Colors.white),
              label: const Text('Naviga Comunque'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    } else {
      _avviaNavigatoreReale(idrante.latitudine, idrante.longitudine);
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
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              if (_passwordController.text == _passwordSicurezza) {
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

  void _confermaEApriModificaIdrante(PuntoIdrico idrante) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Protezione Modifica'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Inserisci password per modificare ${idrante.codice}:'),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              if (_passwordController.text == _passwordSicurezza) {
                Navigator.of(ctx).pop();
                _mostraDialogoModificaIdrante(idrante);
              } else {
                _mostraMessaggio('Password errata!', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            child: const Text('Sblocca Modifica', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostraDialogoModificaIdrante(PuntoIdrico idrante) {
    _codiceController.text = idrante.codice;
    _ubicazioneController.text = idrante.ubicazione;
    _latController.text = idrante.latitudine.toString();
    _lngController.text = idrante.longitudine.toString();
    _noteController.text = idrante.note;

    String tipoSelezionato = idrante.tipo;
    String statoSelezionato = idrante.stato;
    bool hasUni45 = idrante.hasUni45;
    bool hasUni70 = idrante.hasUni70;
    bool isH24 = idrante.isH24;

    Map<String, bool> mezziSelezionati = {
      for (var m in mezziDisponibili) m: idrante.mezziCompatibili.contains(m),
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Modifica ${idrante.codice}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: tipologieDisponibili.contains(tipoSelezionato) ? tipoSelezionato : tipologieDisponibili.first,
                  decoration: const InputDecoration(labelText: 'Tipologia'),
                  items: tipologieDisponibili
                      .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (valore) {
                    if (valore != null) {
                      setDialogState(() {
                        tipoSelezionato = valore;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: _codiceController, decoration: const InputDecoration(labelText: 'Codice Progressivo')),
                const SizedBox(height: 8),
                TextField(controller: _ubicazioneController, decoration: const InputDecoration(labelText: 'Ubicazione')),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(
                    isH24 ? 'Accessibile H24 (Pubblico)' : 'Proprietà Privata',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isH24 ? Colors.green[800] : Colors.orange[900],
                    ),
                  ),
                  subtitle: const Text('Disattiva se in area privata/recintata', style: TextStyle(fontSize: 11)),
                  value: isH24,
                  activeColor: Colors.green[700],
                  onChanged: (v) => setDialogState(() => isH24 = v),
                ),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLength: 200,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note aggiuntive (max 200 caratteri)',
                    border: OutlineInputBorder(),
                    hintText: 'Es. Presso cancello verde, pressione bassa...',
                  ),
                ),
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

                PuntoIdrico aggiornato = PuntoIdrico(
                  id: idrante.id,
                  codice: _codiceController.text,
                  tipo: tipoSelezionato,
                  ubicazione: _ubicazioneController.text,
                  stato: statoSelezionato,
                  latitudine: double.tryParse(_latController.text) ?? idrante.latitudine,
                  longitudine: double.tryParse(_lngController.text) ?? idrante.longitudine,
                  mezziCompatibili: selezionati,
                  hasUni45: hasUni45,
                  hasUni70: hasUni70,
                  isH24: isH24,
                  note: _noteController.text,
                );

                Navigator.of(ctx).pop();
                _aggiornaIdranteSuSupabase(aggiornato);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
              child: const Text('Salva Modifiche'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostraDettaglioIdrante(PuntoIdrico idrante, double distanzaKm) {
    _mapController.move(LatLng(idrante.latitudine, idrante.longitudine), 15.0);

    String latGMS = _convertiInWGS84GMS(idrante.latitudine, true);
    String lngGMS = _convertiInWGS84GMS(idrante.longitudine, false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            _buildIconaSimbolo(idrante, size: 24, overrideColor: _getColoreStato(idrante.stato)),
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
            Row(
              children: [
                const Text('Stato: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  idrante.stato,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getColoreStato(idrante.stato),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  idrante.isH24 ? Icons.lock_open : Icons.lock,
                  size: 16,
                  color: idrante.isH24 ? Colors.green[700] : Colors.orange[800],
                ),
                const SizedBox(width: 4),
                Text(
                  idrante.isH24 ? 'Accessibile H24' : 'Proprietà Privata',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: idrante.isH24 ? Colors.green[800] : Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Distanza: ${distanzaKm.toStringAsFixed(2)} km', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(height: 16),
            Text('WGS84: $latGMS - $lngGMS', style: const TextStyle(fontSize: 12)),
            Text('Decimali: ${idrante.latitudine.toStringAsFixed(6)}, ${idrante.longitudine.toStringAsFixed(6)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const Divider(height: 16),
            Row(
              children: [
                _buildBadgeAttacco('UNI 45', idrante.hasUni45),
                const SizedBox(width: 8),
                _buildBadgeAttacco('UNI 70', idrante.hasUni70),
              ],
            ),
            if (idrante.mezziCompatibili.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Mezzi: ${idrante.mezziCompatibili.join(', ')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
            if (idrante.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber[400]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📝 Note:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.brown)),
                    const SizedBox(height: 2),
                    Text(idrante.note, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.green), onPressed: () => _condividiPuntoIdrico(idrante)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Chiudi')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _richiediEAvviaNavigazione(idrante);
            },
            icon: const Icon(Icons.turn_right, color: Colors.white),
            label: const Text('Naviga'),
            style: ElevatedButton.styleFrom(
              backgroundColor: idrante.stato == 'Non Funzionante' ? Colors.red[700] : Colors.blue[700],
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
    _ubicazioneController.clear();
    _noteController.clear();
    String tipoSelezionato = tipologieDisponibili.first;
    String statoSelezionato = 'Funzionante';
    bool hasUni45 = true;
    bool hasUni70 = true;
    bool isH24 = true;

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
                  items: tipologieDisponibili
                      .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo, style: const TextStyle(fontSize: 13))))
                      .toList(),
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
                SwitchListTile(
                  title: Text(
                    isH24 ? 'Accessibile H24 (Pubblico)' : 'Proprietà Privata',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isH24 ? Colors.green[800] : Colors.orange[900],
                    ),
                  ),
                  subtitle: const Text('Disattiva se in area privata/recintata', style: TextStyle(fontSize: 11)),
                  value: isH24,
                  activeColor: Colors.green[700],
                  onChanged: (v) => setDialogState(() => isH24 = v),
                ),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLength: 200,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note aggiuntive (max 200 caratteri)',
                    border: OutlineInputBorder(),
                    hintText: 'Es. Presso cancello verde, pressione bassa...',
                  ),
                ),
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
                  isH24: isH24,
                  note: _noteController.text,
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
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_fire_department, color: Colors.orange),
            ),
            const SizedBox(width: 10),
            const Text('Idranti AIB Cloud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.my_location), onPressed: _ottieniPosizioneGPS, tooltip: 'Aggiorna Posizione GPS'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _caricaIdrantiDaSupabase, tooltip: 'Ricarica da Supabase'),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_caricamentoCloud) const LinearProgressIndicator(color: Colors.orange),
            Container(
              height: 36,
              color: Colors.blue[900],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Parco Ticino - Supabase Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('GPS: ${posizioneCorrenteLat.toStringAsFixed(4)}, ${posizioneCorrenteLng.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                      Marker(
                          point: LatLng(posizioneCorrenteLat, posizioneCorrenteLng),
                          child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 32)),
                      ...idrantiMostrati.map((idrante) {
                        return Marker(
                          point: LatLng(idrante.latitudine, idrante.longitudine),
                          child: GestureDetector(
                            onTap: () => _mostraDettaglioIdrante(
                                idrante, _calcolaDistanzaKm(posizioneCorrenteLat, posizioneCorrenteLng, idrante.latitudine, idrante.longitudine)),
                            child: CircleAvatar(
                              backgroundColor: _getColoreStato(idrante.stato),
                              child: _buildIconaSimbolo(idrante, size: 18, overrideColor: Colors.white),
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
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Punti Censiti (${listaIdranti.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ElevatedButton.icon(
                    onPressed: _mostraDialogoNuovoIdrante,
                    icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                    label: const Text('+ Idrante Cloud', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(children: [_buildFilterChip('Tutti'), _buildFilterChip('Idranti'), _buildFilterChip('Vasche'), _buildFilterChip('Prese d\'Acqua')]),
            ),
            const SizedBox(height: 6),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: idrantiMostrati.length,
              itemBuilder: (ctx, index) {
                final idrante = idrantiMostrati[index];
                double dist = _calcolaDistanzaKm(posizioneCorrenteLat, posizioneCorrenteLng, idrante.latitudine, idrante.longitudine);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _mostraDettaglioIdrante(idrante, dist),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: _getColoreStato(idrante.stato),
                            child: _buildIconaSimbolo(idrante, size: 18, overrideColor: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${idrante.codice} - ${idrante.tipo}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${idrante.ubicazione} (${idrante.isH24 ? "H24" : "Privato"})',
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildBadgeAttacco('UNI 45', idrante.hasUni45),
                                    const SizedBox(width: 6),
                                    _buildBadgeAttacco('UNI 70', idrante.hasUni70),
                                    const SizedBox(width: 8),
                                    Text('Dist: ${dist.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                if (idrante.mezziCompatibili.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mezzi: ${idrante.mezziCompatibili.join(', ')}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                                  ),
                                ],
                                if (idrante.note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '📝 ${idrante.note}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amber[900]),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _confermaEApriModificaIdrante(idrante),
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 12.0),
                                        child: Icon(Icons.edit, size: 20, color: Colors.orange),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _confermaEliminazioneIdrante(idrante),
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 12.0),
                                        child: Icon(Icons.delete, size: 20, color: Colors.red),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.build_circle, size: 20, color: Colors.blueGrey),
                                      tooltip: 'Cambia Stato',
                                      onSelected: (String nuovoStato) => _cambiaStatoIdrante(idrante, nuovoStato),
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem(value: 'Funzionante', child: Text('Funzionante', style: TextStyle(color: Colors.green))),
                                        const PopupMenuItem(value: 'Non Funzionante', child: Text('Non Funzionante', style: TextStyle(color: Colors.red))),
                                        const PopupMenuItem(value: 'Da Verificare', child: Text('Da Verificare', style: TextStyle(color: Colors.orange))),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _condividiPuntoIdrico(idrante),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Icon(Icons.share, size: 20, color: Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
  final bool isH24;
  final String note;

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
    this.isH24 = true,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'codice': codice,
      'tipo': tipo,
      'ubicazione': ubicazione,
      'stato': stato,
      'latitudine': latitudine,
      'longitudine': longitudine,
      'mezzicompatibili': mezziCompatibili.join(','),
      'hasuni45': hasUni45,
      'hasuni70': hasUni70,
      'ish24': isH24,
      'note': note,
    };
  }

  factory PuntoIdrico.fromMap(Map<String, dynamic> map) {
    String mezziRaw = map['mezzicompatibili']?.toString() ?? '';
    List<String> mezzi = mezziRaw.isNotEmpty ? mezziRaw.split(',') : [];

    return PuntoIdrico(
      id: map['id']?.toString() ?? '',
      codice: map['codice']?.toString() ?? 'IDR-00',
      tipo: map['tipo']?.toString() ?? 'Idrante Soprasuolo',
      ubicazione: map['ubicazione']?.toString() ?? 'N/D',
      stato: map['stato']?.toString() ?? 'Funzionante',
      latitudine: map['latitudine'] != null ? double.tryParse(map['latitudine'].toString()) ?? 0.0 : 0.0,
      longitudine: map['longitudine'] != null ? double.tryParse(map['longitudine'].toString()) ?? 0.0 : 0.0,
      mezziCompatibili: mezzi,
      hasUni45: map['hasuni45'] == true,
      hasUni70: map['hasuni70'] == true,
      isH24: map['ish24'] ?? true,
      note: map['note']?.toString() ?? map['Note']?.toString() ?? '',
    );
  }
}