import 'dart:async';
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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C4DFF)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF9F7FF),
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
  final _mapController = MapController();
  final _zones = const [
    _Zone('Station Zuid', 'Centrum', 'Hoog risico', Colors.red, Icons.train, LatLng(52.3380, 4.8737), 12),
    _Zone('Westerpark', 'Noord', 'Waarschuwing', Colors.orange, Icons.park, LatLng(52.3876, 4.8756), 7),
    _Zone('Museumplein', 'Zuid', 'Veilig', Colors.green, Icons.museum, LatLng(52.3580, 4.8815), 2),
  ];
  final _contacts = const [
    _Contact('Mama', '06 12 34 56 78', Icons.person),
    _Contact('Lotte', '06 23 45 67 89', Icons.person_2),
    _Contact('Bram', '06 98 76 54 32', Icons.person_3),
  ];
  int _page = 0, _activeZone = 0, _seconds = 0;
  bool _tracking = false, _notifications = true;
  double _risk = 18;
  LatLng _center = const LatLng(52.3676, 4.9041);
  Position? _position;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_tracking || !mounted) return;
      final zone = _zones[_activeZone];
      setState(() {
        _seconds += 5;
        final minutes = _seconds / 60;
        _risk = (18 + minutes * 8 + zone.minutes * minutes / 2).clamp(10.0, 96.0).toDouble();
      });
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _message('Zet GPS aan om je locatie te gebruiken.'); return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _message('Locatietoegang is nodig voor de kaart.'); return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() { _position = position; _center = LatLng(position.latitude, position.longitude); });
      _mapController.move(_center, 15);
    } catch (_) { _message('Kon je locatie niet ophalen.'); }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('SafeZone', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(onPressed: () => _message('Je hebt geen nieuwe meldingen.'), icon: Badge(isLabelVisible: _notifications, child: const Icon(Icons.notifications_outlined))),
            IconButton(onPressed: _settings, icon: const Icon(Icons.settings_outlined)),
          ],
        ),
        body: [_overview(), _mapPage(), _community(), _contacts()][_page],
        bottomNavigationBar: NavigationBar(
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
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          onPressed: _emergency,
          icon: const Icon(Icons.sos),
          label: const Text('112 / Noodknop'),
        ),
      );

  Widget _overview() {
    final zone = _zones[_activeZone];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
      Text('Goedenavond, blijf veilig', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Card(color: _tracking ? Colors.green.shade50 : null, child: SwitchListTile(
        secondary: CircleAvatar(backgroundColor: _tracking ? Colors.green : Colors.deepPurple.shade100, child: Icon(_tracking ? Icons.gps_fixed : Icons.gps_not_fixed)),
        title: Text(_tracking ? 'Tracking actief' : 'Tracking uit', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_tracking ? 'Je locatie wordt gevolgd.' : 'Schakel tracking in voor locatie-waarschuwingen.'),
        value: _tracking,
        onChanged: (value) { setState(() => _tracking = value); if (value) _locate(); },
      )),
      const SizedBox(height: 18),
      _header('Veiligheidsstatus', 'Kaart'), _riskCard(zone),
      const SizedBox(height: 18), _header('Aanbevolen zones', 'Alles bekijken'),
      ..._zones.map(_zoneTile),
    ]);
  }

  Widget _mapPage() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text('Veiligheidskaart', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6), const Text('Bekijk echte kaartdata en je actuele positie.'),
        const SizedBox(height: 18), _map(), const SizedBox(height: 18),
        const Text('Onveilige zones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ..._zones.map(_selectZone),
      ]);

  Widget _map() {
    final markers = _zones.map((zone) => Marker(point: zone.location, child: _Marker(color: zone.color, label: zone.name))).toList();
    if (_position != null) markers.add(Marker(point: LatLng(_position!.latitude, _position!.longitude), child: const _CurrentMarker()));
    return SizedBox(height: 300, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _center, initialZoom: 12.5),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.safezone'),
          MarkerLayer(markers: markers),
        ],
      ),
      Positioned(right: 12, bottom: 12, child: FloatingActionButton.small(onPressed: _locate, child: const Icon(Icons.my_location))),
    ])));
  }

  Widget _community() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text('Community', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), const Text('Delen van veilige of onveilige routes helpt iedereen.'),
        const SizedBox(height: 16), FilledButton.icon(onPressed: () => _message('Je melding is gedeeld met de community.'), icon: const Icon(Icons.add_location_alt), label: const Text('Meld een onveilige plek')),
        const SizedBox(height: 16),
        for (final report in const ['Slechte verlichting in de tunnel', 'Toezicht verhoogd bij Station Zuid', 'Veilige koffiebar open tot laat']) Card(child: ListTile(title: Text(report), subtitle: const Text('Community-melding'), trailing: const Icon(Icons.share_outlined))),
      ]);

  Widget _contacts() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text('Vertrouwde contacten', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), const Text('Deze personen ontvangen een melding als je hulp nodig hebt.'),
        const SizedBox(height: 16),
        ..._contacts.map((contact) => Card(child: ListTile(leading: CircleAvatar(child: Icon(contact.icon)), title: Text(contact.name), subtitle: Text(contact.phone), trailing: IconButton(onPressed: () => _message('Bellen naar ${contact.name}...'), icon: const Icon(Icons.phone_outlined))))),
      ]);

  Widget _header(String title, String action) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), TextButton(onPressed: () => setState(() => _page = 1), child: Text(action))]);

  Widget _riskCard(_Zone zone) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(backgroundColor: zone.color.withValues(alpha: .15), child: Icon(zone.icon, color: zone.color)), const SizedBox(width: 10), Expanded(child: Text('${zone.name}\n${zone.district} • ${zone.risk}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
        const SizedBox(height: 18), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Risiconiveau', style: TextStyle(fontWeight: FontWeight.bold)), Text('${_risk.round()}%')]),
        const SizedBox(height: 8), LinearProgressIndicator(value: _risk / 100, minHeight: 10, color: _risk > 70 ? Colors.red : _risk > 40 ? Colors.orange : Colors.green),
        const SizedBox(height: 10), Text(_risk > 70 ? 'Blijf alert en verlaat het gebied als dat mogelijk is.' : 'Houd je route in de gaten.'),
        Align(alignment: Alignment.centerRight, child: Text('Tijd in zone: ${_seconds ~/ 60} min ${_seconds % 60} s')),
      ])));

  Widget _zoneTile(_Zone zone) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: zone.color.withValues(alpha: .15), child: Icon(zone.icon, color: zone.color)), title: Text(zone.name), subtitle: Text('${zone.district} • ${zone.risk}'), trailing: IconButton(onPressed: () { setState(() { _activeZone = _zones.indexOf(zone); _risk = (18 + zone.minutes * 6).clamp(15, 90).toDouble(); }); _mapController.move(zone.location, 14); }, icon: const Icon(Icons.arrow_forward_ios))));

  Widget _selectZone(_Zone zone) => CheckboxListTile(value: _activeZone == _zones.indexOf(zone), onChanged: (_) { setState(() => _activeZone = _zones.indexOf(zone)); _mapController.move(zone.location, 14); }, secondary: Icon(zone.icon, color: zone.color), title: Text(zone.name), subtitle: Text('${zone.district} • ${zone.risk}'));

  void _settings() => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: SwitchListTile(title: const Text('Meldingen'), value: _notifications, onChanged: (value) { setState(() => _notifications = value); Navigator.pop(context); })));

  void _emergency() => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.warning_rounded, size: 52, color: Colors.red), const SizedBox(height: 12), const Text('Heb je direct hulp nodig?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () async { final uri = Uri(scheme: 'tel', path: '112'); if (await canLaunchUrl(uri)) await launchUrl(uri); if (mounted) Navigator.pop(context); }, icon: const Icon(Icons.phone), label: const Text('Bel 112'))),
        const SizedBox(height: 10), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); _message('Stille melding verzonden naar je contacten.'); }, icon: const Icon(Icons.notifications_active), label: const Text('Stille melding'))),
      ])));
}

class _Zone { final String name, district, risk; final Color color; final IconData icon; final LatLng location; final int minutes; const _Zone(this.name, this.district, this.risk, this.color, this.icon, this.location, this.minutes); }
class _Contact { final String name, phone; final IconData icon; const _Contact(this.name, this.phone, this.icon); }
class _Marker extends StatelessWidget { final Color color; final String label; const _Marker({required this.color, required this.label}); @override Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on, color: color, size: 30), Container(color: Colors.white70, padding: const EdgeInsets.all(2), child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))]); }
class _CurrentMarker extends StatelessWidget { const _CurrentMarker(); @override Widget build(BuildContext context) => Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 3)))); }
