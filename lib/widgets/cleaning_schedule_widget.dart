import 'package:flutter/material.dart';

class CleaningScheduleWidget extends StatefulWidget {
  const CleaningScheduleWidget({super.key});

  @override
  State<CleaningScheduleWidget> createState() => _CleaningScheduleWidgetState();
}

class _CleaningScheduleWidgetState extends State<CleaningScheduleWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = [
    'Pondělí',
    'Úterý',
    'Středa',
    'Čtvrtek',
    'Pátek',
    'Sobota',
    'Neděle'
  ];

  // Data pro úklidy - přesně podle původního widgetu
  final Map<String, Map<String, String>> cleaningSchedule = {
    'Dětský bazén': {
      'Pondělí': 'Oplach + Dezinfekce',
      'Úterý': 'VEDA',
      'Středa': 'Chromy + Oplach',
      'Čtvrtek': 'Oplach + Dezinfekce',
      'Pátek': 'Oplach',
      'Sobota': 'Oplach + Dezinfekce',
      'Neděle': 'Oplach + VEDA',
    },
    '50m': {
      'Pondělí': 'Oplach + Dezinfekce',
      'Úterý': 'Oplach + VEDA',
      'Středa': 'Chromy + Oplach',
      'Čtvrtek': 'Oplach + Dezinfekce + VEDA',
      'Pátek': 'Oplach',
      'Sobota': 'Oplach + Dezinfekce + VEDA + R:Plavčíkárna',
      'Neděle': 'Oplach',
    },
    '25m': {
      'Pondělí': 'Oplach + Dezinfekce + VEDA',
      'Úterý': 'Oplach + VEDA + R:Balkon',
      'Středa': 'Oplach + VEDA + Chromy + R:Balkon',
      'Čtvrtek': 'Oplach + Dezinfekce + VEDA',
      'Pátek': 'Oplach',
      'Sobota': 'Oplach + Dezinfekce + VEDA + R:Balkon',
      'Neděle': 'VEDA',
    },
    'Venek': {
      'Pondělí': 'Oplach + Dezinfekce',
      'Úterý': 'Oplach + VEDA',
      'Středa': 'Dezinfekce + VEDA',
      'Čtvrtek': 'Oplach',
      'Pátek': 'Dezinfekce + VEDA',
      'Sobota': 'Oplach + VEDA',
      'Neděle': 'Oplach',
    },
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cleaning_services, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Úklidy',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                icon: Icon(Icons.child_care),
                child: Column(
                  children: [
                    SizedBox(height: 4),
                    Text('Dětský', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Tab(
                icon: Icon(Icons.pool),
                child: Column(
                  children: [
                    SizedBox(height: 4),
                    Text('50m', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Tab(
                icon: Icon(Icons.pool_outlined),
                child: Column(
                  children: [
                    SizedBox(height: 4),
                    Text('25m', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Tab(
                icon: Icon(Icons.wb_sunny),
                child: Column(
                  children: [
                    SizedBox(height: 4),
                    Text('Venek', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPoolSchedule('Dětský bazén'),
                  _buildPoolSchedule('50m'),
                  _buildPoolSchedule('25m'),
                  _buildPoolSchedule('Venek'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolSchedule(String poolType) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _days.length,
      itemBuilder: (context, index) {
        final day = _days[index];
        final cleaning = cleaningSchedule[poolType]?[day] ?? '';
        final isEven = index % 2 == 0;
        final isLastItem = index == _days.length - 1;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isEven ? Colors.grey.withOpacity(0.05) : Colors.white,
            borderRadius: isLastItem
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  )
                : null,
            border: !isLastItem
                ? Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 100,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  cleaning,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
