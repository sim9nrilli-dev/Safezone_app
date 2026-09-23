import 'dart:async';
import 'package:flutter/material.dart';

void main() => runApp(const SafeZoneApp());

class SafeZoneApp extends StatefulWidget {
  const SafeZoneApp({super.key});

  @override
  State<SafeZoneApp> createState() => _SafeZoneAppState();
}

class _SafeZoneAppState extends State<SafeZoneApp> {
  bool _darkMode = false;
  bool _tracking = false;
  bool _notifications = true;
  int _contactAfter = 2;
  int _emergencyAfter = 5;

  final List<_Contact> _contacts = [
    _Contact('Mama', '06 12 34 56 78', Icons.person),
    _Contact('Lotte', '06 23 45 67 89', Icons.person_2),
    _Contact('Bram', '06 98 76 54 32', Icons.person_3),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeZone',
      debugShowCheckedModeBanner: false,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: SafeZoneHome(
        tracking: _tracking,
        notifications: _notifications,
        contacts: _contacts,
        contactAfter: _contactAfter,
        emergencyAfter: _emergencyAfter,
        onTrackingChanged: (value) => setState(() => _tracking = value),
        onOpenSettings: _showSettings,
        onContactsChanged: (contacts) => setState(() => _contacts
          ..clear()
          ..addAll(contacts)),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C4DFF),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF9F7FF)
          : const Color(0xFF121212),
    );
  }

  void _showSettings() {
    final contactController = TextEditingController(text: '$_contactAfter');
    final emergencyController = TextEditingController(text: '$_emergencyAfter');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Text('Instellingen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Dark mode'),
                  subtitle: const Text('Pas het uiterlijk van de app aan'),
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() => _darkMode = value);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Meldingen'),
                  value: _notifications,
                  onChanged: (value) {
                    setState(() => _notifications = value);
                    setSheetState(() {});
                  },
                ),
                const Divider(),
                const Text('Escalatie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(
                      controller: contactController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Contact na', suffixText: 'min', border: OutlineInputBorder()),
                      onChanged: (value) => _setMinutes(value, emergency: false),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: emergencyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '112 na', suffixText: 'min', border: OutlineInputBorder()),
                      onChanged: (value) => _setMinutes(value, emergency: true),
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Standaard: contact na 2 minuten en 112 na 5 minuten.'),
                const SizedBox(height: 16),
                const Text('Contacten', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ..._contacts.asMap().entries.map((entry) => ListTile(
                  leading: CircleAvatar(child: Icon(entry.value.icon)),
                  title: Text(entry.value.name),
                  subtitle: Text(entry.value.phone),
                  trailing: Wrap(children: [
                    IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editContact(entry.key)),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteContact(entry.key)),
                  ]),
                )),
                OutlinedButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Contact toevoegen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setMinutes(String value, {required bool emergency}) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    setState(() {
      if (emergency) {
        _emergencyAfter = parsed.clamp(1, 60);
      } else {
        _contactAfter = parsed.clamp(1, 30);
      }
    });
  }

  Future<void> _addContact() async {
    final contact = await _contactDialog();
    if (contact != null) setState(() => _contacts.add(contact));
  }

  Future<void> _editContact(int index) async {
    final contact = await _contactDialog(existing: _contacts[index]);
    if (contact != null) setState(() => _contacts[index] = contact);
  }

  void _deleteContact(int index) {
    if (_contacts.length == 1) return;
    setState(() => _contacts.removeAt(index));
  }

  Future<_Contact?> _contactDialog({_Contact? existing}) {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    var icon = existing?.icon ?? Icons.person;
    return showDialog<_Contact>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Contact toevoegen' : 'Contact bewerken'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Naam')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefoonnummer')),
          DropdownButtonFormField<IconData>(
            value: icon,
            decoration: const InputDecoration(labelText: 'Icoon'),
            items: const [
              DropdownMenuItem(value: Icons.person, child: Text('Persoon')),
              DropdownMenuItem(value: Icons.person_2, child: Text('Persoon 2')),
              DropdownMenuItem(value: Icons.person_3, child: Text('Persoon 3')),
              DropdownMenuItem(value: Icons.phone, child: Text('Telefoon')),
            ],
            onChanged: (value) => setDialogState(() => icon = value ?? Icons.person),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
            Navigator.pop(context, _Contact(name.text.trim(), phone.text.trim(), icon));
          }, child: const Text('Opslaan')),
        ],
      )),
    );
  }
}

