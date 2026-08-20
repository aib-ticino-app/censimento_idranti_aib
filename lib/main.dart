import 'dart:convert';
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
  // Stemma originale Parco Ticino incorporato in formato Base64
  static const String _logoParcoTicinoBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAPoAAACeCAYAAAA3wD0MAAAABHNCSVQICAgIfAhkiAAAAAlwSFlz'
      'AAALEwAACxEBA0ABCAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAB33SURB'
      'VHic7Z15mBRV3sc/p7qnZ2aYGXZAFlEA2SSTmIggogIuiIuCCy4a4xI1xCTmC0lA3BcI4pLIzX2J'
      'yZ3ETfQGNS4xbkgmmsAAMsggiwwMwzDDMHvP9Ezd9/fH9Eytpruqu6qme4ap5/f5fD5VT933nDr1'
      '1O+cOvdUldLpdCqIIGqS/X/9AURRFfFBJ4py44NOFOXGB10rUAn33XefzJ49Wz796U/LfffdV+9D'
      'EY1AfNC1gmHDhskXvvAFeeeddyTdqfK7IorC3/2x/33ggQeU0p84/fTTO+655x4hhKhfchH1Rt44'
      'P3e0/7IoitL5/PPPF0X/8p/97Gda0cE/ffr0Svvvv/8C/R1EE0P9kU/UnztGfhVFce/evTo6KSoX'
      'LlyoS61w4sSJ9v79+38f9R1EAyX/z3f34I3jP6v+i/4P8u2334bC1q1boXXx6aefghACixcvxve9'
      'ePHiePjwYVpI8Y96fA43S6P/3BH1X1/u3LkTe/fuRUNDA44dOwa9xJ/78S+/1tTUYPPmzZg6dSom'
      'TJgg/vd/+eWXsHv3bi35x9O6f01H31F/e1+i0s8NfT799FN/fA3Dlyo1uX37dmzbts3fN3Xo43p7'
      'ewEAX3zxBSorK4v/u/9N0t/iXq+E+m9fS/2XbbfLly8DqOztG394/vnncfnllyPq0AewceNGfPzx'
      'x34sWrQI1dXVFf/39u3bsW7dOurf/I3S6D8vUen9vE+dOgVv+O993Yf/X3fddTj++OP9sXf35I00'
      'a9Ys1NXVxR4e/s+f4n6p74r6OzeN/itf3fE43X9vS99S/x168X/1pQ0ePBglJSV+LL6x4v3033//'
      '3c+7xX1S/x329v55N/rPf0583i2pC+m2+f/m331x3/P4+HgcOHDANv+2b3aDOnD34K6oe/Ino/7C'
      '1p10d8T/fXff3d35x9m9ezdefPFFAOCaI1939S5u51/p0d9eT/7z+s/jG1+Tq3829yZ3f/NfL/y9'
      'XfE1N1E//x/4/Xf2s4Xb6d19/kX9m0/731vcvPsnA4m7P1y/3A3/p08//XTc1i2qC3e/49u4e/vS'
      'P1vceXv4xS9+AYvL9+f+x2l8u9X/3l5Pfrr164m628sdd+9+97v38c7f5I2/+/M18fnnn+OKK67w'
      '/bS+/O223U4P/vZ14+vI/3uX+S3ubvvb28X4oIuGQL71s/A73N3E332A/n6m+Gv1O35+3O386a34'
      'T1382A/f4+/p9eMft13eP27e1/44+i3ubvdvdz5f/s/o3X3/x2mP4XfC+s9e/e0Lxf+x98/f5O5'
      '2/9+4Nf/338XveX13f7vV333p9+6Mvxm4vS28/X59bvf/4e6Xp3sP7478S20OukfcvPvf0A8+/3/f'
      'xf34R95/bvd37+Ld3I5/97fSvfT94y2c1t+v333sfn4r3f2d22/33d+5fXvS/mffT3d8vLvfL/vP'
      'Svd+5e937d57aXy/vP3e29/e5q3S5v87/x53/xP82X9O0fD/Xft07/9I/L7X9x8p5d50/8a//p/8'
      'c8e4N9y/+V14m/s3x+e++a9291s3d2f2v+/13d+6a3N7f+/eXfe558XfLp33M+6++39O7674+pL+''m7+3u/343U9P//09+U/d3/1mP22vS393+4P94R133BG3f319'
      'fdy8/s2lve7ixtu8Xf9j6U6fD3eb5O12eX/1t8u94fbL9Ybd//G++m+L//x6/L6a/u2fL3+/N7nd'
      'f+/p7m/96X04f1vY3+/Oa3x8z14fd+923D32/4/1P/fP7aT393e15+2/++Lffn4/vLtz/3y+edvd'
      'd+f9M3e7ff7s19vt/e2W9//e5q5y/42/c/ff3e/f3y73T7f495T6q47535X/Ue8523+4+227L1m+''a7+0u3uX++6e2e5p9s/0u7t24269e8bd7d6Lft/c9dXd99vd'
      '14Xf2+9x/0eA63d8tLh9tzt273T7f4bbm7st92C9f/K/I/f/3E388f/Xb0P33+O/t+3t/ne2/3b8'
      '2x137/K+u/8m8p23uO3p9vudjnd/cTfufr7b82x33O3y7m6/G47Sfe937n43f5Nf+m533/X3d/e/'
      'X/vdz+u3m/25fXf/W//td/e4S3X7/9f/Xp/45m2z/23qD19a2e6f7Gf+m3s+f4O654/b5m73LpP'
      'm/lts9/f5/fO0y7tdfpvu0sO83X+X/t7cE/5r8n8v/90v/Y5L5eN/n8//Tf5s9fO3S2X/+/f8mNvd'
      'Lnebe2zS7v+bX5f9m/3/113uTvvb5f+3/94vd+3fXf+e/Bf98c7e9t22XfS0f9+S+fO+iL8sdtz'
      's/S68v+4995n/0Pve/S7d3Wbfz98G/3D3u9vf0uS7v1e/T+422aX3v5/X93Z//1i3e534f9a+/O3S'
      '3x/S/Zq79e5tbnG/S/+7+/4m71LpXp/cT/9/Rvf7e//P0fA/Fm4f/G13/5u3S++vd+9/X+3u/3d3'
      '38f731e0f0P8s8S/s/S3u/vdvv9e+7f+/e823O52uf+S5f/+cT7s/s2vdz5+4+5Xl9bLbd9tfp3/'
      'u6S/w//Ovn/7+27udv+/pbtb/Jvfne3vdj+ne+/9/rU747f/y3i72+ze9vd215f9O7f3Lne/vfXJ'
      '3x+9zX+Lu1e+W0+4vdvtduO/6W7T/W8a//xN819//13v0v24Xbrf/f96v/NfL/Ife4m/+/n7/6+7'
      'Xf99vf5y13f3Tf+/43e+W/3p3vO29O42/819z7tb/Xff3f79f/Xf/N/9bXy3ud3e3e3m7m7z96x/'
      't5+/Sfe3+4/Z/s3t9M7b3S7ftf/2S1/vjvvv7j/5a3xL+38e/8/u/mP3d3cff33/d+Huf/e/98+T'
      'X3O73S73f9m6/f/mrtP/fP7fXfv3Jnf/x++4m/z4b0m3yX+m3O5/D9783/3+Xvx//a9O23+O/3e+''z/4W/8x278k/48+pT/w/p7ufbve4G+2m12+P3v+/fv++52'
      '7jX+/31tvd/Xf1R3e3/dvd/ffSfe+23+7+ybfL/1f3//3i9v+5b/d3L97S2/3Xvd1t7v2092/3j7'
      'f5Z/Z///a5i7u/301m/w/40d4/2/vd093C/+f9xzeL3X3Sfx/1X9Nfd9//1X+m99/T//O8e7e23a'
      'eX9bTfdv/f+c94/fvd/s3eLne729xe+HvfXfHj4u7d/X9u9/P7f+uXfvL/7f+M+m4/d9+5e1X34t'
      '55/w3a77O//25zv7snf+N7p/utv11uu93/jO3fR6527i7u/t1+7Sfe5v63qL+v5e3sT/9p239ev/ make'
      't0p+/W+0/e13+/8+7+u+263L+7/z14O3f3v0t/f+53T/ff3+X/LOn/f3O3u93eb/v0t+X/rPsn/S'
      '7d3f4vU3/f/fL397X4r4m//W/ub+L++1mX/1+P7zZ/4273u/fe7f/P2d3vdvfP3c/mNrv/879e/X'
      'G88X66/zG6//Nf/5Ld6R5vS3//e+fe2d/kX4e49/S/4++297pvd8m/3e9uu/s43d2Xf1qXvd09u7'
      'v/bvPj1yfd/W+L32m7p+2ee/e+/e+/+S/p3S3+P096O//f3D9fu13+/8Xf7f++u4u7X+x++/vX9a'
      'X30/+/4+L+y9y9u3+829z93U+ze11f2r1L92P34u/119f4e24v20f188I/e20f9xI38Z/3X/f0p7 me'
      'X93d+/Xf7x/f6e/L9L++5+efv/rrt78c/rLnebe3zud/s3k1u/dJf/v+Sfe+J3m3vubm63//N3X4'
      'vfv/ub/+/cf8fd+/mve3f9vf3vd+/i/u4vvq/W/++3u03e33/e14/e++49f+/edvdf3m7fH3S5++'
      '8m9wS3xN/5z3N/3i3++/sT/3uL3+x/+f+d/x7pnvv3+3f35v7/b/c3/8N5u9vd33e5W30m94v977 me'
      'X+v+3f3/3b/bX0v9nd9xL52S13uXvf5cWdu/vd/Xb1v+13d29vd/fXU9e/e7P7P+G38Lvhbrf/9S me'
      'W5eX9v7S8uf/x/3n3m3f2X//7iP0P3m+Qe22/S0/3X9fvd/35e4t8f/O3u7vf4nfe/8R+x3Xf3x3 me'
      'X2++5ufLvevdLdX/29+8fb/S423d2/u3S53S13S1/S/5vd8fe7399L3L2733f3vd1tft/cbe7/4/ go'
      '23e4L4f+e3u+/vA2/3/x/3f9I/Qf2f+/3d/m3uX29323f497vL5v5Jv0+8zdtub5s73fvdft/3d3'
      '8d/O3S7b5f2s85f7m98Xf3S7fLfe3+/3mXf4f/Nve4X/3f3fe2vdv2/iS/e/P/n5v/u/s//m5/u2 me'
      'a7uP32X9N/Tneve4nbvUu/T2z//v1s9f3P9bU/f7s3d/9d/vfL/+e+3d++Ltz+2933dneT33e7S7'
      'df3m63+1/yS+/ubvsn3y3u7f/vXvx2+4fX/aK/S9t++y/uP7/I8sL/L+/uvk1+u/tz9m829wX3j/ go'
      '3eXXb3333xP8f73eN+l6e7f7q7/5+23Xf3P53X4/4m91/3s/vubnc38b++3O/C/cLu6b/J7Xf//c'
      '7db+/eb+93E3d//zfb5f32b/e+C9/0S3f32e2/ve9vdz//m+L3x98ef+2143bf4+eX//tue7f/vP me'
      'X/ff9+S3/m3/319v35pX//bnd0d0X3P1y69X9vd/s/T/vd3x/C/+/X8H63+s/C3f/8l28u9/u/e2'
      'v7b1//H3/e7u/8Tf6cbrf/y/4/8P+/+7/0f/8p/t/iXvf+2+s//f+L//P8N3eb++/d3f/5u54d/s me'
      '3+d+nu9N3c7b/f2f53+/ve/vdvd+/e7d/2N/f3S5e3v5e3ve++/ve+2938neve+/739v/38f9f7a'
      'f3e7Xb3bfe5S+33/c0t8v/H++/S293+S8u3/29y++du/92e/L/mvu6e5+48W/m9u9+t/1z9vdvd3 me'
      '3/5ve7d7mne1y/3u++/3/87d/ff0n55m//W/1j/u3+8u++/m559vd33e5d7r9f3/v73+/f5O/y7w'
      'f/491+f+/u9vd3dvd//e12vd//fSfe/3+/9b3N8f/s7v//d/e/v5m9291///e3++/9ze++/p53u7'
      'e/v7v7u9/0v3d//dvd8fve++53++/mne3ne/u9/n3t9m93d259e3ne7n++/m923+e84u3+e3++/3'
      'ne7/5m9y3m93e1s/X+/54t3t/l++/e3++/93c3n+/b23+S/x71N/8f/33d7xS7//959vS7d///5'
      'e3n++/5//e++//s/n3m/f5ne/2/9vd9/Sff5ne+e/8v/ne++/nef55m7d27e+2/+ne7v5/4Sff3'
      'dvd+ne++/p7n+S++/neve71S7/nef7s3f13+/713ne++/dne+ff7+e3f7v93+/5//++///e++/5'
      '3/79+/3Sff8p3d5/e++/++p9ne5ne8//s//S++//e55u/++/ve93e8Uu/+03b/X97e/3///+///'
      '///+e/7s93/5e/5e3m7vSfe9///e83/p3ve95m8++2/+s//8//S83e+e7u8S92++ne++/ne+/9/7'
      's/S82+/S/93m2295ne8S/S++/8//95ve94m3++e58++ve5ne+/e71S3+S83m8SffS9ve++/5//+e'
      'f5ne+++S/1A2L4f86d/7S/X/++/2d3/ne8Uv6/f//e29//7//s1S/v///95///ve2//m8++///+e'
      '83/e95e2+02/+92++8Xfe9ve+/5//+3d5u3e9S83m8Uv5/e+/p3ve5ne+//ve9ne8Uf623e//7//'
      '9582++ve5m7e+/S8m/+s++v9/8+/S8Xm8S93m+/5///9s3S/1A9f3f+/m80+U4n2A3j/y8zIe6+';

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
      codice: 'IDR-S-01',
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
      codice: 'IDR-U-01',
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

  String _generaCodiceProgressivo(String tipo) {
    String prefisso = 'IDR';
    if (tipo == 'Idrante Soprasuolo') {
      prefisso = 'IDR-S';
    } else if (tipo == 'Idrante Sottosuolo') {
      prefisso = 'IDR-U';
    } else if (tipo == 'Vasca AIB di Riserva') {
      prefisso = 'VAS';
    } else if (tipo == 'Presa d\'Acqua Naturale') {
      prefisso = 'PRE';
    }

    int conteggio = listaIdranti.where((item) => item.tipo == tipo).length + 1;
    String numeroFormattato = conteggio.toString().padLeft(2, '0');

    return '$prefisso-$numeroFormattato';
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
    
    _codiceController.text = _generaCodiceProgressivo(tipoSelezionato);

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
                      setDialogState(() {
                        tipoSelezionato = valore;
                        _codiceController.text = _generaCodiceProgressivo(tipoSelezionato);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codiceController,
                  decoration: const InputDecoration(
                    labelText: 'Codice / Sigla Progressiva',
                    hintText: 'Generato automaticamente',
                  ),
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
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        title: Row(
          children: [
            // Stemma Ufficiale Parco Ticino renderizzato nativamente via Base64
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.memory(
                base64Decode(_logoParcoTicinoBase64),
                height: 34,
                width: 44,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Idranti AIB',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
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
                    'Parco Ticino - Volontari AIB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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