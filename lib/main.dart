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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeZone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F7FF),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const SafeZoneHome(),
    );
  }
}

class SafeZoneHome extends StatefulWidget {
  const SafeZoneHome({super.key});

  @override
  State<SafeZoneHome> createState() => _SafeZoneHomeState();
}

class _SafeZoneHomeState extends State<SafeZoneHome> {
  final _mapController = MapController();
  final _zones = const [
    _Zone('Station Zuid', 'Centrum', 'Hoog risico', Colors.red, Icons.train,
        LatLng(52.3380, 4.8737), 12),
    _Zone('Westerpark', 'Noord', 'Waarschuwing', Colors.orange, Icons.park,
        LatLng(52.3876, 4.8756), 7),
    _Zone('Museumplein', 'Zuid', 'Veilig', Colors.green, Icons.museum,
        LatLng(52.3580, 4.8815), 2),
  ];
  final _trustedContacts = <_Contact>[
    _Contact('Mama', '06 12 34 56 78', Icons.person),
    _Contact('Lotte', '06 23 45 67 89', Icons.person_2),
    _Contact('Bram', '06 98 76 54 32', Icons.person_3),
  ];
  final _reports = <_Report>[
    _Report('Slechte verlichting in de tunnel', 'Onveilige verlichting',
        'Vandaag gemeld', LatLng(52.3665, 4.9000)),
    _Report('Toezicht verhoogd bij Station Zuid', 'Politie/toezicht',
        'Vandaag gemeld', LatLng(52.3380, 4.8737)),
    _Report('Veilige koffiebar open tot laat', 'Veilige plek', 'Vandaag gemeld',
        LatLng(52.3580, 4.8815)),
  ];
  final _notificationItems = <String>[
    'Westerpark heeft een nieuwe veiligheidsupdate.',
    'Je noodcontacten staan klaar voor gebruik.',
  ];

