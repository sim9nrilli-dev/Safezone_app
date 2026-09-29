import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const SafeZoneApp());

class SafeZoneApp extends StatelessWidget {
  const SafeZoneApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SafeZone',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFA000)),
          scaffoldBackgroundColor: const Color(0xFFFFF8E1),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFFC107), foregroundColor: Colors.black87),
        ),
        home: const SafeZoneHome(),
      );
}

class SafeZoneHome extends StatefulWidget {
  const SafeZoneHome({super.key});
  @override
  State<SafeZoneHome> createState() => _SafeZoneHomeState();
}

class _SafeZoneHomeState extends State<SafeZoneHome> {
  final _map = MapController();
  late List<_Zone> _zones = [];
  late List<_Contact> _contacts = [];
  late List<_Report> _reports = [];

  int _page = 0;
  int _zone = 0;
  int _seconds = 0;
  double _risk = 18;
  bool _tracking = false;
  LatLng _center = const LatLng(52.3676, 4.9041);
  Position? _position;
  Timer? _timer;
  final _notifications = <String>[];

  @override
  void initState() {
    super.initState();
    _zones = [];
    _contacts = [];
    _reports = [];
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_tracking || !mounted) return;
      setState(() {
        _seconds += 5;
        final minutes = _seconds / 60;
        if (_zones.isNotEmpty) {
          _risk = (18 + minutes * 8 + _zones[_zone].minutes * minutes / 2).clamp(10.0, 96.0).toDouble();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _notify(String text) {
    if (!mounted) return;
    setState(() {
      _notifications.insert(0, text);
      if (_notifications.length > 10) _notifications.removeLast();
    });
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: const Color(0xFFFF8F00)));

  Future<LatLng?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack('Zet GPS aan om je locatie te gebruiken.');
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _snack('Locatietoegang is nodig voor deze functie.');
      return null;
    }
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return null;
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _position = position;
        _center = location;
      });
      return location;
    } catch (_) {
      _snack('Kon je locatie niet ophalen.');
      return null;
    }
  }

  Future<void> _locate() async {
    final location = await _getLocation();
    if (location != null) {
      _map.move(location, 15);
      _snack('Je locatie is gevonden.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('SafeZone', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(onPressed: _showNotifications, icon: const Icon(Icons.notifications_outlined)),
            IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings_outlined)),
          ],
        ),
        body: IndexedStack(index: _page, children: [_overview(), _mapPage(), _community(), _contactsPage()]),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFFFFB300),
          selectedIndex: _page,
          onDestinationSelected: (value) => setState(() => _page = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Overzicht'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Kaart'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Community'),
            NavigationDestination(icon: Icon(Icons.contacts_outlined), selectedIcon: Icon(Icons.contacts), label: 'Contacten'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          onPressed: _emergency,
          icon: const Icon(Icons.sos),
          label: const Text('112 / Noodknop'),
        ),
      );

  Widget _overview() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Text('Goedenavond, blijf veilig', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(elevation: 3, child: SwitchListTile(
            secondary: CircleAvatar(backgroundColor: _tracking ? const Color(0xFFFFC107) : Colors.grey, child: Icon(_tracking ? Icons.gps_fixed : Icons.gps_not_fixed)),
            title: Text(_tracking ? 'Tracking actief' : 'Tracking uit', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_tracking ? 'Je locatie wordt gevolgd.' : 'Schakel tracking in voor locatie-waarschuwingen.'),
            value: _tracking,
            onChanged: (value) async {
              setState(() => _tracking = value);
              if (value) {
                await _locate();
                _notify('Tracking gestart');
              } else {
                _snack('Tracking is gestopt.');
                _notify('Tracking gestopt');
              }
            },
          )),
          const SizedBox(height: 18),
          _section('Veiligheidsstatus'),
          if (_zones.isNotEmpty) _riskCard(),
          const SizedBox(height: 18),
          _section('Aanbevolen zones'),
          if (_zones.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Geen zones toegevoegd. Voeg zones toe via de kaart.')),
          ..._zones.map(_zoneTile),
        ],
      );

  Widget _section(String title) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        TextButton(onPressed: () => setState(() => _page = 1), child: const Text('Kaart', style: TextStyle(color: Color(0xFFE65100)))),
      ]);

  Widget _riskCard() {
    if (_zones.isEmpty) return const SizedBox.shrink();
    final zone = _zones[_zone];
    final color = _risk > 70 ? const Color(0xFFD32F2F) : (_risk > 40 ? const Color(0xFFFF8F00) : const Color(0xFFFFC107));
    return Card(elevation: 3, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(backgroundColor: Color.fromARGB((0.15 * 255).toInt(), zone.color.value >> 16 & 0xFF, zone.color.value >> 8 & 0xFF, zone.color.value & 0xFF), child: Icon(zone.icon, color: zone.color)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(zone.district)]))]),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Risiconiveau', style: TextStyle(fontWeight: FontWeight.bold)), Text('${_risk.round()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: _risk / 100, minHeight: 12, color: color),
      const SizedBox(height: 10),
      Text(_risk > 70 ? 'Blijf alert en verlaat het gebied als dat mogelijk is.' : 'Houd je route in de gaten.', style: TextStyle(color: color)),
      Align(alignment: Alignment.centerRight, child: Text('Tijd in zone: ${_seconds ~/ 60} min ${_seconds % 60} s', style: const TextStyle(fontSize: 12))),
    ])));
  }

  Widget _zoneTile(_Zone zone) => Card(elevation: 2, child: ListTile(
        leading: CircleAvatar(backgroundColor: Color.fromARGB((0.15 * 255).toInt(), zone.color.value >> 16 & 0xFF, zone.color.value >> 8 & 0xFF, zone.color.value & 0xFF), child: Icon(zone.icon, color: zone.color)),
        title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${zone.district} · ${zone.risk}'),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFE65100)),
        onTap: () {
          setState(() { _zone = _zones.indexOf(zone); _page = 1; _seconds = 0; });
          _map.move(zone.location, 14);
          _notify('Zone geselecteerd: ${zone.name}');
        },
      ));

  Widget _mapPage() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text('Veiligheidskaart', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6), const Text('Bekijk zones, meldingen en je actuele positie.'), const SizedBox(height: 18), _mapWidget(),
        const SizedBox(height: 18), const Text('Meldingen op de kaart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 8),
        if (_reports.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Geen meldingen. Voeg meldingen toe via Community.')),
        ..._reports.map(_reportTile),
      ]);

  Widget _mapWidget() {
    final markers = _zones.map((z) => Marker(point: z.location, child: _Marker(color: z.color, label: z.name))).toList();
    markers.addAll(_reports.map((r) => Marker(point: r.location, child: Icon(Icons.flag, color: r.type == 'Veilige plek' ? const Color(0xFFFFC107) : const Color(0xFFD32F2F), size: 32))));
    if (_position != null) markers.add(Marker(point: LatLng(_position!.latitude, _position!.longitude), child: const Icon(Icons.my_location, color: Colors.blue, size: 28)));
    return SizedBox(height: 300, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Stack(children: [
      FlutterMap(mapController: _map, options: MapOptions(initialCenter: _center, initialZoom: 12.5), children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.safezone'), MarkerLayer(markers: markers),
      ]),
      Positioned(right: 12, bottom: 12, child: FloatingActionButton.small(backgroundColor: const Color(0xFFFFC107), onPressed: _locate, child: const Icon(Icons.my_location))),
    ])));
  }

  Widget _community() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text('Community', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), const Text('Deel echte informatie met mensen in jouw buurt.'), const SizedBox(height: 16),
        FilledButton.icon(onPressed: _addReport, icon: const Icon(Icons.add_location_alt), label: const Text('Meld iets in je buurt'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF8F00))),
        const SizedBox(height: 16),
        if (_reports.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Geen meldingen. Voeg een melding toe om te beginnen.'))
        else ..._reports.map(_reportTile),
      ]);

  Widget _contactsPage() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text('Vertrouwde contacten', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), const Text('Deze personen ontvangen een melding als je hulp nodig hebt.'), const SizedBox(height: 16),
        FilledButton.icon(onPressed: _addContact, icon: const Icon(Icons.person_add), label: const Text('Contact toevoegen'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF8F00))),
        const SizedBox(height: 16),
        if (_contacts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Geen contacten toegevoegd. Voeg contacten toe voor noodgeval.'))
        else ..._contacts.map((c) => Card(elevation: 2, child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFFFFC107), child: Icon(c.icon)), 
          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Text(c.phone),
          trailing: IconButton(onPressed: () => _call(c), icon: const Icon(Icons.phone, color: Color(0xFFD32F2F))),
        ))),
      ]);

  Widget _reportTile(_Report report) => Card(elevation: 2, child: ListTile(
    leading: Icon(report.type == 'Veilige plek' ? Icons.shield : Icons.warning_amber, color: report.type == 'Veilige plek' ? const Color(0xFFFFC107) : const Color(0xFFD32F2F)),
    title: Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold)), 
    subtitle: Text(report.type), 
    trailing: const Icon(Icons.chevron_right), 
    onTap: () => _showReport(report),
  ));

  Future<void> _addReport() async {
    final title = TextEditingController();
    final details = TextEditingController();
    final result = await showDialog<_Report>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Nieuwe melding'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Wat wil je melden?', border: OutlineInputBorder())),
        const SizedBox(height: 12), TextField(controller: details, maxLines: 2, decoration: const InputDecoration(labelText: 'Extra informatie', border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuleren')), FilledButton(onPressed: () {
        if (title.text.trim().isEmpty) return;
        Navigator.pop(dialogContext, _Report(title.text.trim(), details.text.trim().isEmpty ? 'Onveilige plek' : details.text.trim(), _center));
      }, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF8F00)), child: const Text('Melden'))],
    ));
    title.dispose(); details.dispose();
    if (result != null && mounted) { setState(() => _reports.insert(0, result)); _notify('Nieuwe melding geplaatst: ${result.title}'); _snack('Melding geplaatst en zichtbaar op de kaart.'); }
  }

  Future<void> _addContact() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final result = await showDialog<_Contact>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Contact toevoegen'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Naam', border: OutlineInputBorder())),
        const SizedBox(height: 12), 
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefoonnummer', hintText: '06 12 34 56 78', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuleren')), FilledButton(onPressed: () {
        if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
          _snack('Vul alle velden in.');
          return;
        }
        Navigator.pop(dialogContext, _Contact(name.text.trim(), phone.text.trim(), Icons.person));
      }, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF8F00)), child: const Text('Toevoegen'))],
    ));
    name.dispose(); phone.dispose();
    if (result != null && mounted) { setState(() => _contacts.insert(0, result)); _notify('Contact toegevoegd: ${result.name}'); _snack('${result.name} is toegevoegd als vertrouwd contact.'); }
  }

  void _showReport(_Report report) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(report.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(report.type),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Sluiten'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _call(_Contact contact) async {
    final uri = Uri(scheme: 'tel', path: contact.phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) { await launchUrl(uri); _notify('Bellen naar ${contact.name}'); } else { _snack('Bellen wordt niet ondersteund op dit apparaat.'); }
  }

  void _showNotifications() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Meldingen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            if (_notifications.isEmpty)
              const Text('Geen meldingen')
            else
              Expanded(
                child: ListView(children: _notifications.map((n) => ListTile(title: Text(n))).toList()),
              ),
          ],
        ),
      ),
    ),
  );

  void _showSettings() => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const ListTile(title: Text('Instellingen', style: TextStyle(fontWeight: FontWeight.bold))),
    ListTile(leading: const Icon(Icons.notifications, color: Color(0xFFFFA000)), title: const Text('Meldingen inschakelen'), onTap: () { Navigator.pop(context); _snack('Meldingen zijn ingeschakeld.'); }),
    ListTile(leading: const Icon(Icons.privacy_tip, color: Color(0xFFFFA000)), title: const Text('Privacy & Veiligheid'), onTap: () { Navigator.pop(context); _snack('Privacy-instellingen geopend.'); }),
    ListTile(leading: const Icon(Icons.info, color: Color(0xFFFFA000)), title: const Text('Over SafeZone'), onTap: () { Navigator.pop(context); _snack('SafeZone versie 1.0.0'); }),
  ])));

  void _emergency() => showModalBottomSheet<void>(context: context, showDragHandle: true, backgroundColor: const Color(0xFFD32F2F), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.sos, color: Colors.white, size: 48),
    const SizedBox(height: 12),
    const Text('Bel 112 bij direct gevaar.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    FilledButton.icon(onPressed: () { Navigator.pop(context); _notify('Noodcontacten ingelicht'); _snack('Noodcontacten zijn ingelicht.'); }, icon: const Icon(Icons.person), label: const Text('Noodcontacten waarschuwen')),
    const SizedBox(height: 8),
    OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white)), child: const Text('Annuleren', style: TextStyle(color: Colors.white))),
  ]))));
}

class _Zone { 
  final String name, district, risk; 
  final Color color; 
  final IconData icon; 
  final LatLng location; 
  final int minutes; 
  const _Zone(this.name, this.district, this.risk, this.color, this.icon, this.location, this.minutes); 
}

class _Contact { 
  final String name, phone; 
  final IconData icon; 
  const _Contact(this.name, this.phone, this.icon); 
}

class _Report { 
  final String title, type; 
  final LatLng location; 
  const _Report(this.title, this.type, this.location); 
}

class _Marker extends StatelessWidget { 
  final Color color; 
  final String label; 
  const _Marker({required this.color, required this.label}); 
  @override 
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 40, height: 40, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: Center(child: Text(label.isNotEmpty ? label[0] : '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
    CustomPaint(painter: _TrianglePainter(color), size: const Size(10, 8)),
  ]); 
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()..moveTo(size.width / 2, 0)..lineTo(0, size.height)..lineTo(size.width, size.height)..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
