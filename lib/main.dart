import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String supabaseUrl = 'https://srielrbjejggxvpeshfd.supabase.co';
const String supabaseApiKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNyaWVscmJqZWpnZ3h2cGVzaGZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczMjcwMzAsImV4cCI6MjEwMjkwMzAzMH0.3nX0meQZYEAIMEvuFSZVP0CTvgbTKES5bS5gDRDFa-c';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseApiKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            return const HomePage();
          }
          return const AuthPage();
        },
      ),
    );
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
  bool ricordaAccesso = true;
  bool _oscuraPassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _distaccamentoController = TextEditingController();
  final _siglaController = TextEditingController();
  String _ruoloSelezionato = 'OPERATORE';

  final List<String> ruoliDisponibili = ['OPERATORE', 'CAPOSQUADRA', 'DOS'];

  @override
  void initState() {
    super.initState();
    _caricaEmailSalvata();
  }

  Future<void> _caricaEmailSalvata() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
      });
    }
  }

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
    final emailTrimmed = _emailController.text.trim();

    try {
      if (isLogin) {
        final res = await supabase.auth.signInWithPassword(
          email: emailTrimmed,
          password: _passwordController.text.trim(),
        );

        final prefs = await SharedPreferences.getInstance();
        if (ricordaAccesso) {
          await prefs.setString('saved_email', emailTrimmed);
        } else {
          await prefs.remove('saved_email');
        }

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
      } else {
        if (_nomeController.text.isEmpty ||
            _cognomeController.text.isEmpty ||
            _distaccamentoController.text.isEmpty) {
          _mostraMessaggio('Compila tutti i campi obbligatori.', isError: true);
          setState(() => loading = false);
          return;
        }

        final res = await supabase.auth.signUp(
          email: emailTrimmed,
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
      _mostraMessaggio('Inserisci la tua email.', isError: true);
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      _mostraMessaggio('Email per il ripristino inviata!');
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
                      Image.asset(
                        'assets/logo.png',
                        height: 40,
                        errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, color: Colors.orange, size: 36),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isLogin ? 'Idranti AIB Cloud' : 'Registrazione Volontario',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!isLogin) ...[
                    TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome *')),
                    TextField(controller: _cognomeController, decoration: const InputDecoration(labelText: 'Cognome *')),
                    TextField(controller: _distaccamentoController, decoration: const InputDecoration(labelText: 'Distaccamento *')),
                    TextField(controller: _siglaController, decoration: const InputDecoration(labelText: 'Sigla Operativa')),
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
                  TextField(
                    controller: _passwordController,
                    obscureText: _oscuraPassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      suffixIcon: IconButton(
                        icon: Icon(_oscuraPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _oscuraPassword = !_oscuraPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isLogin)
                    CheckboxListTile(
                      title: const Text('Ricordami (Mantieni accesso)', style: TextStyle(fontSize: 13)),
                      value: ricordaAccesso,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() => ricordaAccesso = v ?? true),
                    ),
                  const SizedBox(height: 12),
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
  String _filtroSelezionato = 'Tutti';
  bool _usaMappaTopografica = false;

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
    if (!serviceEnabled) {
      _mostraMessaggio('Attiva il GPS del dispositivo.', isError: true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _mostraMessaggio('Permesso GPS negato.', isError: true);
        return;
      }
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
        _mostraMessaggio('Posizione GPS aggiornata!');
      }
    } catch (_) {
      _mostraMessaggio('Impossibile rilevare la posizione GPS.', isError: true);
    }
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
        _mostraMessaggio('Dati aggiornati da Supabase!');
      }
    } catch (_) {
      _mostraMessaggio('Errore di connessione (modalità offline attiva).', isError: true);
    } finally {
      setState(() => _caricamentoCloud = false);
    }
  }

  Future<void> _salvaIdranteSuSupabase(PuntoIdrico idrante) async {
    setState(() => _caricamentoCloud = true);
    try {
      final dataMap = idrante.toMap();
      dataMap['creato_da'] = '${mioProfilo?['nome_cognome']} (${mioProfilo?['ruolo']})';
      dataMap['modificato_da'] = '${mioProfilo?['nome_cognome']} (${mioProfilo?['ruolo']})';

      final response = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/idranti'),
        headers: _headers,
        body: json.encode(dataMap),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _caricaIdrantiDaSupabase();
        _mostraMessaggio('Punto idrico salvato!');
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

  Future<void> _cambiaStatoIdrante(PuntoIdrico idrante, String nuovoStato) async {
    setState(() => idrante.stato = nuovoStato);
    String operatoreCorrente = mioProfilo != null 
        ? '${mioProfilo!['nome_cognome']} (${mioProfilo!['ruolo']})' 
        : 'Operatore AIB';

    try {
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/idranti?id=eq.${idrante.id}'),
        headers: _headers,
        body: json.encode({
          'stato': nuovoStato,
          'modificato_da': operatoreCorrente,
        }),
      );
      _caricaIdrantiDaSupabase();
      _mostraMessaggio('Stato aggiornato a "$nuovoStato" da $operatoreCorrente');
    } catch (_) {}
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

  void _confermaEliminazioneIdrante(PuntoIdrico idrante) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Vuoi eliminare la voce ${idrante.codice} (${idrante.ubicazione})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _eliminaIdranteDaSupabase(idrante);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _mostraMessaggio(String testo, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testo),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        duration: const Duration(seconds: 2),
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

  String _convertiInUTM(double lat, double lon) {
    const double a = 6378137.0;
    const double f = 1.0 / 298.257223563;
    const double k0 = 0.9996;

    double latRad = lat * pi / 180.0;
    double lonRad = lon * pi / 180.0;

    int zoneNumber = ((lon + 180) / 6).floor() + 1;
    double lonOrigin = (zoneNumber - 1) * 6 - 180 + 3;
    double lonOriginRad = lonOrigin * pi / 180.0;

    double e2 = 2 * f - f * f;
    double ePrime2 = e2 / (1 - e2);

    double N = a / sqrt(1 - e2 * sin(latRad) * sin(latRad));
    double T = tan(latRad) * tan(latRad);
    double C = ePrime2 * cos(latRad) * cos(latRad);
    double A = cos(latRad) * (lonRad - lonOriginRad);

    double M = a * ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256) * latRad
        - (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * e2 * e2 * e2 / 1024) * sin(2 * latRad)
        + (15 * e2 * e2 / 256 + 45 * e2 * e2 * e2 / 1024) * sin(4 * latRad)
        - (35 * e2 * e2 * e2 / 3072) * sin(6 * latRad));

    double easting = k0 * N * (A + (1 - T + C) * A * A * A / 6
        + (5 - 18 * T + T * T + 72 * C - 58 * ePrime2) * A * A * A * A * A / 120) + 500000.0;

    double northing = k0 * (M + N * tan(latRad) * (A * A / 2
        + (5 - T + 9 * C + 4 * C * C) * A * A * A * A / 24
        + (61 - 58 * T + T * T + 600 * C - 330 * ePrime2) * A * A * A * A * A * A / 720));

    if (lat < 0) northing += 10000000.0;

    String banda = 'T';
    if (lat >= 56 && lat < 64) banda = 'U';
    if (lat >= 48 && lat < 56) banda = 'U';

    return '32$banda ${easting.toStringAsFixed(0)} E, ${northing.toStringAsFixed(0)} N';
  }

  // CONDIVISIONE CORRETTA PER APK E WEB
  void _condividiPuntoIdrico(PuntoIdrico idrante) async {
    String latGMS = _convertiInWGS84GMS(idrante.latitudine, true);
    String lngGMS = _convertiInWGS84GMS(idrante.longitudine, false);
    String utmStr = _convertiInUTM(idrante.latitudine, idrante.longitudine);

    List<String> attacchi = [];
    if (idrante.hasUni45) attacchi.add('UNI 45');
    if (idrante.hasUni70) attacchi.add('UNI 70');
    String attacchiStr = attacchi.isNotEmpty ? attacchi.join(', ') : 'Nessuno';

    String notaStrWeb = idrante.note.isNotEmpty ? '\n- Note: ${idrante.note}' : '';
    String mezziStrWeb = idrante.mezziCompatibili.isNotEmpty ? '\n- Mezzi: ${idrante.mezziCompatibili.join(', ')}' : '';
    String modStrWeb = idrante.modificatoDa.isNotEmpty ? '\n- Modifica: ${idrante.modificatoDa}' : '';

    String testoWeb = '''
*PUNTO IDRICO AIB*
- Codice: ${idrante.codice} (${idrante.tipo})
- Ubicazione: ${idrante.ubicazione}
- Accesso: ${idrante.isH24 ? "H24" : "Privato"}
- Stato: ${idrante.stato}
- Attacchi: $attacchiStr$mezziStrWeb$notaStrWeb$modStrWeb

- WGS84: $latGMS - $lngGMS
- UTM: $utmStr
- Mappa: https://www.google.com/maps/search/?api=1&query=${idrante.latitudine},${idrante.longitudine}
''';

    String notaStrApp = idrante.note.isNotEmpty ? '\n📝 Note: ${idrante.note}' : '';
    String mezziStrApp = idrante.mezziCompatibili.isNotEmpty ? '\n🚒 Mezzi: ${idrante.mezziCompatibili.join(', ')}' : '';
    String modStrApp = idrante.modificatoDa.isNotEmpty ? '\n👤 Modifica: ${idrante.modificatoDa}' : '';

    String testoApp = '''
🚨 *PUNTO IDRICO AIB*
📍 Codice: ${idrante.codice} (${idrante.tipo})
📌 Ubicazione: ${idrante.ubicazione}
🔑 Accesso: ${idrante.isH24 ? "H24" : "Privato"}
🟢 Stato: ${idrante.stato}
⚙️ Attacchi: $attacchiStr$mezziStrApp$notaStrApp$modStrApp

🌐 WGS84: $latGMS - $lngGMS
📐 UTM: $utmStr
🗺️ Mappa: https://www.google.com/maps/search/?api=1&query=${idrante.latitudine},${idrante.longitudine}
''';

    String testoFinale = kIsWeb ? testoWeb : testoApp;

    final Uri whatsappWebUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(testoFinale)}');
    final Uri whatsappDirectUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(testoFinale)}');
    
    try {
      if (kIsWeb) {
        await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
      } else {
        // Tenta l'apertura diretta di WhatsApp o di un app di messaggistica esterna
        if (await canLaunchUrl(whatsappDirectUri)) {
          await launchUrl(whatsappDirectUri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: testoFinale));
      _mostraMessaggio('Copiato negli appunti!');
    }
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

  Widget _buildIconaSimbolo(PuntoIdrico idrante, {double size = 20, Color? overrideColor}) {
    if (idrante.stato == 'Non Funzionante') {
      return Icon(Icons.close, size: size, color: overrideColor ?? Colors.white);
    }
    if (idrante.stato == 'Da Verificare') {
      return Icon(Icons.question_mark, size: size * 0.8, color: overrideColor ?? Colors.white);
    }
    if (idrante.tipo.contains('Vasca')) return IconaVascaAIB(size: size);
    if (idrante.tipo.contains('Presa')) return Icon(Icons.waves, size: size, color: overrideColor ?? Colors.white);
    return Icon(Icons.fire_hydrant_alt, size: size, color: overrideColor ?? Colors.white);
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

  void _mostraDettaglioIdrante(PuntoIdrico idrante, double distanzaKm) {
    _mapController.move(LatLng(idrante.latitudine, idrante.longitudine), 15.0);
    String latGMS = _convertiInWGS84GMS(idrante.latitudine, true);
    String lngGMS = _convertiInWGS84GMS(idrante.longitudine, false);
    String utmStr = _convertiInUTM(idrante.latitudine, idrante.longitudine);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(radius: 14, backgroundColor: _getColoreStato(idrante.stato), child: _buildIconaSimbolo(idrante, size: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text('Dettaglio ${idrante.codice}')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipologia: ${idrante.tipo}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Ubicazione: ${idrante.ubicazione}'),
              const SizedBox(height: 6),
              Text('Stato: ${idrante.stato}', style: TextStyle(fontWeight: FontWeight.bold, color: _getColoreStato(idrante.stato))),
              const SizedBox(height: 6),
              Text('Accesso: ${idrante.isH24 ? "H24 (Pubblico)" : "Proprietà Privata"}'),
              const SizedBox(height: 6),
              Text('Distanza: ${distanzaKm.toStringAsFixed(2)} km', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const Divider(),
              Text('WGS84: $latGMS - $lngGMS', style: const TextStyle(fontSize: 12)),
              Text('UTM: $utmStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              Text('Decimali: ${idrante.latitudine.toStringAsFixed(6)}, ${idrante.longitudine.toStringAsFixed(6)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const Divider(),
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(6)),
                  child: Text('Note: ${idrante.note}', style: const TextStyle(fontSize: 12)),
                ),
              ],
              if (idrante.modificatoDa.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Ultima modifica: ${idrante.modificatoDa}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.green), onPressed: () => _condividiPuntoIdrico(idrante), tooltip: 'Condividi su WhatsApp'),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Chiudi')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _richiediEAvviaNavigazione(idrante);
            },
            icon: const Icon(Icons.navigation, color: Colors.white),
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

  void _apriMappaFullscreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MappaFullscreenPage(
          listaIdranti: listaIdranti,
          posizioneLat: posizioneCorrenteLat,
          posizioneLng: posizioneCorrenteLng,
          usaMappaTopografica: _usaMappaTopografica,
          onTapIdrante: (idrante) {
            double dist = _calcolaDistanzaKm(posizioneCorrenteLat, posizioneCorrenteLng, idrante.latitudine, idrante.longitudine);
            _mostraDettaglioIdrante(idrante, dist);
          },
        ),
      ),
    );
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

  Widget _buildBadgeCasco(String ruolo) {
    Color coloreCasco = Colors.black;
    Color coloreStriscia = Colors.yellow[600]!;

    if (ruolo == 'DOS') coloreCasco = Colors.white;
    if (ruolo == 'CAPOSQUADRA') coloreCasco = Colors.red[700]!;
    if (ruolo == 'AMMINISTRATORE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.purple[800], borderRadius: BorderRadius.circular(4)),
        child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

  Widget _buildBadgeAttacco(String nome, bool disponibile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: disponibile ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: disponibile ? Colors.green[800]! : Colors.red[800]!, width: 1),
      ),
      child: Text(
        nome,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: disponibile ? Colors.green[900] : Colors.red[900]),
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
        onSelected: (_) => setState(() => _filtroSelezionato = etichetta),
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
          title: const Text('Pannello Gestione Utenti'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: utenti.length,
              itemBuilder: (context, index) {
                final u = utenti[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${u['nome_cognome']} (${u['distaccamento']})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Ruolo: ${u['ruolo']} - ${u['approvato'] ? "APPROVATO" : "IN ATTESA"}',
                                style: TextStyle(fontSize: 11, color: u['approvato'] ? Colors.green[800] : Colors.orange[800])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (!u['approvato'])
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          tooltip: 'Approva',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            await supabase.from('profili_utenti').update({'approvato': true}).eq('id', u['id']);
                            Navigator.of(ctx).pop();
                            _apriPannelloAdmin();
                            _controllaUtentiDaApprovare();
                          },
                        ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 105,
                        child: DropdownButtonFormField<String>(
                          value: u['ruolo'],
                          isDense: true,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: OutlineInputBorder(),
                          ),
                          items: ['OPERATORE', 'CAPOSQUADRA', 'DOS', 'AMMINISTRATORE']
                              .map((r) => DropdownMenuItem(value: r, child: Text(r == 'AMMINISTRATORE' ? 'ADMIN' : r, style: const TextStyle(fontSize: 10))))
                              .toList(),
                          onChanged: (nuovoRuolo) async {
                            if (nuovoRuolo != null) {
                              await supabase.from('profili_utenti').update({'ruolo': nuovoRuolo}).eq('id', u['id']);
                              Navigator.of(ctx).pop();
                              _apriPannelloAdmin();
                            }
                          },
                        ),
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

  void _mostraMenuProfilo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Profilo Operatore AIB'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👤 Nome: ${mioProfilo?['nome_cognome'] ?? "N/D"}', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 8),
              Text('🚒 Distaccamento: ${mioProfilo?['distaccamento'] ?? "N/D"}', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 8),
              Text('🏷️ Sigla Operativa: ${mioProfilo?['sigla'] ?? "N/D"}', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 8),
              Text('⭐ Ruolo: ${mioProfilo?['ruolo'] ?? "N/D"}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await Supabase.instance.client.auth.signOut();
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Disconnetti'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }

  bool get possoModificareEEliminare {
    final r = mioProfilo?['ruolo'];
    return r == 'CAPOSQUADRA' || r == 'DOS' || r == 'AMMINISTRATORE';
  }

  @override
  Widget build(BuildContext context) {
    final idrantiMostrati = _idrantiFiltratiEVicini;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        titleSpacing: 8,
        title: Image.asset(
          'assets/logo.png',
          height: 32,
          errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, color: Colors.orange),
        ),
        actions: [
          IconButton(
            icon: Icon(_usaMappaTopografica ? Icons.terrain : Icons.map),
            onPressed: () => setState(() => _usaMappaTopografica = !_usaMappaTopografica),
            tooltip: _usaMappaTopografica ? 'Passa a Mappa Standard' : 'Passa a Mappa Topografica',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _ottieniPosizioneGPS,
            tooltip: 'Aggiorna GPS',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _caricaIdrantiDaSupabase,
            tooltip: 'Ricarica',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          if (mioProfilo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Center(
                child: InkWell(
                  onTap: () => _mostraMenuProfilo(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBadgeCasco(mioProfilo!['ruolo']),
                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          if (mioProfilo?['ruolo'] == 'AMMINISTRATORE')
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: _apriPannelloAdmin,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                if (utentiDaApprovare > 0)
                  Positioned(
                    right: 4,
                    top: 8,
                    child: CircleAvatar(
                      radius: 7,
                      backgroundColor: Colors.red,
                      child: Text('$utentiDaApprovare', style: const TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 4),
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
                  const Text('Mappa AIB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  Row(
                    children: [
                      Text('GPS: ${posizioneCorrenteLat.toStringAsFixed(4)}, ${posizioneCorrenteLng.toStringAsFixed(4)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _apriMappaFullscreen,
                        child: const Row(
                          children: [
                            Icon(Icons.fullscreen, color: Colors.white, size: 16),
                            SizedBox(width: 2),
                            Text('Schermo Intero', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // MAPPA STANDARD CON BUSSOLA DIGITALE INTEGRATA
            SizedBox(
              height: 240,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(posizioneCorrenteLat, posizioneCorrenteLng),
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _usaMappaTopografica
                            ? 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: _usaMappaTopografica ? const ['a', 'b', 'c'] : const [],
                        userAgentPackageName: 'com.example.idranti_aib',
                        maxZoom: 17,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(posizioneCorrenteLat, posizioneCorrenteLng),
                            child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 30),
                          ),
                          ...idrantiMostrati.map((idrante) {
                            return Marker(
                              point: LatLng(idrante.latitudine, idrante.longitudine),
                              child: GestureDetector(
                                onTap: () => _mostraDettaglioIdrante(idrante, _calcolaDistanzaKm(posizioneCorrenteLat, posizioneCorrenteLng, idrante.latitudine, idrante.longitudine)),
                                child: CircleAvatar(
                                  backgroundColor: _getColoreStato(idrante.stato),
                                  child: _buildIconaSimbolo(idrante, size: 18),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                  // BUSSOLA DIGITALE NELL'ANGOLO SUPERIORE SINISTRO
                  Positioned(
                    left: 10,
                    top: 10,
                    child: WidgetBussolaDigitale(mapController: _mapController),
                  ),
                  // PULSANTE FULLSCREEN NELL'ANGOLO SUPERIORE DESTRO
                  Positioned(
                    right: 10,
                    top: 10,
                    child: FloatingActionButton.small(
                      heroTag: 'fullscreen_btn',
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      tooltip: 'Espandi Mappa a Schermo Intero',
                      onPressed: _apriMappaFullscreen,
                      child: const Icon(Icons.fullscreen, size: 24),
                    ),
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
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Idrante'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
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
                    onTap: () => _mostraDettaglioIdrante(idrante, dist),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: _getColoreStato(idrante.stato),
                            child: _buildIconaSimbolo(idrante, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${idrante.codice} - ${idrante.tipo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${idrante.ubicazione} (${idrante.isH24 ? "H24" : "Privato"})', style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildBadgeAttacco('UNI 45', idrante.hasUni45),
                                    const SizedBox(width: 6),
                                    _buildBadgeAttacco('UNI 70', idrante.hasUni70),
                                    const SizedBox(width: 8),
                                    Text('Dist: ${dist.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                                if (idrante.mezziCompatibili.isNotEmpty)
                                  Text('Mezzi: ${idrante.mezziCompatibili.join(', ')}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                if (idrante.note.isNotEmpty)
                                  Text('Note: ${idrante.note}', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amber[900])),
                                if (idrante.modificatoDa.isNotEmpty)
                                  Text('Modificato da: ${idrante.modificatoDa}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (possoModificareEEliminare)
                                      InkWell(
                                        onTap: () => _mostraDialogoModificaIdrante(idrante),
                                        child: const Padding(padding: EdgeInsets.only(right: 12.0), child: Icon(Icons.edit, size: 20, color: Colors.orange)),
                                      ),
                                    if (possoModificareEEliminare)
                                      InkWell(
                                        onTap: () => _confermaEliminazioneIdrante(idrante),
                                        child: const Padding(padding: EdgeInsets.only(right: 12.0), child: Icon(Icons.delete, size: 20, color: Colors.red)),
                                      ),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.build_circle, size: 20, color: Colors.blueGrey),
                                      onSelected: (st) => _cambiaStatoIdrante(idrante, st),
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'Funzionante', child: Text('Funzionante')),
                                        const PopupMenuItem(value: 'Non Funzionante', child: Text('Non Funzionante')),
                                        const PopupMenuItem(value: 'Da Verificare', child: Text('Da Verificare')),
                                      ],
                                    ),
                                    InkWell(
                                      onTap: () => _condividiPuntoIdrico(idrante),
                                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.share, size: 20, color: Colors.green)),
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

  void _mostraDialogoNuovoIdrante() {
    _latController.text = posizioneCorrenteLat.toStringAsFixed(4);
    _lngController.text = posizioneCorrenteLng.toStringAsFixed(4);
    _ubicazioneController.clear();
    _noteController.clear();
    String tipoSelezionato = tipologieDisponibili.first;
    bool hasUni45 = true;
    bool hasUni70 = true;
    bool isH24 = true;
    _codiceController.text = 'IDR-${listaIdranti.length + 1}';
    Map<String, bool> mezziSelezionati = {for (var m in mezziDisponibili) m: false};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuovo Idrante'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: tipoSelezionato,
                  items: tipologieDisponibili.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setDialogState(() => tipoSelezionato = v!),
                ),
                TextField(controller: _codiceController, decoration: const InputDecoration(labelText: 'Codice')),
                TextField(controller: _ubicazioneController, decoration: const InputDecoration(labelText: 'Ubicazione')),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _latController, decoration: const InputDecoration(labelText: 'Latitudine'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _lngController, decoration: const InputDecoration(labelText: 'Longitudine'))),
                  ],
                ),
                CheckboxListTile(title: const Text('UNI 45'), value: hasUni45, onChanged: (v) => setDialogState(() => hasUni45 = v ?? false)),
                CheckboxListTile(title: const Text('UNI 70'), value: hasUni70, onChanged: (v) => setDialogState(() => hasUni70 = v ?? false)),
                SwitchListTile(title: const Text('Accesso H24'), value: isH24, onChanged: (v) => setDialogState(() => isH24 = v)),
                const SizedBox(height: 8),
                const Text('Mezzi Compatibili:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...mezziDisponibili.map((mezzo) {
                  return CheckboxListTile(
                    title: Text(mezzo, style: const TextStyle(fontSize: 12)),
                    value: mezziSelezionati[mezzo] ?? false,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (s) => setDialogState(() => mezziSelezionati[mezzo] = s ?? false),
                  );
                }),
                TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () {
                List<String> selMezzi = mezziSelezionati.entries.where((e) => e.value).map((e) => e.key).toList();
                final nuovo = PuntoIdrico(
                  id: '',
                  codice: _codiceController.text,
                  tipo: tipoSelezionato,
                  ubicazione: _ubicazioneController.text,
                  stato: 'Funzionante',
                  latitudine: double.tryParse(_latController.text) ?? posizioneCorrenteLat,
                  longitudine: double.tryParse(_lngController.text) ?? posizioneCorrenteLng,
                  hasUni45: hasUni45,
                  hasUni70: hasUni70,
                  isH24: isH24,
                  mezziCompatibili: selMezzi,
                  note: _noteController.text,
                  modificatoDa: mioProfilo != null ? '${mioProfilo!['nome_cognome']} (${mioProfilo!['ruolo']})' : '',
                );
                Navigator.of(ctx).pop();
                _salvaIdranteSuSupabase(nuovo);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostraDialogoModificaIdrante(PuntoIdrico idrante) {
    _codiceController.text = idrante.codice;
    _ubicazioneController.text = idrante.ubicazione;
    _latController.text = idrante.latitudine.toString();
    _lngController.text = idrante.longitudine.toString();
    _noteController.text = idrante.note;
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
                TextField(controller: _ubicazioneController, decoration: const InputDecoration(labelText: 'Ubicazione')),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _latController, decoration: const InputDecoration(labelText: 'Latitudine'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _lngController, decoration: const InputDecoration(labelText: 'Longitudine'))),
                  ],
                ),
                CheckboxListTile(title: const Text('UNI 45'), value: hasUni45, onChanged: (v) => setDialogState(() => hasUni45 = v ?? false)),
                CheckboxListTile(title: const Text('UNI 70'), value: hasUni70, onChanged: (v) => setDialogState(() => hasUni70 = v ?? false)),
                SwitchListTile(title: const Text('Accesso H24'), value: isH24, onChanged: (v) => setDialogState(() => isH24 = v)),
                const SizedBox(height: 8),
                const Text('Mezzi Compatibili:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...mezziDisponibili.map((mezzo) {
                  return CheckboxListTile(
                    title: Text(mezzo, style: const TextStyle(fontSize: 12)),
                    value: mezziSelezionati[mezzo] ?? false,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (s) => setDialogState(() => mezziSelezionati[mezzo] = s ?? false),
                  );
                }),
                TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () {
                List<String> selMezzi = mezziSelezionati.entries.where((e) => e.value).map((e) => e.key).toList();
                final agg = PuntoIdrico(
                  id: idrante.id,
                  codice: idrante.codice,
                  tipo: idrante.tipo,
                  ubicazione: _ubicazioneController.text,
                  stato: idrante.stato,
                  latitudine: double.tryParse(_latController.text) ?? idrante.latitudine,
                  longitudine: double.tryParse(_lngController.text) ?? idrante.longitudine,
                  hasUni45: hasUni45,
                  hasUni70: hasUni70,
                  isH24: isH24,
                  mezziCompatibili: selMezzi,
                  note: _noteController.text,
                  modificatoDa: mioProfilo != null ? '${mioProfilo!['nome_cognome']} (${mioProfilo!['ruolo']})' : '',
                );
                Navigator.of(ctx).pop();
                _aggiornaIdranteSuSupabase(agg);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET BUSSOLA DIGITALE (ROSSA = NORD, GRIGIA = SUD, TOCCO = RESETTA ORIENTAMENTO)
class WidgetBussolaDigitale extends StatelessWidget {
  final MapController mapController;
  const WidgetBussolaDigitale({super.key, required.this.mapController});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        double rotation = mapController.camera.rotation;
        return GestureDetector(
          onTap: () {
            mapController.rotate(0);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Transform.rotate(
              angle: rotation * (pi / 180),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Punta freccia SUD (Grigia/Nera)
                  Positioned(
                    bottom: 6,
                    child: Container(
                      width: 4,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Punta freccia NORD (Rossa)
                  Positioned(
                    top: 6,
                    child: Container(
                      width: 4,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Centro della bussola
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// PAGINA DEDICATA ALLA MAPPA A TUTTO SCHERMO
class MappaFullscreenPage extends StatelessWidget {
  final List<PuntoIdrico> listaIdranti;
  final double posizioneLat;
  final double posizioneLng;
  final bool usaMappaTopografica;
  final Function(PuntoIdrico) onTapIdrante;

  const MappaFullscreenPage({
    super.key,
    required this.listaIdranti,
    required this.posizioneLat,
    required this.posizioneLng,
    required this.usaMappaTopografica,
    required this.onTapIdrante,
  });

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

  Widget _buildIconaSimbolo(PuntoIdrico idrante, {double size = 20}) {
    if (idrante.stato == 'Non Funzionante') return Icon(Icons.close, size: size, color: Colors.white);
    if (idrante.stato == 'Da Verificare') return Icon(Icons.question_mark, size: size * 0.8, color: Colors.white);
    if (idrante.tipo.contains('Vasca')) return IconaVascaAIB(size: size);
    if (idrante.tipo.contains('Presa')) return Icon(Icons.waves, size: size, color: Colors.white);
    return Icon(Icons.fire_hydrant_alt, size: size, color: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    final MapController fullscreenMapController = MapController();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        title: const Text('Mappa AIB - Schermo Intero'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Torna Indietro',
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: fullscreenMapController,
            options: MapOptions(initialCenter: LatLng(posizioneLat, posizioneLng), initialZoom: 14.0),
            children: [
              TileLayer(
                urlTemplate: usaMappaTopografica
                    ? 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: usaMappaTopografica ? const ['a', 'b', 'c'] : const [],
                userAgentPackageName: 'com.example.idranti_aib',
                maxZoom: 17,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(posizioneLat, posizioneLng),
                    child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 32),
                  ),
                  ...listaIdranti.map((idrante) {
                    return Marker(
                      point: LatLng(idrante.latitudine, idrante.longitudine),
                      child: GestureDetector(
                        onTap: () => onTapIdrante(idrante),
                        child: CircleAvatar(
                          backgroundColor: _getColoreStato(idrante.stato),
                          child: _buildIconaSimbolo(idrante, size: 18),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          Positioned(
            left: 15,
            top: 15,
            child: WidgetBussolaDigitale(mapController: fullscreenMapController),
          ),
        ],
      ),
    );
  }
}

class IconaVascaAIB extends StatelessWidget {
  final double size;
  const IconaVascaAIB({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue[300],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(child: Icon(Icons.waves, size: size * 0.6, color: Colors.white)),
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
    this.mezziCompatibili = const [],
    this.hasUni45 = true,
    this.hasUni70 = true,
    this.isH24 = true,
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
      'mezzicompatibili': mezziCompatibili.join(','),
      'hasuni45': hasUni45,
      'hasuni70': hasUni70,
      'ish24': isH24,
      'note': note,
      'modificato_da': modificatoDa,
    };
  }

  factory PuntoIdrico.fromMap(Map<String, dynamic> map5) {
    String mezziRaw = map5['mezzicompatibili']?.toString() ?? '';
    List<String> mezzi = mezziRaw.isNotEmpty ? mezziRaw.split(',') : [];

    return PuntoIdrico(
      id: map5['id']?.toString() ?? '',
      codice: map5['codice']?.toString() ?? 'IDR-00',
      tipo: map5['tipo']?.toString() ?? 'Idrante Soprasuolo',
      ubicazione: map5['ubicazione']?.toString() ?? 'N/D',
      stato: map5['stato']?.toString() ?? 'Funzionante',
      latitudine: double.tryParse(map5['latitudine']?.toString() ?? '0') ?? 0.0,
      longitudine: double.tryParse(map5['longitudine']?.toString() ?? '0') ?? 0.0,
      mezziCompatibili: mezzi,
      hasUni45: map5['hasuni45'] == true,
      hasUni70: map5['hasuni70'] == true,
      isH24: map5['ish24'] ?? true,
      note: map5['note']?.toString() ?? '',
      creatoDa: map5['creato_da']?.toString() ?? '',
      modificatoDa: map5['modificato_da']?.toString() ?? '',
    );
  }
}