class SafeZoneHome extends StatefulWidget {
  final bool tracking;
  final bool notifications;
  final List<_Contact> contacts;
  final int contactAfter;
  final int emergencyAfter;
  final ValueChanged<bool> onTrackingChanged;
  final VoidCallback onOpenSettings;
  final ValueChanged<List<_Contact>> onContactsChanged;

  const SafeZoneHome({super.key, required this.tracking, required this.notifications, required this.contacts, required this.contactAfter, required this.emergencyAfter, required this.onTrackingChanged, required this.onOpenSettings, required this.onContactsChanged});

  @override
  State<SafeZoneHome> createState() => _SafeZoneHomeState();
}

class _SafeZoneHomeState extends State<SafeZoneHome> {
  int _tab = 0;
  int _activeZone = 0;
  int _seconds = 0;
  double _risk = 18;
  Timer? _timer;
  final List<_DangerZone> _zones = [
    const _DangerZone('Station Zuid', 'Centrum', 'Hoog risico', Colors.red, Icons.train, 12, 0.22, 0.25),
    const _DangerZone('Westerpark', 'Noord', 'Waarschuwing', Colors.orange, Icons.park, 7, 0.68, 0.74),
    const _DangerZone('Museumplein', 'Zuid', 'Veilig', Colors.green, Icons.museum, 2, 0.78, 0.52),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!widget.tracking) return;
      setState(() {
        _seconds += 5;
        final minutes = _seconds / 60;
        _risk = (18 + minutes * 8 + _zones[_activeZone].minutes * minutes / 2).clamp(10.0, 96.0).toDouble();
      });
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _selectZone(int index) {
    if (index < 0 || index >= _zones.length) return;
    setState(() { _activeZone = index; _risk = (18 + _zones[index].minutes * 6).clamp(15.0, 90.0).toDouble(); });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_overview(), _map(), _community(), _contacts()];
    return Scaffold(
      appBar: AppBar(title: const Text('SafeZone', style: TextStyle(fontWeight: FontWeight.bold)), actions: [
        IconButton(onPressed: () => _message(widget.notifications ? 'Je hebt geen nieuwe meldingen.' : 'Meldingen staan uit.'), icon: Badge(isLabelVisible: widget.notifications, backgroundColor: Colors.red, child: const Icon(Icons.notifications_outlined))),
        IconButton(onPressed: widget.onOpenSettings, icon: const Icon(Icons.settings_outlined)),
      ]),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (value) => setState(() => _tab = value), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Overzicht'),
        NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Kaart'),
        NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Community'),
        NavigationDestination(icon: Icon(Icons.contacts_outlined), selectedIcon: Icon(Icons.contacts), label: 'Contacten'),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _emergency, backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, icon: const Icon(Icons.sos), label: const Text('112 / Noodknop')),
    );
  }

  Widget _overview() {
    final zone = _zones[_activeZone];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
      Text('Goedenavond, blijf veilig', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Card(child: SwitchListTile(secondary: CircleAvatar(child: Icon(widget.tracking ? Icons.gps_fixed : Icons.gps_not_fixed)), title: Text(widget.tracking ? 'Tracking actief' : 'Tracking uit'), subtitle: Text(widget.tracking ? 'Je locatie wordt gedeeld met vertrouwde contacten.' : 'Schakel tracking in voor zone-waarschuwingen.'), value: widget.tracking, onChanged: widget.onTrackingChanged)),
      const SizedBox(height: 18),
      const Text('Veiligheidsstatus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      _riskCard(zone),
      const SizedBox(height: 18),
      const Text('Aanbevolen zones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ..._zones.asMap().entries.map((entry) => _zoneTile(entry.key, entry.value)),
    ]);
  }

  Widget _riskCard(_DangerZone zone) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: zone.color.withOpacity(.15), child: Icon(zone.icon, color: zone.color)), title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), subtitle: Text('${zone.district} • ${zone.risk}')),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Risiconiveau', style: TextStyle(fontWeight: FontWeight.bold)), Text('${_risk.round()}%', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
    const SizedBox(height: 8), LinearProgressIndicator(value: _risk / 100, minHeight: 10, borderRadius: BorderRadius.circular(10), color: _risk > 70 ? Colors.red : _risk > 40 ? Colors.orange : Colors.green),
    const SizedBox(height: 10), Text('Tijd in zone: ${_seconds ~/ 60} min ${_seconds % 60} s'),
  ])));

  Widget _map() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
    Text('Veiligheidskaart', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 6), const Text('Tik op een marker om een zone te selecteren. Tik op een lege plek om een zone toe te voegen.'), const SizedBox(height: 18),
    SizedBox(height: 280, child: LayoutBuilder(builder: (context, constraints) => GestureDetector(onTapUp: (details) {
      final x = details.localPosition.dx / constraints.maxWidth; final y = details.localPosition.dy / 240;
      final index = _zones.indexWhere((zone) => (zone.x - x).abs() < .12 && (zone.y - y).abs() < .12);
      if (index >= 0) { _selectZone(index); } else { _editZone(); }
    }, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Theme.of(context).brightness == Brightness.dark ? const Color(0xff203040) : const Color(0xffdfeed9)), child: Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
      ..._zones.asMap().entries.map((entry) => Positioned(left: entry.value.x * constraints.maxWidth - 22, top: entry.value.y * 240 - 28, child: GestureDetector(onTap: () => _selectZone(entry.key), child: _Marker(color: entry.value.color, label: entry.value.name)))),
    ]))))),
    const SizedBox(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Zones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), TextButton.icon(onPressed: _editZone, icon: const Icon(Icons.add), label: const Text('Toevoegen'))]),
    ..._zones.asMap().entries.map((entry) => _zoneTile(entry.key, entry.value)),
  ]);

  Widget _zoneTile(int index, _DangerZone zone) => Card(color: index == _activeZone ? Theme.of(context).colorScheme.primaryContainer : null, child: ListTile(onTap: () => _selectZone(index), leading: CircleAvatar(backgroundColor: zone.color.withOpacity(.15), child: Icon(zone.icon, color: zone.color)), title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${zone.district} • ${zone.risk}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: () => _editZone(index: index), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () => _deleteZone(index), icon: const Icon(Icons.delete_outline))])));

  Widget _community() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [Text('Community', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 10), FilledButton.icon(onPressed: () => _message('Je melding is gedeeld met de community.'), icon: const Icon(Icons.add_location_alt), label: const Text('Meld een onveilige plek')), const SizedBox(height: 12), ...const [_Report('Slechte verlichting in de tunnel', 'Anoniem • 9 min geleden', Colors.orange, Icons.lightbulb), _Report('Toezicht verhoogd bij Station Zuid', 'Nora • 1 uur geleden', Colors.red, Icons.local_police), _Report('Veilige koffiebar open tot laat', 'Samira • 2 uur geleden', Colors.green, Icons.local_cafe)].map((report) => Card(child: ListTile(leading: CircleAvatar(child: Icon(report.icon, color: report.color)), title: Text(report.title), subtitle: Text(report.meta), trailing: IconButton(onPressed: () => _message('Verhaal is gedeeld.'), icon: const Icon(Icons.share_outlined)))))]);

  Widget _contacts() => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [Text('Vertrouwde contacten', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text('Melding na ${widget.contactAfter} minuten • 112 na ${widget.emergencyAfter} minuten'), const SizedBox(height: 12), ...widget.contacts.map((contact) => Card(child: ListTile(leading: CircleAvatar(child: Icon(contact.icon)), title: Text(contact.name), subtitle: Text(contact.phone), trailing: IconButton(onPressed: () => _message('Bellen naar ${contact.name}...'), icon: const Icon(Icons.phone_outlined)))))]);

  void _editZone({int? index}) {
    final existing = index == null ? null : _zones[index];
    final name = TextEditingController(text: existing?.name ?? 'Nieuwe zone');
    final district = TextEditingController(text: existing?.district ?? '');
    final risk = TextEditingController(text: existing?.risk ?? 'Waarschuwing');
    final minutes = TextEditingController(text: '${existing?.minutes ?? 5}');
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(index == null ? 'Zone toevoegen' : 'Zone bewerken'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Naam')), TextField(controller: district, decoration: const InputDecoration(labelText: 'Gebied')), TextField(controller: risk, decoration: const InputDecoration(labelText: 'Risico')), TextField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Risico-minuten'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')), FilledButton(onPressed: () { final zone = _DangerZone(name.text, district.text, risk.text, existing?.color ?? Colors.blue, existing?.icon ?? Icons.location_on, int.tryParse(minutes.text) ?? 5, existing?.x ?? .5, existing?.y ?? .5); setState(() { if (index == null) { _zones.add(zone); _activeZone = _zones.length - 1; } else { _zones[index] = zone; } }); Navigator.pop(context); }, child: const Text('Opslaan'))]));
  }

  void _deleteZone(int index) { if (_zones.length == 1) return; setState(() { _zones.removeAt(index); if (_activeZone >= _zones.length) _activeZone = _zones.length - 1; }); }
  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  void _emergency() => showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.warning, size: 52, color: Colors.red), const Text('Heb je direct hulp nodig?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 16), FilledButton.icon(onPressed: () { Navigator.pop(context); _message('112 wordt gebeld.'); }, icon: const Icon(Icons.phone), label: const Text('Bel 112')), OutlinedButton.icon(onPressed: () { Navigator.pop(context); _message('Stille melding verzonden.'); }, icon: const Icon(Icons.notifications_active), label: const Text('Stille melding'))]))));
}

