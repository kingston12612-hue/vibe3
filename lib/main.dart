import 'package:flutter/material.dart';

void main() {
  runApp(const VibeApp());
}

class VibeApp extends StatelessWidget {
  const VibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'vibe<3',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8164FF),
          secondary: Color(0xFFD96EFF),
          surface: Color(0xFF14141D),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090F),
        title: const Text(
          'vibe<3',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: const [
          _ChatTile(
            name: 'Marcus',
            message: 'Welcome to vibe<3',
            time: 'now',
            unread: 2,
          ),
          _ChatTile(
            name: 'vibe<3 Team',
            message: 'Your messenger is ready',
            time: 'now',
            unread: 0,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        backgroundColor: const Color(0xFF14141D),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Calls'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final int unread;

  const _ChatTile({
    required this.name,
    required this.message,
    required this.time,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF14141D),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF8164FF),
          child: Text(name.substring(0, 1)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(time, style: const TextStyle(fontSize: 12)),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD96EFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$unread', style: const TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}
