// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:convert';
// import 'dart:math' as math;

// /// Progress tracking and analytics for pronunciation practice
// class PronunciationProgressTracker {
//   static const String _progressKey = 'pronunciation_progress';
//   static const String _streakKey = 'practice_streak';
//   static const String _achievementsKey = 'pronunciation_achievements';

//   /// Save practice session to local storage and Firestore
//   static Future<void> savePracticeSession(PronunciationSession session) async {
//     final prefs = await SharedPreferences.getInstance();
//     final user = FirebaseAuth.instance.currentUser;
    
//     // Create progress entry
//     final progressEntry = PronunciationProgressEntry(
//       sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
//       verseIndex: session.verseIndex,
//       date: session.startTime,
//       duration: session.getDuration(),
//       attempts: session.attempts.length,
//       bestAccuracy: session.getBestAccuracy(),
//       averageAccuracy: session.getCurrentAccuracy(),
//       improvementScore: await _calculateImprovementScore(session),
//     );

//     // Save locally
//     await _saveProgressLocally(prefs, progressEntry);
    
//     // Save to Firestore if user is authenticated
//     if (user != null) {
//       await _saveProgressToFirestore(user.uid, progressEntry);
//     }

//     // Update streak
//     await _updatePracticeStreak();
    
//     // Check for achievements
//     await _checkAndUnlockAchievements(progressEntry);
//   }

//   /// Save progress entry locally
//   static Future<void> _saveProgressLocally(
//     SharedPreferences prefs, 
//     PronunciationProgressEntry entry,
//   ) async {
//     final progressJson = prefs.getString(_progressKey) ?? '[]';
//     final progressList = List<Map<String, dynamic>>.from(
//       jsonDecode(progressJson),
//     );
    
//     progressList.add(entry.toJson());
    
//     // Keep only last 100 entries locally
//     if (progressList.length > 100) {
//       progressList.removeRange(0, progressList.length - 100);
//     }
    
//     await prefs.setString(_progressKey, jsonEncode(progressList));
//   }

//   /// Save progress to Firestore
//   static Future<void> _saveProgressToFirestore(
//     String userId, 
//     PronunciationProgressEntry entry,
//   ) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(userId)
//           .collection('pronunciation_progress')
//           .doc(entry.sessionId)
//           .set(entry.toJson());
//     } catch (e) {
//       print('Error saving progress to Firestore: $e');
//     }
//   }

//   /// Calculate improvement score based on historical data
//   static Future<double> _calculateImprovementScore(PronunciationSession session) async {
//     final history = await getProgressHistory();
    
//     if (history.length < 2) return 0.0;
    
//     // Compare with last 5 sessions
//     final recentSessions = history.take(5).toList();
//     final previousAverage = recentSessions
//         .map((e) => e.averageAccuracy)
//         .reduce((a, b) => a + b) / recentSessions.length;
    
//     final currentAccuracy = session.getCurrentAccuracy();
//     return (currentAccuracy - previousAverage).clamp(-1.0, 1.0);
//   }

//   /// Update practice streak
//   static Future<void> _updatePracticeStreak() async {
//     final prefs = await SharedPreferences.getInstance();
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
    
//     final lastPracticeStr = prefs.getString('last_practice_date');
//     final currentStreak = prefs.getInt(_streakKey) ?? 0;
    
//     if (lastPracticeStr == null) {
//       // First practice session
//       await prefs.setInt(_streakKey, 1);
//       await prefs.setString('last_practice_date', today.toIso8601String());
//       return;
//     }
    
//     final lastPractice = DateTime.parse(lastPracticeStr);
//     final daysDifference = today.difference(lastPractice).inDays;
    
//     if (daysDifference == 0) {
//       // Already practiced today, no change to streak
//       return;
//     } else if (daysDifference == 1) {
//       // Consecutive day, increment streak
//       await prefs.setInt(_streakKey, currentStreak + 1);
//     } else {
//       // Streak broken, reset to 1
//       await prefs.setInt(_streakKey, 1);
//     }
    
//     await prefs.setString('last_practice_date', today.toIso8601String());
//   }

//   /// Get current practice streak
//   static Future<int> getCurrentStreak() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getInt(_streakKey) ?? 0;
//   }

//   /// Get progress history
//   static Future<List<PronunciationProgressEntry>> getProgressHistory() async {
//     final prefs = await SharedPreferences.getInstance();
//     final progressJson = prefs.getString(_progressKey) ?? '[]';
//     final progressList = List<Map<String, dynamic>>.from(
//       jsonDecode(progressJson),
//     );
    
