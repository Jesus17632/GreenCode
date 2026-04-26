import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../api_service.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map_geojson/flutter_map_geojson.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/greenbot_service.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  // ───── PALETA AQUA TRANQUILO / LETRAS OSCURAS ─────
  static const Color _kPrimary     = Color(0xFF7ABFCC);
  static const Color _kPrimaryMid  = Color(0xFF5EA8B7);
  static const Color _kPrimaryDark = Color(0xFF3D8A99);
  static const Color _kPrimarySoft = Color(0xFFC2E4EB);
  static const Color _kAccent      = Color(0xFF95D0DA);
  static const Color _kPrimaryGhost= Color(0xFFF0F8FA);

  static const Color _kBg      = Color(0xFFF4F9FA);
  static const Color _kSurface = Color(0xFFFFFFFF);
  static const Color _kSidebar = Color(0xFFE8F3F6);
  static const Color _kBorder  = Color(0xFFADD6DF);
  static const Color _kDivider = Color(0xFFCFE8ED);

  static const Color _kInk     = Color(0xFF0F2D33);
  static const Color _kInkMid  = Color(0xFF1A4F5A);
  static const Color _kInkSoft = Color(0xFF3D7A85);

  // ───── COLORES POR CAPA ─────
  static const Color _kColorPuebla     = Color(0xFF5A7F8A);
  static const Color _kColorAtlixco    = Color(0xFF5EA8B7);
  static const Color _kColorUsoSuelo   = Color(0xFF9E6B45);
  static const Color _kColorEdafologia = Color(0xFF3DAB6E);

  final MapController _mapController = MapController();
  final LatLng _initialCenter = const LatLng(19.0414, -98.2063);
  double _currentZoom = 9.0;
  bool _mapExpanded = false;

  final ScrollController _carouselScrollDesktop = ScrollController();
  final ScrollController _carouselScrollMobile  = ScrollController();
  static const double _cardWidth       = 370.0;
  static const double _cardWidthMobile = 280.0;
  static const double _carouselSpeed   = 40.0;

  // Mobile sheets
  bool _mobileLayersOpen  = false;
  bool _mobileChatOpen    = false;
  bool _mobileCropsOpen   = false; // ← nueva

