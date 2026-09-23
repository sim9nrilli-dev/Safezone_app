import 'dart:async';
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
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F7FF),
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
  bool _trackingEnabled = false;
  bool _notificationsEnabled = true;
  int _activeZoneIndex = 0;
  int _secondsInZone = 0;
  double _riskLevel = 18.0;

  final List<_DangerZone> _dangerZones = const [
    _DangerZone(
      name: 'Station Zuid',
      district: 'Centrum',
      risk: 'Hoog risico',
      color: Colors.red,
      icon: Icons.train,
      minutes: 12,
    ),
    _DangerZone(
      name: 'Westerpark',
      district: 'Noord',
      risk: 'Waarschuwing',
      color: Colors.orange,
      icon: Icons.park,
      minutes: 7,
    ),
    _DangerZone(
      name: 'Museumplein',
      district: 'Zuid',
      risk: 'Veilig',
      color: Colors.green,
      icon: Icons.museum,
      minutes: 2,
    ),
  ];

  final List<_Contact> _contacts = const [
    _Contact('Mama', '06 12 34 56 78', Icons.person),
    _Contact('Lotte', '06 23 45 67 89', Icons.person_2),
    _Contact('Bram', '06 98 76 54 32', Icons.person_3),
  ];

  final List<_CommunityReport> _communityReports = const [
    _CommunityReport('Slechte verlichting in de tunnel', 'Anoniem • 9 min geleden', Colors.orange, Icons.lightbulb),
    _CommunityReport('Toezicht verhoogd bij Station Zuid', 'Nora • 1 uur geleden', Colors.red, Icons.local_police),
    _CommunityReport('Veilige koffiebar open tot laat', 'Samira • 2 uur geleden', Colors.green, Icons.local_cafe),
  ];

  Timer? _riskTimer;

  @override
  void initState() {
    super.initState();
    _riskTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_trackingEnabled) return;

      final zone = _dangerZones[_activeZoneIndex];
      setState(() {
        _secondsInZone += 5;
        final minutes = _secondsInZone / 60;
        final intensifier = zone.minutes.toDouble();
        _riskLevel = (18 + minutes * 8 + intensifier * (minutes / 2))
            .clamp(10.0, 96.0)
            .toDouble();
      });
    });
  }

  @override
  void dispose() {
    _riskTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildOverviewPage(),
      _buildMapPage(),
      _buildCommunityPage(),
      _buildContactsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeZone', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Meldingen',
            onPressed: () => _showMessage('Je hebt geen nieuwe meldingen.'),
            icon: Badge(
              isLabelVisible: _notificationsEnabled,
              backgroundColor: Colors.red,
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
        label: const Text('112 / Noodknop', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildOverviewPage() {
    final activeZone = _dangerZones[_activeZoneIndex];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text(
          'Goedenavond, blijf veilig',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          color: _trackingEnabled ? Colors.green.shade50 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _trackingEnabled ? Colors.green : Colors.deepPurple.shade100,
                  child: Icon(
                    _trackingEnabled ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: _trackingEnabled ? Colors.white : Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _trackingEnabled ? 'Tracking actief' : 'Tracking uit',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _trackingEnabled
                            ? 'Je locatie wordt gedeeld met vertrouwde contacten.'
                            : 'Schakel tracking in om je route en zone-waarschuwingen te volgen.',
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _trackingEnabled,
                  onChanged: (value) => setState(() => _trackingEnabled = value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _sectionHeader('Veiligheidsstatus', 'Kaart'),
        _riskCard(activeZone),
        const SizedBox(height: 18),
        _sectionHeader('Foto\'s van de buurt', 'Meer'),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final colors = [Colors.indigo.shade200, Colors.orange.shade200, Colors.teal.shade200];
              final icons = [Icons.streetview, Icons.local_police, Icons.lightbulb_outline];
              return Container(
                width: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: colors[index],
                ),
                child: Center(
                  child: Icon(icons[index], size: 42, color: Colors.white),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _sectionHeader('Aanbevolen zones', 'Alles bekijken'),
        ..._dangerZones.map((zone) => _zoneRecommendationTile(zone)),
      ],
    );
  }

  Widget _buildMapPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Veiligheidskaart', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Selecteer gebieden waar je meer waarschuwingen wilt ontvangen.'),
        const SizedBox(height: 18),
        _safeMapCard(),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Onveilige zones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            TextButton.icon(
              onPressed: () => _showMessage('Voeg een nieuwe zone toe vanuit de kaart.'),
              icon: const Icon(Icons.add),
              label: const Text('Toevoegen'),
            ),
          ],
        ),
        ..._dangerZones.map((zone) => _zoneSelectionTile(zone)),
      ],
    );
  }

  Widget _buildCommunityPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Community', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Delen van veilige of onveilige routes helpt de hele community.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _showMessage('Je melding is gedeeld met de community.'),
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Meld een onveilige plek'),
        ),
        const SizedBox(height: 16),
        ..._communityReports.map((report) => _communityReportCard(report)),
      ],
    );
  }

  Widget _buildContactsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Vertrouwde contacten', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Deze personen ontvangen een melding als je hulp nodig hebt.'),
        const SizedBox(height: 16),
        ..._contacts.map((contact) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
              child: Icon(contact.icon, color: const Color(0xFF7C4DFF)),
            ),
            title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(contact.phone),
            trailing: IconButton(
              onPressed: () => _showMessage('Bellen naar ${contact.name}...'),
              icon: const Icon(Icons.phone_outlined),
            ),
          ),
        )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showMessage('Contact toevoegen'),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Contact toevoegen'),
        ),
        const SizedBox(height: 18),
        Card(
          color: Colors.red.shade50,
          child: const ListTile(
            leading: Icon(Icons.emergency, color: Colors.red),
            title: Text('112 bij direct gevaar', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Bel direct. Je contacten krijgen automatisch een melding.'),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, [String? action]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        if (action != null)
          TextButton(
            onPressed: () => _showMessage('$action geselecteerd'),
            child: Text(action),
          ),
      ],
    );
  }

  Widget _riskCard(_DangerZone activeZone) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: activeZone.color.withValues(alpha: 0.15),
                  child: Icon(activeZone.icon, color: activeZone.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activeZone.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('${activeZone.district} • ${activeZone.risk}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Risiconiveau', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${_riskLevel.round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              minHeight: 10,
              value: (_riskLevel / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color: _riskLevel > 70 ? Colors.red : _riskLevel > 40 ? Colors.orange : Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 12),
            Text(
              _riskLevel > 70
                  ? 'Je bent langere tijd in een risicogebied. De kans op ongewenste interactie neemt toe.'
                  : _riskLevel > 40
                      ? 'Je bent in een gebied met verhoogde alertheid. Blijf in openbare, goed verlichte routes.'
                      : 'Je staat momenteel in een relatief veilige zone. Houd de route in de gaten.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Tijd in zone: ${(_secondsInZone / 60).floor()} min ${_secondsInZone % 60} s',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _safeMapCard() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFDDEED9),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MapPatternPainter())),
          const Positioned(top: 30, left: 45, child: _MapMarker(color: Colors.red, label: 'Station Zuid')),
          const Positioned(bottom: 42, right: 55, child: _MapMarker(color: Colors.orange, label: 'Westerpark')),
          const Positioned(top: 120, right: 125, child: _MapMarker(color: Colors.green, label: 'Veilig')),
          Positioned(
            right: 12,
            bottom: 10,
            child: FloatingActionButton.small(
              onPressed: () => _showMessage('Kaart wordt geopend.'),
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneRecommendationTile(_DangerZone zone) {
    final selected = _activeZoneIndex == _dangerZones.indexOf(zone);
    return Card(
      color: selected ? Colors.red.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: zone.color.withValues(alpha: 0.15),
          child: Icon(zone.icon, color: zone.color),
        ),
        title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${zone.district} • ${zone.risk}'),
        trailing: IconButton(
          onPressed: () {
            setState(() {
              _activeZoneIndex = _dangerZones.indexOf(zone);
              _riskLevel = (18 + zone.minutes * 6).clamp(15.0, 90.0).toDouble();
            });
            _showMessage('Zone ${zone.name} geselecteerd.');
          },
          icon: const Icon(Icons.arrow_forward_ios),
        ),
      ),
    );
  }

  Widget _zoneSelectionTile(_DangerZone zone) {
    final selected = _activeZoneIndex == _dangerZones.indexOf(zone);
    return Card(
      child: CheckboxListTile(
        value: selected,
        onChanged: (_) {
          setState(() {
            _activeZoneIndex = _dangerZones.indexOf(zone);
            _riskLevel = (18 + zone.minutes * 8).clamp(15.0, 90.0).toDouble();
          });
        },
        secondary: CircleAvatar(
          backgroundColor: zone.color.withValues(alpha: 0.12),
          child: Icon(zone.icon, color: zone.color),
        ),
        title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${zone.district} • ${zone.risk}'),
      ),
    );
  }

  Widget _communityReportCard(_CommunityReport report) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: report.color.withValues(alpha: 0.18),
          child: Icon(report.icon, color: report.color),
        ),
        title: Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(report.meta),
        trailing: IconButton(
          onPressed: () => _showMessage('Verhaal is gedeeld.'),
          icon: const Icon(Icons.share_outlined),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Instellingen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Meldingen'),
                  value: _notificationsEnabled,
                  onChanged: (value) => setState(() => _notificationsEnabled = value),
                ),
                const ListTile(
                  leading: Icon(Icons.timer_outlined),
                  title: Text('Escalatie'),
                  subtitle: Text('Na 5 minuten: contact • na 10 minuten: 112'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEmergencySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded, size: 52, color: Colors.red),
                const SizedBox(height: 12),
                const Text('Heb je direct hulp nodig?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Bel 112 of stuur een stille melding naar je vertrouwde contacten.'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage('112 wordt gebeld. Blijf aan de lijn.');
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Bel 112'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage('Stille melding verzonden naar je contacten.');
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Stille melding'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DangerZone {
  final String name;
  final String district;
  final String risk;
  final Color color;
  final IconData icon;
  final int minutes;

  const _DangerZone({
    required this.name,
    required this.district,
    required this.risk,
    required this.color,
    required this.icon,
    required this.minutes,
  });
}

class _Contact {
  final String name;
  final String phone;
  final IconData icon;

  const _Contact(this.name, this.phone, this.icon);
}

class _CommunityReport {
  final String title;
  final String meta;
  final Color color;
  final IconData icon;

  const _CommunityReport(this.title, this.meta, this.color, this.icon);
}

class _MapMarker extends StatelessWidget {
  final Color color;
  final String label;

  const _MapMarker({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.location_on, color: color, size: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: Colors.white70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  const _MapPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final paths = [
      Path()..moveTo(0, size.height * 0.72)..quadraticBezierTo(size.width * 0.35, size.height * 0.2, size.width, size.height * 0.42),
      Path()..moveTo(size.width * 0.14, 0)..quadraticBezierTo(size.width * 0.38, size.height * 0.58, size.width * 0.82, size.height),
      Path()..moveTo(size.width * 0.62, 0)..quadraticBezierTo(size.width * 0.7, size.height * 0.45, size.width, size.height * 0.7),
    ];

    for (final path in paths) {
      canvas.drawPath(path, roadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