//     return progressList
//         .map((json) => PronunciationProgressEntry.fromJson(json))
//         .toList()
//         ..sort((a, b) => b.date.compareTo(a.date));
//   }

//   /// Get weekly progress statistics
//   static Future<WeeklyProgressStats> getWeeklyStats() async {
//     final history = await getProgressHistory();
//     final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    
//     final weeklyData = history
//         .where((entry) => entry.date.isAfter(oneWeekAgo))
//         .toList();
    
//     if (weeklyData.isEmpty) {
//       return WeeklyProgressStats.empty();
//     }
    
//     final totalSessions = weeklyData.length;
//     final totalDuration = weeklyData
//         .map((e) => e.duration.inMinutes)
//         .reduce((a, b) => a + b);
//     final averageAccuracy = weeklyData
//         .map((e) => e.averageAccuracy)
//         .reduce((a, b) => a + b) / weeklyData.length;
//     final bestAccuracy = weeklyData
//         .map((e) => e.bestAccuracy)
//         .reduce(math.max);
    
//     return WeeklyProgressStats(
//       totalSessions: totalSessions,
//       totalMinutes: totalDuration,
//       averageAccuracy: averageAccuracy,
//       bestAccuracy: bestAccuracy,
//       daysActive: _getDaysActive(weeklyData),
//     );
//   }

//   /// Get days active from progress data
//   static int _getDaysActive(List<PronunciationProgressEntry> data) {
//     final uniqueDays = data
//         .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
//         .toSet();
//     return uniqueDays.length;
//   }

//   /// Check and unlock achievements
//   static Future<void> _checkAndUnlockAchievements(PronunciationProgressEntry entry) async {
//     final achievements = await getUnlockedAchievements();
//     final newAchievements = <PronunciationAchievement>[];
    
//     // Check various achievement conditions
//     await _checkFirstPracticeAchievement(entry, achievements, newAchievements);
//     await _checkAccuracyAchievements(entry, achievements, newAchievements);
//     await _checkStreakAchievements(achievements, newAchievements);
//     await _checkVolumeAchievements(achievements, newAchievements);
    
//     // Save new achievements
//     if (newAchievements.isNotEmpty) {
//       await _saveAchievements(achievements + newAchievements);
//     }
//   }

//   /// Check first practice achievement
//   static Future<void> _checkFirstPracticeAchievement(
//     PronunciationProgressEntry entry,
//     List<PronunciationAchievement> current,
//     List<PronunciationAchievement> newAchievements,
//   ) async {
//     if (current.any((a) => a.id == 'first_practice')) return;
    
//     newAchievements.add(PronunciationAchievement(
//       id: 'first_practice',
//       title: 'First Steps',
//       description: 'Complete your first pronunciation practice',
//       icon: Icons.baby_changing_station,
//       unlockedAt: DateTime.now(),
//     ));
//   }

//   /// Check accuracy-based achievements
//   static Future<void> _checkAccuracyAchievements(
//     PronunciationProgressEntry entry,
//     List<PronunciationAchievement> current,
//     List<PronunciationAchievement> newAchievements,
//   ) async {
//     // Perfect verse achievement
//     if (entry.bestAccuracy >= 0.95 && !current.any((a) => a.id == 'perfect_verse')) {
//       newAchievements.add(PronunciationAchievement(
//         id: 'perfect_verse',
//         title: 'Perfect Recitation',
//         description: 'Achieve 95% accuracy on a verse',
//         icon: Icons.star,
//         unlockedAt: DateTime.now(),
//       ));
//     }
    
//     // Consistent accuracy achievement
//     if (entry.averageAccuracy >= 0.8 && !current.any((a) => a.id == 'consistent_accuracy')) {
//       final history = await getProgressHistory();
//       final last5Sessions = history.take(5);
//       final allAbove80 = last5Sessions.every((s) => s.averageAccuracy >= 0.8);
      
//       if (allAbove80) {
//         newAchievements.add(PronunciationAchievement(
//           id: 'consistent_accuracy',
//           title: 'Consistency Master',
//           description: 'Maintain 80%+ accuracy for 5 sessions',
//           icon: Icons.trending_up,
//           unlockedAt: DateTime.now(),
//         ));
//       }
//     }
//   }

//   /// Check streak-based achievements
//   static Future<void> _checkStreakAchievements(
//     List<PronunciationAchievement> current,
//     List<PronunciationAchievement> newAchievements,
//   ) async {
//     final streak = await getCurrentStreak();
    
//     if (streak >= 7 && !current.any((a) => a.id == 'week_streak')) {
//       newAchievements.add(PronunciationAchievement(
//         id: 'week_streak',
//         title: 'Weekly Warrior',
//         description: 'Practice for 7 consecutive days',
//         icon: Icons.calendar_view_week,
//         unlockedAt: DateTime.now(),
//       ));
//     }
    
