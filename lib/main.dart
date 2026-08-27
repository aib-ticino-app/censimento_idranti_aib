import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String supabaseUrl = 'https://srielrbjejggxvpeshfd.supabase.co';
const String supabaseApiKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNyaWVscmJqZWpnZ3h2cGVzaGZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczMjcwMzAsImV4cCI6MjEwMjkwMzAzMH0.3nX0meQZYEAIMEvuFSZVP0CTvgbTKES5bS5gDRDFa-c';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseApiKey);
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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const AuthPage();
    }
    return const HomePage();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool loading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _distaccamentoController = TextEditingController();
  final _siglaController = TextEditingController();
  String _ruoloSelezionato = 'OPERATORE';

  final List<String> ruoliDisponibili = ['OPERATORE', 'CAPOSQUADRA', 'DOS'];

  void _mostraMessaggio(String testo, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testo),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
      ),
    );
  }

  Future<void> _eseguiAuth() async {
    setState(() => loading = true);
    final supabase = Supabase.instance.client;

    try {
      if (isLogin) {
        final res = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final prof = await supabase
            .from('profili_utenti')
            .select()
            .eq('id', res.user!.id)
            .maybeSingle();

        if (prof != null && prof['approvato'] == false) {
          await supabase.auth.signOut();
          _mostraMessaggio('Account in attesa di approvazione dall\'Amministratore.', isError: true);
          setState(() => loading = false);
          return;
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
        }
      } else {
        if (_nomeController.text.isEmpty ||
            _cognomeController.text.isEmpty ||
            _distaccamentoController.text.isEmpty) {
          _mostraMessaggio('Compila tutti i campi obbligatori.', isError: true);
          setState(() => loading = false);
          return;
        }

        final res = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (res.user != null) {
          await supabase.from('profili_utenti').insert({
            'id': res.user!.id,
            'nome_cognome': '${_nomeController.text.trim()} ${_cognomeController.text.trim()}',
            'distaccamento': _distaccamentoController.text.trim(),
            'sigla': _siglaController.text.trim(),
            'ruolo': _ruoloSelezionato,
            'approvato': false,
          });

          await supabase.auth.signOut();
          _mostraMessaggio('Registrazione completata! In attesa di approvazione dall\'Amministratore.');
          setState(() => isLogin = true);
        }
      }
    } catch (e) {
      _mostraMessaggio('Errore: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _recuperaPassword() async {
    if (_emailController.text.isEmpty) {
      _mostraMessaggio('Inserisci la tua email nel campo sopra.', isError: true);
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      _mostraMessaggio('Email per il ripristino inviata! Controlla la tua casella.');
    } catch (e) {
      _mostraMessaggio('Errore nell\'invio della mail.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 36),
                      const SizedBox(width: 8),
                      Text(
                        isLogin ? 'Accedi ad AIB Cloud' : 'Registrazione Volontario',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!isLogin) ...[
                    TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome *')),
                    TextField(controller: _cognomeController, decoration: const InputDecoration(labelText: 'Cognome *')),
                    TextField(controller: _distaccamentoController, decoration: const InputDecoration(labelText: 'Distaccamento (es. Fagnano Olona) *')),
                    TextField(controller: _siglaController, decoration: const InputDecoration(labelText: 'Sigla Operativa (opzionale)')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _ruoloSelezionato,
                      decoration: const InputDecoration(labelText: 'Ruolo Richiesto'),
                      items: ruoliDisponibili
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setState(() => _ruoloSelezionato = v!),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email *')),
                  TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password *')),
                  const SizedBox(height: 16),
                  if (loading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _eseguiAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(45),
                      ),
                      child: Text(isLogin ? 'ACCEDI' : 'INVIA RICHIESTA DI REGISTRAZIONE'),
                    ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? 'Non hai un account? Registrati' : 'Hai già un account? Accedi'),
                  ),
                  if (isLogin)
                    TextButton(
                      onPressed: _recuperaPassword,
                      child: const Text('Password dimenticata?', style: TextStyle(color: Colors.grey)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String _passwordSicurezza = 'Ticino2026';
  String _filtroSelezionato = 'Tutti';

  double posizioneCorrenteLat = 45.6512;
  double posizioneCorrenteLng = 8.7123;
  bool _caricamentoCloud = false;

  Map<String, dynamic>? mioProfilo;
  int utentiDaApprovare = 0;

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
    _caricaProfiloUtente();
    _ottieniPosizioneGPS();
    _caricaIdrantiDaSupabase();
  }

  Future<void> _caricaProfiloUtente() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      final res = await supabase.from('profili_utenti').select().eq('id', user.id).maybeSingle();
      if (res != null) {
        setState(() => mioProfilo = res);
        if (res['ruolo'] == 'AMMINISTRATORE') {
          _controllaUtentiDaApprovare();
        }
      }
    }
  }

  Future<void> _controllaUtentiDaApprovare() async {
    final supabase = Supabase.instance.client;
    final res = await supabase.from('profili_utenti').select().eq('approvato', false);
    setState(() => utentiDaApprovare = (res as List).length);
  }

  Future<void> _ottieniPosizioneGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        setState(() {
          posizioneCorrenteLat = position.latitude;
          posizioneCorrenteLng = position.longitude;
        });
        _mapController.move(LatLng(posizioneCorrenteLat, posizioneCorrenteLng), 14.5);
      }
    } catch (_) {}
  }

  Map<String, String> get _headers => {
        'apikey': supabaseApiKey,
        'Authorization': 'Bearer $supabaseApiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  Future<void> _caricaIdrantiDaSupabase() async {
    setState(() => _caricamentoCloud = true);
    try {
      final response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/idranti?select=*'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          listaIdranti = data.map((item) => PuntoIdrico.fromMap(item)).toList();
        });
      }
    } catch (_) {
    } finally {
      setState(() => _caricamentoCloud = false);
    }
  }

  Future<void> _salvaIdranteSuSupabase(PuntoIdrico idrante) async {
    setState(() => _caricamentoCloud = true);
    try {
      final dataMap = idrante.toMap();
      dataMap['creato_da'] = '${mioProfilo?['nome_cognome']} (${mioProfilo?['ruolo']})';

      final response = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/idranti'),
        headers: _headers,
        body: json.encode(dataMap),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _caricaIdrantiDaSupabase();
        _mostraMessaggio('Punto idrico salvato su Supabase!');
      }
    } catch (e) {
      _mostraMessaggio('Errore di salvataggio.', isError: true);
    } finally {
      setState(() => _caricamentoCloud = false);
    }
  }

  Future<void> _aggiornaIdranteSuSupabase(PuntoIdrico idrante) async {
    setState(() => _caricamentoCloud = true);
    try {
      final dataMap = idrante.toMap();
      dataMap['modificato_da'] = '${mioProfilo?['nome_cognome']} (${mioProfilo?['ruolo']})';

      final response = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/idranti?id=eq.${idrante.id}'),
        headers: _headers,
        body: json.encode(dataMap),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _caricaIdrantiDaSupabase();
        _mostraMessaggio('Punto idrico aggiornato!');
      }
    } catch (e) {
      _mostraMessaggio('Errore di aggiornamento.', isError: true);
    } finally {
      setState(() => _caricamentoCloud = false);
    }
  }

  Future<void> _eliminaIdranteDaSupabase(PuntoIdrico idrante) async {
    try {
      await http.delete(
        Uri.parse('$supabaseUrl/rest/v1/idranti?id=eq.${idrante.id}'),
        headers: _headers,
      );
      _caricaIdrantiDaSupabase();
      _mostraMessaggio('Punto idrico eliminato.');
    } catch (e) {
      _mostraMessaggio('Errore eliminazione.', isError: true);
    }
  }

  void _mostraMessaggio(String testo, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testo),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
      ),
    );
  }

  Widget _buildBadgeCasco(String ruolo) {
    Color coloreCasco = Colors.black;
    Color coloreStriscia = Colors.yellow[600]!;

    if (ruolo == 'DOS') coloreCasco = Colors.white;
    if (ruolo == 'CAPOSQUADRA') coloreCasco = Colors.red[700]!;
    if (ruolo == 'AMMINISTRATORE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.purple[800], borderRadius: BorderRadius.circular(4)),
        child: const Text('🛡️ ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: coloreCasco,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 14, height: 4, color: coloreStriscia),
          const SizedBox(width: 4),
          Text(
            ruolo,
            style: TextStyle(
              color: ruolo == 'DOS' ? Colors.black : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _apriPannelloAdmin() async {
    final supabase = Supabase.instance.client;
    final utenti = await supabase.from('profili_utenti').select();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pannello Amministratore - Gestione Utenti'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: utenti.length,
              itemBuilder: (context, index) {
                final u = utenti[index];
                return ListTile(
                  title: Text('${u['nome_cognome']} (${u['distaccamento']})'),
                  subtitle: Text('Ruolo: ${u['ruolo']} - ${u['approvato'] ? "Approvato" : "IN ATTESA"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!u['approvato'])
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () async {
                            await supabase.from('profili_utenti').update({'approvato': true}).eq('id', u['id']);
                            Navigator.of(ctx).pop();
                            _apriPannelloAdmin();
                            _controllaUtentiDaApprovare();
                          },
                        ),
                      DropdownButton<String>(
                        value: u['ruolo'],
                        items: ['OPERATORE', 'CAPOSQUADRA', 'DOS', 'AMMINISTRATORE']
                            .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (nuovoRuolo) async {
                          if (nuovoRuolo != null) {
                            await supabase.from('profili_utenti').update({'ruolo': nuovoRuolo}).eq('id', u['id']);
                            Navigator.of(ctx).pop();
                            _apriPannelloAdmin();
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Chiudi')),
          ],
        ),
      ),
    );
  }

  bool get possoModificareEEliminare {
    final r = mioProfilo?['ruolo'];
    return r == 'CAPOSQUADRA' || r == 'DOS' || r == 'AMMINISTRATORE';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 30,
              errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, color: Colors.orange),
            ),
            const SizedBox(width: 8),
            const Text('Idranti AIB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          if (mioProfilo != null) _buildBadgeCasco(mioProfilo!['ruolo']),
          if (mioProfilo?['ruolo'] == 'AMMINISTRATORE')
            Stack(
              children: [
                IconButton(icon: const Icon(Icons.admin_panel_settings), onPressed: _apriPannelloAdmin),
                if (utentiDaApprovare > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.red,
                      child: Text('$utentiDaApprovare', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_caricamentoCloud) const LinearProgressIndicator(color: Colors.orange),
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
                        child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 30),
                      ),
                      ...listaIdranti.map((idrante) {
                        return Marker(
                          point: LatLng(idrante.latitudine, idrante.longitudine),
                          child: CircleAvatar(
                            backgroundColor: idrante.stato == 'Non Funzionante' ? Colors.red : Colors.green,
                            child: const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Punti Censiti (${listaIdranti.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _mostraDialogoNuovoIdrante,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Idrante'),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: listaIdranti.length,
              itemBuilder: (ctx, index) {
                final idrante = listaIdranti[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text('${idrante.codice} - ${idrante.tipo}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(idrante.ubicazione),
                        if (idrante.creatoDa.isNotEmpty)
                          Text('Censito da: ${idrante.creatoDa}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (possoModificareEEliminare)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _mostraDialogoModificaIdrante(idrante),
                          ),
                        if (possoModificareEEliminare)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminaIdranteDaSupabase(idrante),
                          ),
                      ],
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

  void _mostraDialogoNuovoIdrante() {
    _latController.text = posizioneCorrenteLat.toStringAsFixed(4);
    _lngController.text = posizioneCorrenteLng.toStringAsFixed(4);
    _ubicazioneController.clear();
    _noteController.clear();
    _codiceController.text = 'IDR-${listaIdranti.length + 1}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo Idrante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _codiceController, decoration: const InputDecoration(labelText: 'Codice')),
            TextField(controller: _ubicazioneController, decoration: const InputDecoration(labelText: 'Ubicazione')),
            TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              final nuovo = PuntoIdrico(
                id: '',
                codice: _codiceController.text,
                tipo: 'Idrante Soprasuolo',
                ubicazione: _ubicazioneController.text,
                stato: 'Funzionante',
                latitudine: posizioneCorrenteLat,
                longitudine: posizioneCorrenteLng,
                note: _noteController.text,
              );
              Navigator.of(ctx).pop();
              _salvaIdranteSuSupabase(nuovo);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _mostraDialogoModificaIdrante(PuntoIdrico idrante) {
    _codiceController.text = idrante.codice;
    _ubicazioneController.text = idrante.ubicazione;
    _noteController.text = idrante.note;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifica ${idrante.codice}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _ubicazioneController, decoration: const InputDecoration(labelText: 'Ubicazione')),
            TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              final agg = PuntoIdrico(
                id: idrante.id,
                codice: idrante.codice,
                tipo: idrante.tipo,
                ubicazione: _ubicazioneController.text,
                stato: idrante.stato,
                latitudine: idrante.latitudine,
                longitudine: idrante.longitudine,
                note: _noteController.text,
              );
              Navigator.of(ctx).pop();
              _aggiornaIdranteSuSupabase(agg);
            },
            child: const Text('Aggiorna'),
          ),
        ],
      ),
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
  final String note;
  final String creatoDa;
  final String modificatoDa;

  PuntoIdrico({
    required this.id,
    required this.codice,
    required this.tipo,
    required this.ubicazione,
    required this.stato,
    required this.latitudine,
    required this.longitudine,
    this.note = '',
    this.creatoDa = '',
    this.modificatoDa = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'codice': codice,
      'tipo': tipo,
      'ubicazione': ubicazione,
      'stato': stato,
      'latitudine': latitudine,
      'longitudine': longitudine,
      'note': note,
    };
  }

  factory PuntoIdrico.fromMap(Map<String, dynamic> map) {
    return PuntoIdrico(
      id: map['id']?.toString() ?? '',
      codice: map['codice']?.toString() ?? 'IDR-00',
      tipo: map['tipo']?.toString() ?? 'Idrante Soprasuolo',
      ubicazione: map['ubicazione']?.toString() ?? 'N/D',
      stato: map['stato']?.toString() ?? 'Funzionante',
      latitudine: double.tryParse(map['latitudine']?.toString() ?? '0') ?? 0.0,
      longitudine: double.tryParse(map['longitudine']?.toString() ?? '0') ?? 0.0,
      note: map['note']?.toString() ?? '',
      creatoDa: map['creato_da']?.toString() ?? '',
      modificatoDa: map['modificato_da']?.toString() ?? '',
    );
  }
}