class _Contact { final String name; final String phone; final IconData icon; const _Contact(this.name, this.phone, this.icon); }
class _DangerZone { final String name, district, risk; final Color color; final IconData icon; final int minutes; final double x, y; const _DangerZone(this.name, this.district, this.risk, this.color, this.icon, this.minutes, this.x, this.y); }
class _Report { final String title, meta; final Color color; final IconData icon; const _Report(this.title, this.meta, this.color, this.icon); }
class _Marker extends StatelessWidget { final Color color; final String label; const _Marker({required this.color, required this.label}); @override Widget build(BuildContext context) => Column(children: [Icon(Icons.location_on, color: color, size: 32), Container(color: Colors.white70, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))]); }
class _MapPainter extends CustomPainter { const _MapPainter(); @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = Colors.white.withOpacity(.7)..strokeWidth = 6..style = PaintingStyle.stroke; for (final path in [Path()..moveTo(0, size.height*.72)..quadraticBezierTo(size.width*.35, size.height*.2, size.width, size.height*.42), Path()..moveTo(size.width*.14, 0)..quadraticBezierTo(size.width*.38, size.height*.58, size.width*.82, size.height), Path()..moveTo(size.width*.62, 0)..quadraticBezierTo(size.width*.7, size.height*.45, size.width, size.height*.7)]) { canvas.drawPath(path, paint); } } @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false; }