//     if (streak >= 30 && !current.any((a) => a.id == 'month_streak')) {
//       newAchievements.add(PronunciationAchievement(
//         id: 'month_streak',
//         title: 'Monthly Master',
//         description: 'Practice for 30 consecutive days',
//         icon: Icons.calendar_month,
//         unlockedAt: DateTime.now(),
//       ));
//     }
//   }

//   /// Check volume-based achievements
//   static Future<void> _checkVolumeAchievements(
//     List<PronunciationAchievement> current,
//     List<PronunciationAchievement> newAchievements,
//   ) async {
//     final history = await getProgressHistory();
    
//     if (history.length >= 50 && !current.any((a) => a.id == 'dedicated_learner')) {
//       newAchievements.add(PronunciationAchievement(
//         id: 'dedicated_learner',
//         title: 'Dedicated Learner',
//         description: 'Complete 50 practice sessions',
//         icon: Icons.school,
//         unlockedAt: DateTime.now(),
//       ));
//     }
    
//     final totalMinutes = history
//         .map((e) => e.duration.inMinutes)
//         .fold(0, (a, b) => a + b);
    
//     if (totalMinutes >= 300 && !current.any((a) => a.id == 'time_invested')) {
//       newAchievements.add(PronunciationAchievement(
//         id: 'time_invested',
//         title: 'Time Invested',
//         description: 'Spend 5+ hours practicing',
//         icon: Icons.schedule,
//         unlockedAt: DateTime.now(),
//       ));
//     }
//   }

//   /// Save achievements
//   static Future<void> _saveAchievements(List<PronunciationAchievement> achievements) async {
//     final prefs = await SharedPreferences.getInstance();
//     final achievementsJson = achievements.map((a) => a.toJson()).toList();
//     await prefs.setString(_achievementsKey, jsonEncode(achievementsJson));
//   }

//   /// Get unlocked achievements
//   static Future<List<PronunciationAchievement>> getUnlockedAchievements() async {
//     final prefs = await SharedPreferences.getInstance();
//     final achievementsJson = prefs.getString(_achievementsKey) ?? '[]';
//     final achievementsList = List<Map<String, dynamic>>.from(
//       jsonDecode(achievementsJson),
//     );
    
//     return achievementsList
//         .map((json) => PronunciationAchievement.fromJson(json))
//         .toList();
//   }
// }

// /// Progress entry data model
// class PronunciationProgressEntry {
//   final String sessionId;
//   final int verseIndex;
//   final DateTime date;
//   final Duration duration;
//   final int attempts;
//   final double bestAccuracy;
//   final double averageAccuracy;
//   final double improvementScore;

//   PronunciationProgressEntry({
//     required this.sessionId,
//     required this.verseIndex,
//     required this.date,
//     required this.duration,
//     required this.attempts,
//     required this.bestAccuracy,
//     required this.averageAccuracy,
//     required this.improvementScore,
//   });

//   Map<String, dynamic> toJson() {
//     return {
//       'sessionId': sessionId,
//       'verseIndex': verseIndex,
//       'date': date.toIso8601String(),
//       'duration': duration.inSeconds,
//       'attempts': attempts,
//       'bestAccuracy': bestAccuracy,
//       'averageAccuracy': averageAccuracy,
//       'improvementScore': improvementScore,
//     };
//   }

//   factory PronunciationProgressEntry.fromJson(Map<String, dynamic> json) {
//     return PronunciationProgressEntry(
//       sessionId: json['sessionId'],
//       verseIndex: json['verseIndex'],
//       date: DateTime.parse(json['date']),
//       duration: Duration(seconds: json['duration']),
//       attempts: json['attempts'],
//       bestAccuracy: json['bestAccuracy'].toDouble(),
//       averageAccuracy: json['averageAccuracy'].toDouble(),
//       improvementScore: json['improvementScore'].toDouble(),
//     );
//   }
// }

// /// Weekly statistics model
// class WeeklyProgressStats {
//   final int totalSessions;
//   final int totalMinutes;
//   final double averageAccuracy;
//   final double bestAccuracy;
//   final int daysActive;

//   WeeklyProgressStats({
//     required this.totalSessions,
//     required this.totalMinutes,
//     required this.averageAccuracy,
//     required this.bestAccuracy,
//     required this.daysActive,
//   });