//CHAT BOT
  final GreenBotService _greenBot = GreenBotService();
  final ScrollController _scrollController = ScrollController();
  bool _cargando = false;
  

  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocus = FocusNode();

  // ─── Capas
  late final List<Map<String, dynamic>> _capas = [
    {
      'nombre': 'Estado de Puebla',
      'subtitulo': 'límite estatal y municipios',
      'color': _kColorPuebla,
      'asset': 'assets/geojson/mapaPuebla.geojson',
      'activa': false,
      'parser': _makeParser(_kColorPuebla),
      'loaded': false,
    },
    {
      'nombre': 'Valle de Atlixco',
      'subtitulo': 'zona agrícola del valle',
      'color': _kColorAtlixco,
      'asset': 'assets/geojson/ValleAtlixco.geojson',
      'activa': false,
      'parser': _makeParser(_kColorAtlixco),
      'loaded': false,
    },
    {
      'nombre': 'Edafología',
      'subtitulo': 'tipos y perfiles de suelo',
      'color': _kColorEdafologia,
      'asset': 'assets/geojson/valleAtlixco_edafología.geojson',
      'activa': false,
      'parser': _makeParser(_kColorEdafologia),
      'loaded': false,
    },
    {
      'nombre': 'Uso de suelo',
      'subtitulo': 'cobertura y uso del territorio',
      'color': _kColorUsoSuelo,
      'asset': 'assets/geojson/valleAtlixco_usoSuelo.geojson',
      'activa': false,
      'parser': _makeParser(_kColorUsoSuelo),
      'loaded': false,
    },
  ];

  static GeoJsonParser _makeParser(Color color) {
    return GeoJsonParser(
      defaultPolygonBorderColor: color,
      defaultPolygonFillColor:   color.withOpacity(0.22),
      defaultPolygonBorderStroke: 2.0,
      defaultPolylineColor: color,
      defaultPolylineStroke: 2.5,
      defaultMarkerColor: color,
    );
  }
  

  // ─── KPIs (carrusel)
  final List<Map<String, dynamic>> _apis = [
    {'icono': Icons.thermostat_rounded,  'valor': '21°',    'label': 'Temperatura',   'tag': 'Templado',  'color': const Color(0xFFE07A3A)},
    {'icono': Icons.water_drop_rounded,  'valor': '72%',    'label': 'Humedad suelo', 'tag': 'Alta',      'color': const Color(0xFF3AAFC4)},
    {'icono': Icons.cloud_rounded,       'valor': '2 mm',   'label': 'Precipitación', 'tag': 'Baja',      'color': const Color(0xFF6B55CC)},
    {'icono': Icons.air_rounded,         'valor': '10 km/h','label': 'Viento',        'tag': 'Suave',     'color': const Color(0xFF3A7ACC)},
    {'icono': Icons.wb_sunny_rounded,    'valor': '6.5',    'label': 'Índice UV',     'tag': 'Moderado',  'color': const Color(0xFFCC9500)},
    {'icono': Icons.compost_rounded,     'valor': 'pH 6.8', 'label': 'Acidez suelo',  'tag': 'Óptimo',    'color': const Color(0xFF2EA855)},
  ];

  // ─── Distribución de cultivos
  final List<_CropData> _cultivos = const [
    _CropData('Maíz',     320.5, Color(0xFFD4A017)),
    _CropData('Frijol',   180.2, Color(0xFFCC4444)),
    _CropData('Aguacate', 240.7, Color(0xFF2EA855)),
    _CropData('Café',     120.4, Color(0xFF9E6B45)),
    _CropData('Caña',      95.3, Color(0xFF6B55CC)),
    _CropData('Tomate',    65.9, Color(0xFF2E9BAA)),
  ];

  final List<Map<String, dynamic>> _chatMessages = [
    {'from': 'bot', 'text': '👋 ¡Hola! Soy GreenBot.\nPronto podré ayudarte con tu parcela.'},
  ];

  late final TextStyle _displayStyle;
  late final TextStyle _bodyStyle;

  late final AnimationController _carouselCtrl;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeHeader;
  late final Animation<double> _fadeCarousel;
  late final Animation<double> _fadeCrops;
  late final Animation<double> _fadeMap;
  late final Animation<double> _fadeChat;
  late final Animation<double> _fadeSidebar;

  @override
  void initState() {
    super.initState();
    _loadClimateData();

    _displayStyle = GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, letterSpacing: -0.8);
    _bodyStyle    = GoogleFonts.inter();

    _carouselCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _carouselCtrl.addListener(_onCarouselTick);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeSidebar  = _stagger(0.00, 0.45);
    _fadeHeader   = _stagger(0.05, 0.50);
    _fadeCarousel = _stagger(0.15, 0.65);
    _fadeCrops    = _stagger(0.25, 0.75);
    _fadeMap      = _stagger(0.35, 0.85);
    _fadeChat     = _stagger(0.45, 1.00);

    WidgetsBinding.instance.addPostFrameCallback((_) => _fadeCtrl.forward());
  }

  Animation<double> _stagger(double begin, double end) {
    return CurvedAnimation(
      parent: _fadeCtrl,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _ensureCapaLoaded(int index) async {
    final capa = _capas[index];
    if (capa['loaded'] == true) return;
    try {
      final data = await rootBundle.loadString(capa['asset'] as String);
      (capa['parser'] as GeoJsonParser).parseGeoJsonAsString(data);
      capa['loaded'] = true;
    } catch (e) {
      debugPrint('❌ Error cargando ${capa['asset']}: $e');
    }
  }

  Future<void> _toggleCapa(int index) async {
    final capa = _capas[index];
    final nuevaActiva = !(capa['activa'] as bool);
    if (nuevaActiva && !(capa['loaded'] as bool)) {
      await _ensureCapaLoaded(index);
    }
    if (!mounted) return;
    setState(() => _capas[index]['activa'] = nuevaActiva);
  }

  void _onCarouselTick() {
    final secs = (_carouselCtrl.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;
    _scrollTo(_carouselScrollDesktop, secs, _cardWidth);
    _scrollTo(_carouselScrollMobile,  secs, _cardWidthMobile);
  }

  void _scrollTo(ScrollController sc, double totalSecs, double cardW) {
    if (!sc.hasClients) return;
    final max = sc.position.maxScrollExtent;
    if (max <= 0) return;
    final pos = (_carouselSpeed * totalSecs) % (max + cardW);
    sc.jumpTo(pos.clamp(0.0, max));
  }

  Future<void> _loadClimateData() async {
    try {
      final frost = await ApiService.getFrostCheck();
      setState(() {
        final todayMin = frost['air_temperature']['today_min_celsius'];
        _apis[0]['valor'] = '$todayMin°';
        final soilTemp = frost['soil_temperature']['lst_celsius'];
        _apis[1]['valor'] = '$soilTemp°';
      });
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  @override
  void dispose() {
    _carouselCtrl.removeListener(_onCarouselTick);
    _carouselCtrl.dispose();
    _fadeCtrl.dispose();
    _carouselScrollDesktop.dispose();
    _carouselScrollMobile.dispose();
    _chatController.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

Future<void> _sendMessage() async {
  final text = _chatController.text.trim();
  if (text.isEmpty || _cargando) return;

  // 1. Agrega el mensaje del usuario y limpia el input
  setState(() {
    _chatMessages.add({'from': 'user', 'text': text});
    _chatController.clear();
    _cargando = true;
    // Indicador de "escribiendo..."
    _chatMessages.add({'from': 'bot', 'text': '...'});
  });

  _scrollChatToBottom();

  // 2. Llama a Gemini
  try {
    final respuesta = await _greenBot.enviarMensaje(text);

    if (!mounted) return;
    setState(() {
      // Quita el "..." y agrega la respuesta real
      _chatMessages.removeLast();
      _chatMessages.add({'from': 'bot', 'text': respuesta});
      _cargando = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _chatMessages.removeLast();
      _chatMessages.add({
        'from': 'bot',
        'text': '⚠️ Hubo un error al conectar con GreenBot.',
      });
      _cargando = false;
    });
  }

  _scrollChatToBottom();
}

void _scrollChatToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}

  Widget _fadeIn(Animation<double> anim, Widget child, {double dy = 12}) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * dy),
          child: child,
        ),
      ),
    );
  }

  

  // ─────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: false,
      floatingActionButton: LayoutBuilder(
        builder: (context, _) {
          final isMobile = MediaQuery.of(context).size.width < 720;
          if (!isMobile) return const SizedBox.shrink();
          return _ChatFab(
            primary: _kPrimary,
            primaryDark: _kPrimaryDark,
            onTap: () => setState(() => _mobileChatOpen = true),
          );
        },
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;
            return Stack(
              children: [
                if (isMobile) _buildMobileLayout(context) else _buildDesktopLayout(),
                if (isMobile) ...[
                  if (_mobileLayersOpen)
                    _MobileSheet(
                      onClose: () => setState(() => _mobileLayersOpen = false),
                      title: 'Bases de datos',
                      child: _buildLayersList(compact: true),
                    ),
                  if (_mobileChatOpen)
                    _MobileSheet(
                      onClose: () => setState(() => _mobileChatOpen = false),
                      title: 'GreenBot',
                      fullHeight: true,
                      child: _buildChatBody(),
                    ),
                  // ── Drum picker de cultivos
                  if (_mobileCropsOpen)
                    _CropsDrumSheet(
                      cultivos: _cultivos,
                      bodyStyle: _bodyStyle,
                      displayStyle: _displayStyle,
                      onClose: () => setState(() => _mobileCropsOpen = false),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // DESKTOP LAYOUT
  // ─────────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          width: _mapExpanded ? 0 : 300,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: 300,
              minWidth: 300,
              child: _fadeIn(_fadeSidebar, _buildSidebar(), dy: 0),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                child: _mapExpanded
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          _fadeIn(_fadeHeader, _buildTopHeader()),
                          const SizedBox(height: 4),
                          _fadeIn(
                            _fadeCarousel,
                            _buildInfiniteCarousel(
                              scrollController: _carouselScrollDesktop,
                              leftPad: 24,
                              height: 168,
                              cardWidth: _cardWidth,
                            ),
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _mapExpanded ? 16 : 24,
                    _mapExpanded ? 16 : 10,
                    _mapExpanded ? 16 : 24,
                    _mapExpanded ? 16 : 24,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _fadeIn(_fadeMap, _buildMapCard()),
                            ),
                            if (!_mapExpanded) ...[
                              const SizedBox(height: 14),
                              _fadeIn(
                                _fadeCrops,
                                _CropsCard(
                                  cultivos: _cultivos,
                                  bodyStyle: _bodyStyle,
                                  displayStyle: _displayStyle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                        width: _mapExpanded ? 0 : 20,
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                        width: _mapExpanded ? 0 : 420,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerRight,
                            maxWidth: 420,
                            minWidth: 420,
                            child: _fadeIn(_fadeChat, _buildChatPanel()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // MOBILE LAYOUT — sin CropsCard, con FAB de cultivos
  // ─────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _fadeIn(
            _fadeHeader,
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kPrimarySoft, _kPrimary, _kPrimaryDark],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: _kAccent.withOpacity(0.40), blurRadius: 14, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: const Icon(Icons.eco_rounded, color: Colors.white, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bienvenido',
                      style: _displayStyle.copyWith(fontSize: 28, color: _kInk),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kPrimaryGhost,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _kBorder, width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, color: _kPrimaryDark, size: 16),
                        const SizedBox(width: 5),
                        Text(
                          'Puebla',
                          style: _bodyStyle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          _fadeIn(
            _fadeCarousel,
            _buildInfiniteCarousel(
              scrollController: _carouselScrollMobile,
              leftPad: 16,
              height: 134,
              cardWidth: _cardWidthMobile,
            ),
          ),

          // ── Botón pill "Cultivos" en lugar de la tarjeta completa
          _fadeIn(
            _fadeCrops,
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: _CropsPillButton(
                cultivos: _cultivos,
                bodyStyle: _bodyStyle,
                displayStyle: _displayStyle,
                onTap: () => setState(() => _mobileCropsOpen = true),
              ),
            ),
          ),

          SizedBox(
            height: math.max(
              420,
              MediaQuery.of(context).size.height - 480,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: _fadeIn(
                _fadeMap,
                Stack(
                  children: [
                    _buildMapCard(),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: _LayersFab(
                        primary: _kPrimary,
                        primaryDark: _kPrimaryDark,
                        accent: _kAccent,
                        activeCount: _capas.where((c) => c['activa'] == true).length,
                        onTap: () => setState(() => _mobileLayersOpen = true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // SIDEBAR
  // ─────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(
        color: _kSidebar,
        border: Border(right: BorderSide(color: _kBorder, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kDivider, width: 0.8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kPrimarySoft, _kPrimary, _kPrimaryDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: _kAccent.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'GreenCode',
                  style: _displayStyle.copyWith(
                    fontSize: 26,
                    color: _kInk,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_kPrimarySoft, _kPrimary, _kPrimaryDark],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'BASES DE DATOS',
                  style: _bodyStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildLayersList()),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kDivider, width: 0.8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: _kInkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toca para activar/desactivar cada capa',
                    style: _bodyStyle.copyWith(fontSize: 15, color: _kInkMid, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayersList({bool compact = false}) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12, vertical: compact ? 8 : 4),
      itemCount: _capas.length,
      itemBuilder: (context, i) {
        final capa = _capas[i];
        final activa = capa['activa'] as bool;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 320 + (i * 60)),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _toggleCapa(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: activa ? _kSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: activa ? _kBorder : Colors.transparent,
                    width: 0.8,
                  ),
                  boxShadow: activa
                      ? [BoxShadow(color: _kAccent.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: activa
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  capa['color'],
                                  Color.lerp(capa['color'], Colors.black, 0.3)!,
                                ],
                              )
                            : null,
                        color: activa ? null : _kBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activa ? Colors.transparent : _kBorder,
                          width: 1.5,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: activa
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18, key: ValueKey(true))
                            : const SizedBox.shrink(key: ValueKey(false)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            capa['nombre'],
                            style: _bodyStyle.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _kInk,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            capa['subtitulo'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle.copyWith(
                              fontSize: 15,
                              color: _kInkMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 240),
                      opacity: activa ? 1.0 : 0.0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: capa['color'],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (capa['color'] as Color).withOpacity(0.7),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────
  Widget _buildTopHeader() {
    final now = DateTime.now();
    const dias  = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const meses = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
    final fechaStr = '${now.day} de ${meses[now.month - 1]}, ${now.year}';
    final diaStr   = dias[now.weekday - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Bienvenido de vuelta',
              style: _displayStyle.copyWith(fontSize: 40, color: _kInk),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _kPrimaryGhost,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(diaStr, style: _bodyStyle.copyWith(fontSize: 17, color: _kInk, fontWeight: FontWeight.w700)),
                Container(width: 1, height: 16, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 10)),
                Text(fechaStr, style: _bodyStyle.copyWith(fontSize: 17, color: _kInkMid)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: _kPrimaryGhost,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kBorder, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, color: _kPrimaryDark, size: 17),
                const SizedBox(width: 6),
                Text(
                  'Puebla, México',
                  style: _bodyStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // CARRUSEL INFINITO
  // ─────────────────────────────────────────────────
  Widget _buildInfiniteCarousel({
    required ScrollController scrollController,
    required double leftPad,
    required double height,
    required double cardWidth,
  }) {
    const repeats = 50;
    final totalItems = _apis.length * repeats;

    return SizedBox(
      height: height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => true,
        child: ListView.builder(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(left: leftPad, right: 8),
          itemCount: totalItems,
          itemExtent: cardWidth,
          itemBuilder: (context, i) {
            final api = _apis[i % _apis.length];
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
              child: _ApiCard(
                icon:         api['icono'],
                valor:        api['valor'],
                label:        api['label'],
                tag:          api['tag'],
                accent:       api['color'],
                bodyStyle:    _bodyStyle,
                displayStyle: _displayStyle,
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // MAPA
  // ─────────────────────────────────────────────────
  List<Widget> _buildActiveLayers() {
    final widgets = <Widget>[];
    for (final capa in _capas) {
      final activa = capa['activa'] as bool;
      final loaded = capa['loaded'] as bool;
      if (!activa || !loaded) continue;
      final parser = capa['parser'] as GeoJsonParser;
      widgets.add(PolygonLayer(polygons: parser.polygons));
      widgets.add(PolylineLayer(polylines: parser.polylines));
      widgets.add(MarkerLayer(markers: parser.markers));
    }
    return widgets;
  }

  Widget _buildMapCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _kBorder, width: 0.9),
          boxShadow: [
            BoxShadow(color: _kAccent.withOpacity(0.18), blurRadius: 32, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _currentZoom,
                minZoom: 4.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.greencodeapp',
                  maxZoom: 19,
                ),
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.greencodeapp',
                  maxZoom: 19,
                ),
                ..._buildActiveLayers(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _initialCenter,
                      width: 50,
                      height: 50,
                      child: const _PulsingMarker(color: _kPrimary),
                    ),
                  ],
                ),
              ],
            ),

            Positioned(
              top: 16,
              left: 16,
              child: _GlassControlStack(
                children: [
                  _GlassIconButton(
                    icon: Icons.add_rounded,
                    standalone: false,
                    onTap: () {
                      setState(() => _currentZoom++);
                      _mapController.move(_mapController.camera.center, _currentZoom);
                    },
                  ),
                  Container(height: 0.5, color: Colors.black.withOpacity(0.12)),
                  _GlassIconButton(
                    icon: Icons.remove_rounded,
                    standalone: false,
                    onTap: () {
                      setState(() => _currentZoom--);
                      _mapController.move(_mapController.camera.center, _currentZoom);
                    },
                  ),
                ],
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              child: _GlassIconButton(
                icon: _mapExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                size: 38,
                onTap: () => setState(() => _mapExpanded = !_mapExpanded),
              ),
            ),

            if (MediaQuery.of(context).size.width >= 720 || _mapExpanded)
              Positioned(
                left: 16,
                bottom: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(13, 11, 16, 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _kAccent.withOpacity(0.4), width: 0.9),
                        boxShadow: [
                          BoxShadow(color: _kAccent.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_kPrimarySoft, _kPrimary, _kPrimaryDark],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: _kAccent.withOpacity(0.50), blurRadius: 12, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 13),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mi parcela',
                                style: _bodyStyle.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: _kInk,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '19.0414, -98.2063',
                                style: _bodyStyle.copyWith(fontSize: 15, color: _kInkMid),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // CHAT
  // ─────────────────────────────────────────────────
  Widget _buildChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder, width: 0.9),
        boxShadow: [
          BoxShadow(color: _kAccent.withOpacity(0.16), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: _buildChatBody(),
      ),
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          decoration: BoxDecoration(
            color: _kPrimary,
            border: const Border(bottom: BorderSide(color: _kBorder, width: 0.8)),
          ),
          child: Row(
            children: [
              _BotAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GreenBot',
                      style: _displayStyle.copyWith(color: Colors.white, fontSize: 22, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const _OnlineDot(),
                        const SizedBox(width: 7),
                        Text(
                          'Asistente agrícola',
                          style: _bodyStyle.copyWith(color: Colors.white.withOpacity(0.90), fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            controller: _scrollController, // ← agrega esto
            itemCount: _chatMessages.length,
            itemBuilder: (context, i) {
              if (i == _chatMessages.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kPrimaryGhost,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorder, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _PulseDot(color: _kInkSoft),
                          const SizedBox(width: 8),
                          Text(
                            'API en desarrollo',
                            style: _bodyStyle.copyWith(
                              fontSize: 15,
                              color: _kInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final msg    = _chatMessages[i];
              final isUser = msg['from'] == 'user';
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(isUser ? (1 - t) * 14 : -(1 - t) * 14, 0),
                    child: child,
                  ),
                ),
                child: Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser ? _kPrimary : _kPrimaryGhost,
                      borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(16),
                        topRight:    const Radius.circular(16),
                        bottomLeft:  Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      border: isUser ? null : Border.all(color: _kBorder, width: 0.8),
                      boxShadow: isUser
                          ? [BoxShadow(color: _kAccent.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))]
                          : null,
                    ),
                    child: Text(
                      msg['text']!,
                      style: _bodyStyle.copyWith(
                        fontSize: 17,
                        height: 1.45,
                        color: isUser ? Colors.white : _kInk,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _kBorder, width: 0.8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _chatFocus.hasFocus ? _kPrimary : _kBorder,
                      width: _chatFocus.hasFocus ? 1.5 : 0.8,
                    ),
                    boxShadow: _chatFocus.hasFocus
                        ? [BoxShadow(color: _kAccent.withOpacity(0.20), blurRadius: 10, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: TextField(
                    controller: _chatController,
                    focusNode: _chatFocus,
                    enabled: !_cargando, // ← agrega
                    onTap: () => setState(() {}),
                    onSubmitted: (_) => _sendMessage(),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    style: _bodyStyle.copyWith(fontSize: 18, color: _kInk, letterSpacing: -0.2),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                      hintText: 'Escribe tu pregunta...',
                      hintStyle: _bodyStyle.copyWith(fontSize: 18, color: _kInkSoft, letterSpacing: -0.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(onTap: _sendMessage, primary: _kPrimary, primaryDark: _kPrimaryDark, accent: _kAccent),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// CROPS PILL BUTTON — botón compacto mobile
// ═══════════════════════════════════════════════════

class _CropsPillButton extends StatefulWidget {
  final List<_CropData> cultivos;
  final TextStyle bodyStyle;
  final TextStyle displayStyle;
  final VoidCallback onTap;

  const _CropsPillButton({
    required this.cultivos,
    required this.bodyStyle,
    required this.displayStyle,
    required this.onTap,
  });

  @override
  State<_CropsPillButton> createState() => _CropsPillButtonState();
}

class _CropsPillButtonState extends State<_CropsPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.cultivos.fold<double>(0, (s, c) => s + c.hectareas);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) => setState(() => _pressed = false),
      onTapCancel:   () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFADD6DF), width: 0.9),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF95D0DA).withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Mini donut
              SizedBox(
                width: 44,
                height: 44,
                child: CustomPaint(
                  painter: _MiniDonutPainter(data: widget.cultivos, total: total),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distribución de cultivos',
                      style: widget.displayStyle.copyWith(
                        fontSize: 17,
                        color: const Color(0xFF0F2D33),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${total.toStringAsFixed(0)} ha · ${widget.cultivos.length} cultivos',
                      style: widget.bodyStyle.copyWith(
                        fontSize: 14,
                        color: const Color(0xFF3D7A85),
                      ),
                    ),
                  ],
                ),
              ),
              // Color dots preview
              Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.cultivos.take(4).map((c) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                  ),
                )).toList(),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.expand_less_rounded, color: Color(0xFF7ABFCC), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDonutPainter extends CustomPainter {
  final List<_CropData> data;
  final double total;
  const _MiniDonutPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.35;
    final r = radius - stroke / 2;

    final track = Paint()
      ..color = const Color(0xFFE8F3F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, r, track);

    double startAngle = -math.pi / 2;
    const gap = 0.03;

    for (final c in data) {
      final sweep = (c.hectareas / total) * (2 * math.pi) - gap;
      if (sweep > 0) {
        final paint = Paint()
          ..color = c.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          startAngle,
          sweep,
          false,
          paint,
        );
      }
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniDonutPainter old) => false;
}

// ═══════════════════════════════════════════════════
// CROPS DRUM SHEET — rueda cilíndrica desplegable
// ═══════════════════════════════════════════════════

class _CropsDrumSheet extends StatefulWidget {
  final List<_CropData> cultivos;
  final TextStyle bodyStyle;
  final TextStyle displayStyle;
  final VoidCallback onClose;

  const _CropsDrumSheet({
    required this.cultivos,
    required this.bodyStyle,
    required this.displayStyle,
    required this.onClose,
  });

  @override
  State<_CropsDrumSheet> createState() => _CropsDrumSheetState();
}

class _CropsDrumSheetState extends State<_CropsDrumSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final FixedExtentScrollController _drumCtrl;
  int _selectedIndex = 0;

  static const double _itemExtent = 72.0;
  static const int _visibleItems  = 5;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
      ..forward();
    _drumCtrl = FixedExtentScrollController(initialItem: 0);
  }

  Future<void> _close() async {
    await _c.reverse();
    widget.onClose();
  }

  @override
  void dispose() {
    _c.dispose();
    _drumCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.cultivos.fold<double>(0, (s, c) => s + c.hectareas);
    final selected = widget.cultivos[_selectedIndex];

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Stack(
          children: [
            // Fondo oscuro
            GestureDetector(
              onTap: _close,
              child: Container(color: Colors.black.withOpacity(0.45 * t)),
            ),
            // Sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: (_itemExtent * _visibleItems + 260) * (t - 1),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, -10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFADD6DF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 16, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFC2E4EB), Color(0xFF7ABFCC), Color(0xFF3D8A99)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Distribución de cultivos',
                              style: widget.displayStyle.copyWith(
                                fontSize: 22,
                                color: const Color(0xFF0F2D33),
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _close,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F3F6),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(Icons.close_rounded, color: Color(0xFF0F2D33), size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(height: 0.8, color: const Color(0xFFCFE8ED)),
                    const SizedBox(height: 16),

                    // ── Drum + Info card lado a lado
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Cilindro / Drum picker
                          Expanded(
                            child: _buildDrum(total),
                          ),
                          const SizedBox(width: 18),
                          // ── Info card del cultivo seleccionado
                          _buildInfoCard(selected, total),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Mini barra horizontal de todos los cultivos
                    _buildStackedBar(total),

                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Drum cilíndrico
  Widget _buildDrum(double total) {
    final drumHeight = _itemExtent * _visibleItems;

    return SizedBox(
      height: drumHeight,
      child: Stack(
        children: [
          // Rueda principal
          ListWheelScrollView.useDelegate(
            controller: _drumCtrl,
            itemExtent: _itemExtent,
            diameterRatio: 1.6,
            perspective: 0.004,
            squeeze: 1.0,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) => setState(() => _selectedIndex = i),
            childDelegate: ListWheelChildLoopingListDelegate(
              children: widget.cultivos.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value;
                final isSelected = i == _selectedIndex;
                final pct = (c.hectareas / total * 100);

                return _DrumItem(
                  cultivo: c,
                  pct: pct,
                  isSelected: isSelected,
                  bodyStyle: widget.bodyStyle,
                );
              }).toList(),
            ),
          ),

          // Gradientes de desvanecimiento arriba/abajo
          IgnorePointer(
            child: Column(
              children: [
                Container(
                  height: _itemExtent * 1.8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  height: _itemExtent * 1.8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Líneas de selección
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 1.0, color: const Color(0xFF7ABFCC).withOpacity(0.6)),
                  SizedBox(height: _itemExtent - 2),
                  Container(height: 1.0, color: const Color(0xFF7ABFCC).withOpacity(0.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card de info del cultivo seleccionado
  Widget _buildInfoCard(_CropData c, double total) {
    final pct = c.hectareas / total * 100;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.color.withOpacity(0.35), width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono / color badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: c.color.withOpacity(0.45), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            c.name,
            style: widget.displayStyle.copyWith(
              fontSize: 22,
              color: const Color(0xFF0F2D33),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${c.hectareas.toStringAsFixed(1)} ha',
            style: widget.bodyStyle.copyWith(
              fontSize: 16,
              color: const Color(0xFF1A4F5A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          // Barra de porcentaje
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: c.color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(c.color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: widget.bodyStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra apilada horizontal
  Widget _buildStackedBar(double total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 0.5, color: const Color(0xFFCFE8ED)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: widget.cultivos.map((c) {
                  final flex = (c.hectareas / total * 1000).round();
                  return Expanded(
                    flex: flex,
                    child: Container(color: c.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Leyenda compacta
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: widget.cultivos.map((c) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    c.name,
                    style: widget.bodyStyle.copyWith(
                      fontSize: 13,
                      color: const Color(0xFF1A4F5A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Item individual del drum
class _DrumItem extends StatelessWidget {
  final _CropData cultivo;
  final double pct;
  final bool isSelected;
  final TextStyle bodyStyle;

  const _DrumItem({
    required this.cultivo,
    required this.pct,
    required this.isSelected,
    required this.bodyStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? cultivo.color.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isSelected
            ? Border.all(color: cultivo.color.withOpacity(0.40), width: 1.0)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 14 : 10,
            height: isSelected ? 14 : 10,
            decoration: BoxDecoration(
              color: cultivo.color,
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [BoxShadow(color: cultivo.color.withOpacity(0.6), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cultivo.name,
              style: bodyStyle.copyWith(
                fontSize: isSelected ? 19 : 16,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F2D33) : const Color(0xFF3D7A85),
                letterSpacing: -0.2,
              ),
            ),
          ),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: bodyStyle.copyWith(
              fontSize: isSelected ? 17 : 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? cultivo.color : const Color(0xFF3D7A85).withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// CULTIVOS (DESKTOP) — Card con donut chart + leyenda
// ═══════════════════════════════════════════════════

class _CropData {
  final String name;
  final double hectareas;
  final Color color;
  const _CropData(this.name, this.hectareas, this.color);
}

class _CropsCard extends StatelessWidget {
  final List<_CropData> cultivos;
  final TextStyle bodyStyle;
  final TextStyle displayStyle;

  const _CropsCard({
    required this.cultivos,
    required this.bodyStyle,
    required this.displayStyle,
  });

  @override
  Widget build(BuildContext context) {
    final total = cultivos.fold<double>(0, (sum, c) => sum + c.hectareas);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFADD6DF), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95D0DA).withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFC2E4EB), Color(0xFF7ABFCC), Color(0xFF3D8A99)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Distribución de cultivos',
                style: displayStyle.copyWith(
                  fontSize: 26,
                  color: const Color(0xFF0F2D33),
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F8FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFADD6DF), width: 0.8),
                ),
                child: Text(
                  '${cultivos.length} cultivos',
                  style: bodyStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A4F5A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: _DonutChart(
                  data: cultivos,
                  total: total,
                  bodyStyle: bodyStyle,
                  displayStyle: displayStyle,
                  centerSize: 34,
                  labelSize: 16,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: _CropsLegend(
                  cultivos: cultivos,
                  total: total,
                  bodyStyle: bodyStyle,
                  isMobile: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CropsLegend extends StatelessWidget {
  final List<_CropData> cultivos;
  final double total;
  final TextStyle bodyStyle;
  final bool isMobile;

  const _CropsLegend({
    required this.cultivos,
    required this.total,
    required this.bodyStyle,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    const cols = 2;
    final rows = (cultivos.length / cols).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (r) {
        return Padding(
          padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : 12),
          child: Row(
            children: List.generate(cols, (c) {
              final idx = r * cols + c;
              if (idx >= cultivos.length) return const Expanded(child: SizedBox());
              final cultivo = cultivos[idx];
              final pct = (cultivo.hectareas / total * 100).toStringAsFixed(1);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c == cols - 1 ? 0 : 14),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: cultivo.color,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(color: cultivo.color.withOpacity(0.5), blurRadius: 5),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cultivo.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bodyStyle.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F2D33),
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '$pct%',
                                  style: bodyStyle.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: cultivo.color,
                                  ),
                                ),
                                Text(
                                  '  ${cultivo.hectareas.toStringAsFixed(1)} ha',
                                  style: bodyStyle.copyWith(
                                    fontSize: 16,
                                    color: const Color(0xFF3D7A85),
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
              );
            }),
          ),
        );
      }),
    );
  }
}

class _DonutChart extends StatefulWidget {
  final List<_CropData> data;
  final double total;
  final TextStyle bodyStyle;
  final TextStyle displayStyle;
  final double centerSize;
  final double labelSize;

  const _DonutChart({
    required this.data,
    required this.total,
    required this.bodyStyle,
    required this.displayStyle,
    required this.centerSize,
    required this.labelSize,
  });

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final progress = Curves.easeOutCubic.transform(_c.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _DonutPainter(
                data: widget.data,
                total: widget.total,
                progress: progress,
              ),
            ),
            Opacity(
              opacity: progress,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.total.toStringAsFixed(0),
                    style: widget.displayStyle.copyWith(
                      fontSize: widget.centerSize,
                      color: const Color(0xFF0F2D33),
                      letterSpacing: -0.6,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'hectáreas',
                    style: widget.bodyStyle.copyWith(
                      fontSize: widget.labelSize,
                      color: const Color(0xFF3D7A85),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_CropData> data;
  final double total;
  final double progress;

  _DonutPainter({required this.data, required this.total, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.30;
    final r = radius - stroke / 2;

    final track = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, r, track);

    double startAngle = -math.pi / 2;
    const gap = 0.025;

    for (final c in data) {
      final fullSweep = (c.hectareas / total) * (2 * math.pi) - gap;
      final sweep = fullSweep * progress;
      if (sweep > 0) {
        final paint = Paint()
          ..color = c.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          startAngle,
          sweep,
          false,
          paint,
        );
      }
      startAngle += fullSweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.data != data || old.total != total;
}

// ═══════════════════════════════════════════════════
// COMPONENTES COMUNES
// ═══════════════════════════════════════════════════

class _ApiCard extends StatefulWidget {
  final IconData icon;
  final String valor;
  final String label;
  final String tag;
  final Color accent;
  final TextStyle bodyStyle;
  final TextStyle displayStyle;

  const _ApiCard({
    required this.icon,
    required this.valor,
    required this.label,
    required this.tag,
    required this.accent,
    required this.bodyStyle,
    required this.displayStyle,
  });

  @override
  State<_ApiCard> createState() => _ApiCardState();
}

class _ApiCardState extends State<_ApiCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(opacity: t, child: child);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.accent.withOpacity(0.30), width: 1.1),
          boxShadow: [
            BoxShadow(color: widget.accent.withOpacity(0.14), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.accent.withOpacity(0.35), width: 1.0),
              ),
              child: Icon(widget.icon, color: widget.accent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.valor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.displayStyle.copyWith(
                      fontSize: 28,
                      color: const Color(0xFF0F2D33),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.bodyStyle.copyWith(
                      fontSize: 16,
                      color: const Color(0xFF3D7A85),
                      letterSpacing: -0.1,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: widget.accent.withOpacity(0.35), width: 0.7),
                    ),
                    child: Text(
                      widget.tag,
                      style: widget.bodyStyle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color.lerp(widget.accent, Colors.black, 0.40),
                        letterSpacing: -0.1,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassControlStack extends StatelessWidget {
  final List<Widget> children;
  const _GlassControlStack({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF95D0DA).withOpacity(0.45), width: 0.9),
            boxShadow: [
              BoxShadow(color: const Color(0xFF95D0DA).withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool standalone;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = 38,
    this.standalone = true,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final core = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp:   (_) => setState(() => _pressed = false),
        onTapCancel:   () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : (_hovered ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _hovered ? 1.0 : 0.92,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (c, a) => RotationTransition(
                  turns: Tween(begin: 0.85, end: 1.0).animate(a),
                  child: ScaleTransition(scale: a, child: c),
                ),
                child: Icon(
                  widget.icon,
                  key: ValueKey(widget.icon),
                  color: const Color(0xFF0F2D33),
                  size: widget.size * 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.standalone) return core;

    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFF95D0DA).withOpacity(0.40), width: 0.9),
            boxShadow: [
              BoxShadow(color: const Color(0xFF95D0DA).withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 3)),
            ],
          ),
          child: core,
        ),
      ),
    );
  }
}

class _BotAvatar extends StatefulWidget {
  @override
  State<_BotAvatar> createState() => _BotAvatarState();
}

class _BotAvatarState extends State<_BotAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.6),
              blurRadius: 10,
            ),
          ],
        ),
        child: Transform.rotate(
          angle: 0.05 * (0.5 - (_c.value % 1.0)).abs(),
          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF3D8A99), size: 23),
        ),
      ),
    );
  }
}

class _OnlineDot extends StatefulWidget {
  const _OnlineDot();

  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.5 + 0.4 * _c.value),
              blurRadius: 4 + 4 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.4 + 0.6 * _c.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PulsingMarker extends StatefulWidget {
  final Color color;
  const _PulsingMarker({required this.color});

  @override
  State<_PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<_PulsingMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 50 * _c.value,
            height: 50 * _c.value,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.30 * (1 - _c.value)),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.3)!],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(0.65), blurRadius: 12, offset: const Offset(0, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color primary;
  final Color primaryDark;
  final Color accent;

  const _SendButton({
    required this.onTap,
    required this.primary,
    required this.primaryDark,
    required this.accent,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp:   (_) => setState(() => _pressed = false),
        onTapCancel:   () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : (_hovered ? 1.06 : 1.0),
          duration: const Duration(milliseconds: 130),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.accent, widget.primary, widget.primaryDark],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withOpacity(_hovered ? 0.60 : 0.40),
                  blurRadius: _hovered ? 16 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _LayersFab extends StatefulWidget {
  final VoidCallback onTap;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final int activeCount;

  const _LayersFab({
    required this.onTap,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.activeCount,
  });

  @override
  State<_LayersFab> createState() => _LayersFabState();
}

class _LayersFabState extends State<_LayersFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) => setState(() => _pressed = false),
      onTapCancel:   () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [widget.accent, widget.primary, widget.primaryDark],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: widget.accent.withOpacity(0.55), blurRadius: 22, offset: const Offset(0, 7)),
                ],
              ),
              child: const Icon(Icons.layers_rounded, color: Colors.white, size: 28),
            ),
            if (widget.activeCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFCC4444).withOpacity(0.5), blurRadius: 8),
                    ],
                  ),
                  child: Text(
                    '${widget.activeCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatFab extends StatefulWidget {
  final VoidCallback onTap;
  final Color primary;
  final Color primaryDark;

  const _ChatFab({required this.onTap, required this.primary, required this.primaryDark});

  @override
  State<_ChatFab> createState() => _ChatFabState();
}

class _ChatFabState extends State<_ChatFab> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp:   (_) => setState(() => _pressed = false),
        onTapCancel:   () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFC2E4EB), Color(0xFF7ABFCC), Color(0xFF3D8A99)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF95D0DA).withOpacity(0.45 + 0.25 * _glow.value),
                  blurRadius: 20 + 10 * _glow.value,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _MobileSheet extends StatefulWidget {
  final VoidCallback onClose;
  final String title;
  final Widget child;
  final bool fullHeight;

  const _MobileSheet({
    required this.onClose,
    required this.title,
    required this.child,
    this.fullHeight = false,
  });

  @override
  State<_MobileSheet> createState() => _MobileSheetState();
}

class _MobileSheetState extends State<_MobileSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 360))..forward();
  }

  Future<void> _close() async {
    await _c.reverse();
    widget.onClose();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq            = MediaQuery.of(context);
    final size          = mq.size;
    final keyboardHeight = mq.viewInsets.bottom;
    final hasKeyboard   = keyboardHeight > 0;
    final baseHeight    = widget.fullHeight ? size.height * 0.85 : size.height * 0.55;
    final sheetHeight   = hasKeyboard
        ? (size.height - keyboardHeight - 24).clamp(300.0, size.height)
        : baseHeight;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Stack(
          children: [
            GestureDetector(
              onTap: _close,
              child: Container(color: Colors.black.withOpacity(0.40 * t)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardHeight - sheetHeight * (1 - t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                height: sheetHeight,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(color: Color(0x35000000), blurRadius: 32, offset: Offset(0, -8)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 11, bottom: 6),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFADD6DF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F2D33),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _close,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F3F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.close_rounded, color: Color(0xFF0F2D33), size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 0.8, color: const Color(0xFFADD6DF)),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
}