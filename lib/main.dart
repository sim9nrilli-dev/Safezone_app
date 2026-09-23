import 'package:flutter/material.dart';

void main() => runApp(const SafeZoneApp());

class SafeZoneApp extends StatelessWidget {
  const SafeZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeZone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C4AB6),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
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
  int _selectedIndex = 0;
  bool _tracking = false;
  bool _notifications = true;
  final List<String> _selectedZones = ['Station Zuid'];

  final List<_Zone> _zones = const [
    _Zone('Station Zuid', 'Amsterdam', 'Hoog risico', Colors.red, Icons.train),
    _Zone('Westerpark', 'Amsterdam', 'Let op', Colors.orange, Icons.park),
    _Zone('Museumplein', 'Amsterdam', 'Veilige route', Colors.green, Icons.museum),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildZones(),
      _buildCommunity(),
      _buildContacts(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeZone', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Meldingen',
            onPressed: () => _showMessage('Je hebt geen nieuwe meldingen.'),
            icon: Badge(
              isLabelVisible: _notifications,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Instellingen',
            onPressed: () => _showSettings(),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
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
        onPressed: _showEmergencySheet,
        icon: const Icon(Icons.sos),
        label: const Text('NOODKNOP', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Text('Goedenavond, blijf veilig', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          color: _tracking ? Colors.green.shade50 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: _tracking ? Colors.green : Colors.deepPurple.shade100,
                  child: Icon(_tracking ? Icons.gps_fixed : Icons.gps_not_fixed, color: _tracking ? Colors.white : Colors.deepPurple),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_tracking ? 'Tracking is actief' : 'Start je veilige reis', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(_tracking ? 'Je vertrouwde contacten kunnen je locatie zien.' : 'Deel je locatie en ontvang zone-waarschuwingen.'),
                ])),
                Switch(value: _tracking, onChanged: (value) => setState(() => _tracking = value)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Jouw veilige route', 'Bekijk kaart', () => setState(() => _selectedIndex = 1)),
        _mapPreview(),
        const SizedBox(height: 12),
        _sectionTitle('Aanbevolen zones', 'Alles bekijken', () => setState(() => _selectedIndex = 1)),
        ..._zones.take(2).map(_zoneTile),
        const SizedBox(height: 12),
        _sectionTitle('Veiligheidsfoto\'s uit de buurt', 'Delen', () => _showMessage('Fotodelen wordt binnenkort beschikbaar.')),
        SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => Container(
              width: 150,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: [Colors.indigo.shade200, Colors.orange.shade200, Colors.teal.shade200][index]),
              child: Center(child: Icon([Icons.streetview, Icons.local_police, Icons.lightbulb_outline][index], size: 38, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZones() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Veiligheidskaart', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Selecteer zones waar je een waarschuwing voor wilt ontvangen.'),
        const SizedBox(height: 16),
        _mapPreview(expanded: true),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Onveilige zones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          TextButton.icon(onPressed: () => _showMessage('Nieuwe zone toevoegen via de kaart.'), icon: const Icon(Icons.add), label: const Text('Toevoegen')),
        ]),
        ..._zones.map(_zoneTile),
      ],
    );
  }

  Widget _buildCommunity() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Community', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const Text('Samen maken we routes veiliger.'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => _showMessage('Bedankt! Je melding wordt gecontroleerd door de community.'), icon: const Icon(Icons.add_location_alt), label: const Text('Meld een onveilige plek')),
        const SizedBox(height: 18),
        _communityPost('Slechte verlichting bij de tunnel', 'Anoniem • 12 min geleden', Icons.lightbulb_outline, Colors.orange),
        _communityPost('Extra toezicht bij Station Zuid', 'Nora • gisteren', Icons.local_police_outlined, Colors.red),
        _communityPost('Veilige koffiezaak tot laat open', 'Samira • 2 dagen geleden', Icons.local_cafe_outlined, Colors.green),
      ],
    );
  }

  Widget _buildContacts() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Vertrouwde contacten', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Deze personen ontvangen een waarschuwing wanneer je hulp nodig hebt.'),
        const SizedBox(height: 16),
        ...[
          ['Mama', '06 12 34 56 78', 'M'],
          ['Lisa', '06 87 65 43 21', 'L'],
          ['Alex', '06 11 22 33 44', 'A'],
        ].map((contact) => Card(child: ListTile(leading: CircleAvatar(child: Text(contact[2])), title: Text(contact[0], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(contact[1]), trailing: IconButton(icon: const Icon(Icons.phone_outlined), onPressed: () => _showMessage('Bellen naar ${contact[0]}...'))))),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _showMessage('Contact toevoegen'), icon: const Icon(Icons.person_add_alt_1), label: const Text('Contact toevoegen')),
        const SizedBox(height: 24),
        Card(color: Colors.red.shade50, child: const ListTile(leading: Icon(Icons.phone_in_talk, color: Colors.red), title: Text('112 bij direct gevaar', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Gebruik de rode noodknop om direct hulp te bellen.'))),
      ],
    );
  }

  Widget _mapPreview({bool expanded = false}) {
    return Container(
      height: expanded ? 260 : 180,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: const Color(0xFFD8E5D5)),
      child: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: MapLinesPainter())),
        const Positioned(top: 24, left: 38, child: _MapPin(color: Colors.red, label: 'Station Zuid')),
        const Positioned(bottom: 34, right: 54, child: _MapPin(color: Colors.orange, label: 'Westerpark')),
        const Positioned(top: 78, right: 110, child: _MapPin(color: Colors.green, label: 'Veilig')),
        Positioned(right: 12, bottom: 12, child: FloatingActionButton.small(heroTag: expanded ? 'map-large' : 'map-small', onPressed: () => _showMessage('Kaart openen'), child: const Icon(Icons.my_location))),
      ]),
    );
  }

  Widget _zoneTile(_Zone zone) {
    final selected = _selectedZones.contains(zone.name);
    return Card(child: ListTile(leading: CircleAvatar(backgroundColor: zone.color.withOpacity(.15), child: Icon(zone.icon, color: zone.color)), title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${zone.city} • ${zone.status}'), trailing: Checkbox(value: selected, onChanged: (value) => setState(() => value == true ? _selectedZones.add(zone.name) : _selectedZones.remove(zone.name)))));
  }

  Widget _sectionTitle(String title, String action, VoidCallback onTap) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), TextButton(onPressed: onTap, child: Text(action))]);

  Widget _communityPost(String title, String author, IconData icon, Color color) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: color.withOpacity(.15), child: Icon(icon, color: color)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(author), trailing: IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => _showMessage('Melding gedeeld.'))));

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _showSettings() => showModalBottomSheet(context: context, builder: (_) => StatefulBuilder(builder: (context, setSheetState) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const ListTile(title: Text('Instellingen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), SwitchListTile(title: const Text('Zone-meldingen'), value: _notifications, onChanged: (value) { setState(() => _notifications = value); setSheetState(() {}); }), const ListTile(leading: Icon(Icons.timer_outlined), title: Text('Escalatie-instellingen'), subtitle: Text('Na 5 minuten: contact • na 10 minuten: hulpdiensten'))]))));

  void _showEmergencySheet() => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.warning_rounded, size: 56, color: Colors.red), const SizedBox(height: 12), const Text('Heb je direct hulp nodig?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Bel 112 bij direct gevaar. Je vertrouwde contacten krijgen ook een melding.'), const SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () { Navigator.pop(context); _showMessage('112 wordt gebeld. Blijf aan de lijn.'); }, icon: const Icon(Icons.phone), label: const Text('BEL 112'))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); _showMessage('Noodmelding verstuurd naar je contacten.'); }, icon: const Icon(Icons.notifications_active), label: const Text('Stuur stille melding'))]))));
}

class _Zone {
  final String name, city, status;
  final Color color;
  final IconData icon;
  const _Zone(this.name, this.city, this.status, this.color, this.icon);
}

class _MapPin extends StatelessWidget {
  final Color color;
  final String label;
  const _MapPin({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [Icon(Icons.location_on, color: color, size: 34), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), color: Colors.white70, child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))]);
}

class MapLinesPainter extends CustomPainter {
  const MapLinesPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()..color = Colors.white.withOpacity(.8)..strokeWidth = 8..style = PaintingStyle.stroke;
    final paths = [Path()..moveTo(0, size.height * .7)..quadraticBezierTo(size.width * .4, size.height * .2, size.width, size.height * .45), Path()..moveTo(size.width * .2, 0)..quadraticBezierTo(size.width * .35, size.height * .6, size.width * .8, size.height)];
    for (final path in paths) canvas.drawPath(path, road);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