//   factory WeeklyProgressStats.empty() {
//     return WeeklyProgressStats(
//       totalSessions: 0,
//       totalMinutes: 0,
//       averageAccuracy: 0.0,
//       bestAccuracy: 0.0,
//       daysActive: 0,
//     );
//   }
// }

// /// Achievement data model
// class PronunciationAchievement {
//   final String id;
//   final String title;
//   final String description;
//   final IconData icon;
//   final DateTime unlockedAt;

//   PronunciationAchievement({
//     required this.id,
//     required this.title,
//     required this.description,
//     required this.icon,
//     required this.unlockedAt,
//   });

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'title': title,
//       'description': description,
//       'iconCodePoint': icon.codePoint,
//       'unlockedAt': unlockedAt.toIso8601String(),
//     };
//   }

//   factory PronunciationAchievement.fromJson(Map<String, dynamic> json) {
//     return PronunciationAchievement(
//       id: json['id'],
//       title: json['title'],
//       description: json['description'],
//       icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
//       unlockedAt: DateTime.parse(json['unlockedAt']),
//     );
//   }
// }

// /// Progress dashboard widget
// class PronunciationProgressDashboard extends StatefulWidget {
//   const PronunciationProgressDashboard({Key? key}) : super(key: key);

//   @override
//   State<PronunciationProgressDashboard> createState() => _PronunciationProgressDashboardState();
// }

// class _PronunciationProgressDashboardState extends State<PronunciationProgressDashboard>
//     with SingleTickerProviderStateMixin {
  
//   late TabController _tabController;
//   WeeklyProgressStats? _weeklyStats;
//   List<PronunciationAchievement> _achievements = [];
//   int _currentStreak = 0;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _loadProgressData();
//   }

//   Future<void> _loadProgressData() async {
//     setState(() => _isLoading = true);
    
//     try {
//       final weeklyStats = await PronunciationProgressTracker.getWeeklyStats();
//       final achievements = await PronunciationProgressTracker.getUnlockedAchievements();
//       final streak = await PronunciationProgressTracker.getCurrentStreak();
      