  int _page = 0;
  int _activeZone = 0;
  int _seconds = 0;
  bool _tracking = false;
  bool _notifications = true;
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
        _risk = (18 + minutes * 8 + zone.minutes * minutes / 2)
            .clamp(10.0, 96.0)
            .toDouble();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<LatLng?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _message('Zet GPS aan om je locatie te gebruiken.');
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _message('Locatietoegang is nodig voor deze functie.');
      return null;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return null;
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _position = position;
        _center = location;
      });
      return location;
    } catch (_) {
      _message('Kon je locatie niet ophalen.');
      return null;
    }
  }

  Future<void> _locate() async {
    final location = await _getLocation();
    if (location != null) {
      _mapController.move(location, 15);
      _message('Je locatie is gevonden.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeZone',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _showNotifications,
            icon: Badge(
              isLabelVisible: _notifications && _notificationItems.isNotEmpty,
              label: Text('${_notificationItems.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            onPressed: _settings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: _page,
        children: [_overview(), _mapPage(), _community(), _contactsPage()],
      ),
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
  }

  Widget _overview() {
    final zone = _zones[_activeZone];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Goedenavond, blijf veilig', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          color: _tracking ? Colors.green.shade50 : null,
          child: SwitchListTile(
            secondary: CircleAvatar(
              backgroundColor: _tracking ? Colors.green : Colors.deepPurple.shade100,
              child: Icon(_tracking ? Icons.gps_fixed : Icons.gps_not_fixed),
            ),
            title: Text(_tracking ? 'Tracking actief' : 'Tracking uit', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_tracking ? 'Je locatie wordt gevolgd.' : 'Schakel tracking in voor locatie-waarschuwingen.'),
            value: _tracking,
            onChanged: (value) async {
              setState(() => _tracking = value);
              if (value) await _locate();
              if (!value) _message('Tracking is gestopt.');
            },
          ),
        ),
        const SizedBox(height: 18),
        _header('Veiligheidsstatus', 'Kaart'),
        _riskCard(zone),
        const SizedBox(height: 18),
        _header('Aanbevolen zones', 'Alles bekijken'),
        ..._zones.map(_zoneTile),
      ],
    );
  }

  Widget _mapPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Veiligheidskaart', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Bekijk zones, meldingen en je actuele positie.'),
        const SizedBox(height: 18),
        _map(),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Meldingen op de kaart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          TextButton.icon(onPressed: _addReport, icon: const Icon(Icons.add), label: const Text('Toevoegen')),
        ]),
        ..._reports.map(_reportTile),
        const SizedBox(height: 10),
        const Text('Veiligheidszones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ..._zones.map(_selectZone),
      ],
    );
  }

  Widget _map() {
    final markers = _zones.map((zone) => Marker(point: zone.location, child: _Marker(color: zone.color, label: zone.name))).toList();
    markers.addAll(_reports.map((report) => Marker(point: report.location, child: _ReportMarker(isSafe: report.type == 'Veilige plek'))));
    if (_position != null) {
      markers.add(Marker(point: LatLng(_position!.latitude, _position!.longitude), child: const _CurrentMarker()));
    }
    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _center, initialZoom: 12.5),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.safezone'),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(right: 12, bottom: 12, child: FloatingActionButton.small(onPressed: _locate, child: const Icon(Icons.my_location))),
        ]),
      ),
    );
  }

  Widget _community() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Community', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Deel echte informatie met mensen in jouw buurt.'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _addReport, icon: const Icon(Icons.add_location_alt), label: const Text('Meld een onveilige plek')),
        const SizedBox(height: 16),
        ..._reports.map(_reportTile),
      ],
    );
  }

  Widget _contactsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('Vertrouwde contacten', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
          IconButton.filledTonal(onPressed: _addContact, icon: const Icon(Icons.person_add_alt_1)),
        ]),
        const SizedBox(height: 8),
        const Text('Deze personen ontvangen een melding als je hulp nodig hebt.'),
        const SizedBox(height: 16),
        ..._trustedContacts.map((contact) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(contact.icon)),
            title: Text(contact.name),
            subtitle: Text(contact.phone),
            trailing: IconButton(onPressed: () => _callContact(contact), icon: const Icon(Icons.phone)),
            onTap: () => _contactActions(contact),
          ),
        )),
      ],
    );
  }

  Widget _header(String title, String action) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          TextButton(onPressed: () => setState(() => _page = 1), child: Text(action)),
        ],
      );

  Widget _riskCard(_Zone zone) {
    final riskColor = _risk > 70 ? Colors.red : _risk > 40 ? Colors.orange : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [CircleAvatar(backgroundColor: zone.color.withValues(alpha: .15), child: Icon(zone.icon, color: zone.color)), const SizedBox(width: 10), Expanded(child: Text('${zone.name}\n${zone.risk}'))]),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Risiconiveau', style: TextStyle(fontWeight: FontWeight.bold)), Text('${_risk.round()}%')]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _risk / 100, minHeight: 10, color: riskColor, backgroundColor: riskColor.withValues(alpha: .15)),
          const SizedBox(height: 10),
          Text(_risk > 70 ? 'Blijf alert en verlaat het gebied als dat mogelijk is.' : 'Houd je route in de gaten.'),
          Align(alignment: Alignment.centerRight, child: Text('Tijd in zone: ${_seconds ~/ 60} min ${_seconds % 60} s')),
        ]),
      ),
    );
  }

  Widget _zoneTile(_Zone zone) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: zone.color.withValues(alpha: .15), child: Icon(zone.icon, color: zone.color)),
          title: Text(zone.name),
          subtitle: Text('${zone.district} · ${zone.risk}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() => _activeZone = _zones.indexOf(zone));
            setState(() => _page = 1);
            _mapController.move(zone.location, 14);
          },
        ),
      );

  Widget _selectZone(_Zone zone) => CheckboxListTile(
        value: _activeZone == _zones.indexOf(zone),
        onChanged: (_) {
          setState(() => _activeZone = _zones.indexOf(zone));
          _mapController.move(zone.location, 14);
          _message('${zone.name} geselecteerd.');
        },
        title: Text(zone.name),
        subtitle: Text(zone.risk),
        secondary: Icon(zone.icon, color: zone.color),
      );

  Widget _reportTile(_Report report) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: report.type == 'Veilige plek' ? Colors.green.shade100 : Colors.orange.shade100, child: Icon(report.type == 'Veilige plek' ? Icons.shield : Icons.warning_amber, color: report.type == 'Veilige plek' ? Colors.green : Colors.orange)),
          title: Text(report.title),
          subtitle: Text('${report.type} · ${report.time}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showReportDetails(report),
        ),
      );

  Future<void> _addReport() async {
    final titleController = TextEditingController();
    final detailsController = TextEditingController();
    String type = 'Onveilige plek';
    LatLng? location = _position == null ? null : LatLng(_position!.latitude, _position!.longitude);
    final result = await showDialog<_Report>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Nieuwe melding'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Wat wil je melden?')),
          const SizedBox(height: 12),
          TextField(controller: detailsController, maxLines: 2, decoration: const InputDecoration(labelText: 'Extra informatie (optioneel)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Type melding'), items: const [DropdownMenuItem(value: 'Onveilige plek', child: Text('Onveilige plek')), DropdownMenuItem(value: 'Politie/toezicht', child: Text('Politie/toezicht')), DropdownMenuItem(value: 'Veilige plek', child: Text('Veilige plek'))], onChanged: (value) => setDialogState(() => type = value!)),
          const SizedBox(height: 8),
          ListTile(contentPadding: EdgeInsets.zero, leading: Icon(location == null ? Icons.location_off : Icons.location_on, color: location == null ? Colors.grey : Colors.green), title: Text(location == null ? 'Geen locatie gekoppeld' : 'Locatie gekoppeld'), subtitle: Text(location == null ? 'Gebruik GPS voor een betere melding.' : 'Je huidige locatie wordt meegestuurd.'), trailing: TextButton(onPressed: () async { final newLocation = await _getLocation(); if (newLocation != null) setDialogState(() => location = newLocation); }, child: const Text('GPS'))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuleren')), FilledButton(onPressed: () { if (titleController.text.trim().isEmpty) { _message('Vul eerst een titel in.'); return; } Navigator.pop(dialogContext, _Report(titleController.text.trim(), type, 'Zojuist gemeld', location ?? _center, details: detailsController.text.trim())); }, child: const Text('Melding plaatsen'))],
      )),
    );
    titleController.dispose();
    detailsController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _reports.insert(0, result);
      _notificationItems.insert(0, 'Nieuwe melding geplaatst: ${result.title}');
    });
    _message('Melding geplaatst en zichtbaar op de kaart.');
  }

  void _showReportDetails(_Report report) {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(report.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(report.type), if (report.details.isNotEmpty) ...[const SizedBox(height: 12), Text(report.details)], const SizedBox(height: 16), FilledButton.icon(onPressed: () { Navigator.pop(context); setState(() => _page = 1); _mapController.move(report.location, 16); }, icon: const Icon(Icons.map), label: const Text('Toon op kaart'))])));
  }

  Future<void> _addContact() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final result = await showDialog<_Contact>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Vertrouwd contact toevoegen'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Naam')), const SizedBox(height: 12), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefoonnummer'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuleren')), FilledButton(onPressed: () { if (name.text.trim().isEmpty || phone.text.trim().isEmpty) { _message('Vul naam en telefoonnummer in.'); return; } Navigator.pop(dialogContext, _Contact(name.text.trim(), phone.text.trim(), Icons.person)); }, child: const Text('Toevoegen'))]));
    name.dispose();
    phone.dispose();
    if (result == null || !mounted) return;
    setState(() => _trustedContacts.add(result));
    _message('${result.name} is toegevoegd als vertrouwd contact.');
  }

  Future<void> _callContact(_Contact contact) async {
    final uri = Uri(scheme: 'tel', path: contact.phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _message('Bellen wordt niet ondersteund op dit apparaat.');
    }
  }

  void _contactActions(_Contact contact) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.phone), title: Text('Bel ${contact.name}'), onTap: () { Navigator.pop(context); _callContact(contact); }), ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Verwijder contact'), onTap: () { Navigator.pop(context); setState(() => _trustedContacts.remove(contact)); _message('${contact.name} is verwijderd.'); })])));
  }

  void _showNotifications() {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(title: const Text('Meldingen', style: TextStyle(fontWeight: FontWeight.bold)), trailing: TextButton(onPressed: () { setState(() => _notificationItems.clear()); Navigator.pop(sheetContext); }, child: const Text('Alles gelezen'))), if (_notificationItems.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Je bent helemaal bij.')) else ..._notificationItems.map((item) => ListTile(leading: const Icon(Icons.info_outline), title: Text(item)))])));
  }

  void _settings() {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: StatefulBuilder(builder: (context, setSheetState) => Column(mainAxisSize: MainAxisSize.min, children: [const ListTile(title: Text('Instellingen', style: TextStyle(fontWeight: FontWeight.bold))), SwitchListTile(title: const Text('Veiligheidsmeldingen'), subtitle: const Text('Ontvang updates over zones en meldingen.'), value: _notifications, onChanged: (value) { setState(() => _notifications = value); setSheetState(() {}); }), ListTile(leading: const Icon(Icons.info_outline), title: const Text('Over SafeZone'), onTap: () => _message('SafeZone helpt je bewuster en veiliger op pad te gaan.'))]))));
  }

  void _emergency() {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.warning_rounded, size: 52, color: Colors.red), const SizedBox(height: 12), const Text('Heb je direct hulp nodig?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () async { Navigator.pop(sheetContext); final uri = Uri(scheme: 'tel', path: '112'); if (await canLaunchUrl(uri)) { await launchUrl(uri); } else { _message('Bellen naar 112 wordt niet ondersteund op dit apparaat.'); } }, icon: const Icon(Icons.phone), label: const Text('Bel 112'))), const SizedBox(height: 10), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(sheetContext); setState(() => _notificationItems.insert(0, 'Stille noodmelding verzonden naar je contacten.')); _message('Stille melding verzonden naar je contacten.'); }, icon: const Icon(Icons.notifications_none), label: const Text('Stuur een stille melding')))]))));
  }
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
  final String title, type, time;
  final LatLng location;
  final String details;
  const _Report(this.title, this.type, this.time, this.location, {this.details = ''});
}

class _Marker extends StatelessWidget {
  final Color color;
  final String label;
  const _Marker({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))), Icon(Icons.location_on, color: color, size: 34)]);
}

class _ReportMarker extends StatelessWidget {
  final bool isSafe;
  const _ReportMarker({required this.isSafe});
  @override
  Widget build(BuildContext context) => Icon(Icons.flag, color: isSafe ? Colors.green : Colors.deepOrange, size: 28);
}

class _CurrentMarker extends StatelessWidget {
  const _CurrentMarker();
  @override
  Widget build(BuildContext context) => Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]));
}
