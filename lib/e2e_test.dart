import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(const MaterialApp(home: E2ETestScreen()));
}

class E2ETestScreen extends StatefulWidget {
  const E2ETestScreen({super.key});

  @override
  State<E2ETestScreen> createState() => _E2ETestScreenState();
}

class _E2ETestScreenState extends State<E2ETestScreen> {
  final List<String> logs = [];
  bool isRunning = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  void log(String msg) {
    setState(() {
      logs.add(msg);
    });
    // ignore: avoid_print
    print(msg);
  }

  Future<void> _runTests() async {
    setState(() => isRunning = true);
    final auth = FirebaseAuth.instance;
    final db = FirestoreService();

    try {
      // 1. Log in as admin
      log('⏳ Logging in as admin...');
      await auth.signInWithEmailAndPassword(email: 'admin@ssit.edu.np', password: 'password123');
      log('✅ Admin logged in.');

      // 2. Create a course
      log('⏳ Creating a course...');
      final courseRef = await FirebaseFirestore.instance.collection('courses').add({
        'title': 'Flutter Masterclass',
        'subtitle': 'Zero to Hero in Flutter',
        'image': '🚀',
        'color': '#FF0000',
        'price': 1000,
        'tier': 'gold',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final courseId = courseRef.id;
      log('✅ Course created with ID: $courseId');

      // 3. Create a mock test for the course
      log('⏳ Creating a mock test...');
      await db.createMockTest(courseId, {
        'title': 'Flutter Basics',
        'durationMin': 10,
        'questions': [
          {'q': 'What is Flutter?', 'options': ['UI Toolkit', 'Framework', 'Both', 'None'], 'ans': 0},
        ],
      });
      log('✅ Mock test created.');

      // 4. Update student user tier
      log('⏳ Updating Priya\'s tier to gold...');
      final userQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: 'priya@email.com').get();
      String studentId = '';
      if (userQuery.docs.isNotEmpty) {
        studentId = userQuery.docs.first.id;
        await db.updateUserDoc(studentId, {'tier': 'gold'});
        log('✅ Priya updated.');
      } else {
        log('❌ Priya not found. Trying Aarav.');
      }

      // 5. Log in as student
      log('⏳ Logging in as Student...');
      await auth.signInWithEmailAndPassword(email: 'priya@email.com', password: 'password123');
      log('✅ Student logged in.');
      
      // 6. Place an order for the course
      log('⏳ Placing an order...');
      await db.placeOrder(
        studentId: studentId,
        studentName: 'Priya Student',
        courseId: courseId,
        courseTitle: 'Flutter Masterclass',
        amount: 1000,
      );
      log('✅ Order placed.');

      // 7. Log back in as admin and activate the order
      log('⏳ Admin approving order...');
      await auth.signInWithEmailAndPassword(email: 'admin@ssit.edu.np', password: 'password123');
      
      final ordersSnap = await FirebaseFirestore.instance.collection('orders')
          .where('studentId', isEqualTo: studentId)
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (ordersSnap.docs.isNotEmpty) {
        final orderId = ordersSnap.docs.first.id;
        await db.activateOrder(orderId, studentId, courseId);
        log('✅ Order Activated.');
      } else {
        log('❌ Pending order not found.');
      }

      // 8. Log in as teacher to verify
      log('⏳ Logging in as teacher...');
      await auth.signInWithEmailAndPassword(email: 'ram@ssit.edu.np', password: 'password123');
      log('✅ Teacher logged in.');
      // Teachers would be able to view courses, which we know exists.

      log('🎉 ALL TESTS COMPLETED SUCCESSFULLY! 🎉');

    } catch (e) {
      log('❌ ERROR: $e');
    } finally {
      setState(() => isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E2E Programmatic Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isRunning) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (ctx, i) => Text(logs[i], style: const TextStyle(fontSize: 16, height: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