//       setState(() {
//         _weeklyStats = weeklyStats;
//         _achievements = achievements;
//         _currentStreak = streak;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error loading progress data: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Pronunciation Progress'),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(icon: Icon(Icons.analytics), text: 'Stats'),
//             Tab(icon: Icon(Icons.timeline), text: 'Progress'),
//             Tab(icon: Icon(Icons.emoji_events), text: 'Achievements'),
//           ],
//         ),
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : TabBarView(
//               controller: _tabController,
//               children: [
//                 _buildStatsTab(),
//                 _buildProgressTab(),
//                 _buildAchievementsTab(),
//               ],
//             ),
//     );
//   }

//   Widget _buildStatsTab() {
//     if (_weeklyStats == null) {
//       return const Center(
//         child: Text('No practice data available yet.\nStart practicing to see your progress!'),
//       );
//     }

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Current streak card
//           _buildStreakCard(),
//           const SizedBox(height: 16),
          
//           // Weekly stats grid
//           _buildWeeklyStatsGrid(),
//           const SizedBox(height: 16),
          
//           // Accuracy chart
//           _buildAccuracyChart(),
//         ],
//       ),
//     );
//   }

//   Widget _buildStreakCard() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.orange.shade400, Colors.orange.shade600],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.orange.withOpacity(0.3),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Icon(
//             Icons.local_fire_department,
//             size: 48,
//             color: Colors.white,
//           ),
//           const SizedBox(height: 8),
//           Text(
//             '$_currentStreak',
//             style: const TextStyle(
//               fontSize: 32,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//           Text(
//             _currentStreak == 1 ? 'Day Streak' : 'Days Streak',
//             style: const TextStyle(
//               fontSize: 16,
//               color: Colors.white,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             _getStreakMessage(),
//             style: const TextStyle(
//               fontSize: 12,
//               color: Colors.white70,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   String _getStreakMessage() {
//     if (_currentStreak == 0) return 'Start practicing to begin your streak!';
//     if (_currentStreak == 1) return 'Great start! Keep it up tomorrow.';
//     if (_currentStreak < 7) return 'You\'re building momentum!';
//     if (_currentStreak < 30) return 'Excellent consistency!';
//     return 'You\'re a pronunciation master!';
//   }

//   Widget _buildWeeklyStatsGrid() {
//     return GridView.count(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       crossAxisCount: 2,
//       crossAxisSpacing: 12,
//       mainAxisSpacing: 12,
//       childAspectRatio: 1.2,
//       children: [
//         _buildStatCard(
//           title: 'Sessions',
//           value: '${_weeklyStats!.totalSessions}',
//           icon: Icons.play_circle,
//           color: Colors.blue,
//           subtitle: 'This week',
//         ),
//         _buildStatCard(
//           title: 'Minutes',
//           value: '${_weeklyStats!.totalMinutes}',
//           icon: Icons.timer,
//           color: Colors.green,
//           subtitle: 'Practice time',
//         ),
//         _buildStatCard(
//           title: 'Accuracy',
//           value: '${(_weeklyStats!.averageAccuracy * 100).toInt()}%',
//           icon: Icons.check_circle,
//           color: Colors.orange,
//           subtitle: 'Average',
//         ),
//         _buildStatCard(
//           title: 'Best Score',
//           value: '${(_weeklyStats!.bestAccuracy * 100).toInt()}%',
//           icon: Icons.star,
//           color: Colors.purple,
//           subtitle: 'Personal best',
//         ),
//       ],
//     );
//   }

//   Widget _buildStatCard({
//     required String title,
//     required String value,
//     required IconData icon,
//     required Color color,
//     required String subtitle,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: color.withOpacity(0.3),
//           width: 1,
//         ),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(icon, color: color, size: 32),
//           const SizedBox(height: 8),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//               color: color,
//             ),
//           ),
//           Text(
//             subtitle,
//             style: TextStyle(
//               fontSize: 10,
//               color: color.withOpacity(0.7),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildAccuracyChart() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Accuracy Trend',
//             style: Theme.of(context).textTheme.titleMedium?.copyWith(
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Container(
//             height: 200,
//             child: Center(
//               child: Text(
//                 'Chart would show accuracy trend over time\n(Implementation depends on charting library)',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.grey.shade600),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildProgressTab() {
//     return FutureBuilder<List<PronunciationProgressEntry>>(
//       future: PronunciationProgressTracker.getProgressHistory(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
        
//         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return const Center(
//             child: Text('No practice sessions yet.\nStart practicing to see your history!'),
//           );
//         }
        
//         final history = snapshot.data!;
//         return ListView.builder(
//           padding: const EdgeInsets.all(16),
//           itemCount: history.length,
//           itemBuilder: (context, index) {
//             final entry = history[index];
//             return _buildProgressItem(entry);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildProgressItem(PronunciationProgressEntry entry) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 8),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: _getAccuracyColor(entry.averageAccuracy),
//           child: Text(
//             '${(entry.averageAccuracy * 100).toInt()}%',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 10,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         title: Text('Verse ${entry.verseIndex + 1}'),
//         subtitle: Text(
//           '${entry.attempts} attempts • ${entry.duration.inMinutes}m ${entry.duration.inSeconds % 60}s',
//         ),
//         trailing: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             Text(
//               _formatDate(entry.date),
//               style: const TextStyle(fontSize: 12),
//             ),
//             if (entry.improvementScore > 0)
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     Icons.trending_up,
//                     size: 12,
//                     color: Colors.green,
//                   ),
//                   Text(
//                     '+${(entry.improvementScore * 100).toInt()}%',
//                     style: const TextStyle(
//                       fontSize: 10,
//                       color: Colors.green,
//                     ),
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAchievementsTab() {
//     if (_achievements.isEmpty) {
//       return const Center(
//         child: Text('No achievements unlocked yet.\nKeep practicing to earn your first achievement!'),
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _achievements.length,
//       itemBuilder: (context, index) {
//         final achievement = _achievements[index];
//         return _buildAchievementItem(achievement);
//       },
//     );
//   }

//   Widget _buildAchievementItem(PronunciationAchievement achievement) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       child: ListTile(
//         leading: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.amber.withOpacity(0.2),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Icon(
//             achievement.icon,
//             color: Colors.amber.shade700,
//           ),
//         ),
//         title: Text(
//           achievement.title,
//           style: const TextStyle(fontWeight: FontWeight.bold),
//         ),
//         subtitle: Text(achievement.description),
//         trailing: Text(
//           _formatDate(achievement.unlockedAt),
//           style: const TextStyle(fontSize: 12),
//         ),
//       ),
//     );
//   }

//   Color _getAccuracyColor(double accuracy) {
//     if (accuracy >= 0.9) return Colors.green;
//     if (accuracy >= 0.7) return Colors.orange;
//     if (accuracy >= 0.5) return Colors.amber;
//     return Colors.red;
//   }

//   String _formatDate(DateTime date) {
//     final now = DateTime.now();
//     final difference = now.difference(date);
    
//     if (difference.inDays == 0) return 'Today';
//     if (difference.inDays == 1) return 'Yesterday';
//     if (difference.inDays < 7) return '${difference.inDays}d ago';
//     return '${date.day}/${date.month}';
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
// }