// lib/screens/prayer_guidance_screen.dart 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrayerGuidanceScreen extends StatefulWidget {
  const PrayerGuidanceScreen({super.key});

  @override
  State<PrayerGuidanceScreen> createState() => _PrayerGuidanceScreenState();
}

class _PrayerGuidanceScreenState extends State<PrayerGuidanceScreen> {
  int _currentStepIndex = 0;
  
  final List<Map<String, dynamic>> _prayerSteps = [
    {
      'title': 'Takbir - تكبير',
      'subtitle': 'Opening the Prayer',
      'description': 'Raise both hands to ear level with palms facing forward and say "Allahu Akbar" (Allah is Greatest).',
      'icon': Icons.pan_tool,
      'color': Colors.blue,
      'details': [
        'Stand facing the Qibla (direction of Kaaba)',
        'Raise hands to shoulder or ear level',
        'Keep palms open and facing forward',
        'Say "Allahu Akbar" clearly',
        'This marks the beginning of prayer'
      ],
    },
    {
      'title': 'Qiyam - قيام',
      'subtitle': 'Standing Position',
      'description': 'Stand upright with hands folded over the chest or abdomen, recite Al-Fatiha and other verses.',
      'icon': Icons.accessibility_new,
      'color': Colors.green,
      'details': [
        'Stand straight and tall',
        'Place right hand over left hand',
        'Position hands on chest or just below',
        'Look at the place of prostration',
        'Recite Al-Fatiha and additional verses'
      ],
    },
    {
      'title': 'Ruku - ركوع',
      'subtitle': 'Bowing Position',
      'description': 'Bow down with hands on knees, keeping back straight and saying "Subhana Rabbiy al-Adheem".',
      'icon': Icons.keyboard_arrow_down,
      'color': Colors.orange,
      'details': [
        'Say "Allahu Akbar" while moving to bow',
        'Bend at the waist with straight back',
        'Place hands firmly on knees',
        'Keep head aligned with back',
        'Say "Subhana Rabbiy al-Adheem" (3x)'
      ],
    },
    {
      'title': 'I\'tidal - اعتدال',
      'subtitle': 'Standing from Ruku',
      'description': 'Return to standing position and say "Sami\'a Allahu liman hamidah, Rabbana wa laka al-hamd".',
      'icon': Icons.keyboard_arrow_up,
      'color': Colors.purple,
      'details': [
        'Rise slowly from bowing position',
        'Say "Sami\'a Allahu liman hamidah"',
        'Stand fully upright',
        'Then say "Rabbana wa laka al-hamd"',
        'Hands at sides or folded'
      ],
    },
    {
      'title': 'Sujud - سجود',
      'subtitle': 'Prostration',
      'description': 'Prostrate with forehead, nose, palms, knees, and toes touching the ground.',
      'icon': Icons.keyboard_double_arrow_down,
      'color': Colors.red,
      'details': [
        'Say "Allahu Akbar" while going down',
        'Knees touch ground first, then hands',
        'Forehead and nose touch the ground',
        'Seven parts touch the ground',
        'Say "Subhana Rabbiy al-A\'ala" (3x)'
      ],
    },
    {
      'title': 'Jalsa - جلسة',
      'subtitle': 'Sitting Between Prostrations',
      'description': 'Sit between the two prostrations and make du\'a.',
      'icon': Icons.event_seat,
      'color': Colors.teal,
      'details': [
        'Sit on your left foot',
        'Right foot upright with toes pointing forward',
        'Hands on thighs',
        'Say "Rabbighfir li" or other du\'a',
        'Brief pause before second prostration'
      ],
    },
    {
      'title': 'Tahiyat - تحيات',
      'subtitle': 'Final Sitting',
      'description': 'Sit for the final tashahhud and send blessings upon the Prophet.',
      'icon': Icons.chair,
      'color': Colors.indigo,
      'details': [
        'Sit in the same position as Jalsa',
        'Recite the Tashahhud',
        'Point with index finger when saying "La ilaha illa Allah"',
        'Send blessings upon Prophet Muhammad',
        'Make personal du\'a if desired'
      ],
    },
    {
      'title': 'Salam - سلام',
      'subtitle': 'Ending the Prayer',
      'description': 'Turn your head right then left, saying "As-salamu alaykum wa rahmatullah".',
      'icon': Icons.waving_hand,
      'color': Colors.amber,
      'details': [
        'Turn head to the right shoulder',
        'Say "As-salamu alaykum wa rahmatullah"',
        'Turn head to the left shoulder',
        'Say "As-salamu alaykum wa rahmatullah"',
        'Prayer is now complete'
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Guidance'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/home'),
          tooltip: 'Back to Home',
        ),
        actions: [
          IconButton(
            onPressed: _showOverview,
            icon: const Icon(Icons.list),
            tooltip: 'Prayer Overview',
          ),
          
        ],
      ),
      
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Main content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildStepContent(),
              ),
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.teal.shade50,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStepIndex + 1} of ${_prayerSteps.length}',
                style: TextStyle(
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${((_currentStepIndex + 1) / _prayerSteps.length * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStepIndex + 1) / _prayerSteps.length,
            backgroundColor: Colors.teal.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    final currentStep = _prayerSteps[_currentStepIndex];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: currentStep['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: currentStep['color'].withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                currentStep['icon'],
                size: 64,
                color: currentStep['color'],
              ),
              const SizedBox(height: 16),
              Text(
                currentStep['title'],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: currentStep['color'],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                currentStep['subtitle'],
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Description
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            currentStep['description'],
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Detailed steps
        const Text(
          'Step-by-step Guide:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        ...List.generate(currentStep['details'].length, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: currentStep['color'],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentStep['details'][index],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _currentStepIndex > 0 ? _previousStep : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _currentStepIndex < _prayerSteps.length - 1 ? _nextStep : _resetGuide,
              icon: Icon(_currentStepIndex < _prayerSteps.length - 1 ? Icons.arrow_forward : Icons.refresh),
              label: Text(_currentStepIndex < _prayerSteps.length - 1 ? 'Next' : 'Restart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  void _nextStep() {
    if (_currentStepIndex < _prayerSteps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    }
  }

  void _resetGuide() {
    setState(() {
      _currentStepIndex = 0;
    });
  }

  void _showOverview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prayer Steps Overview'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(_prayerSteps.length, (index) {
                final step = _prayerSteps[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: step['color'],
                    child: Icon(
                      step['icon'],
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    step['title'],
                    style: TextStyle(
                      fontWeight: index == _currentStepIndex ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(step['subtitle']),
                  onTap: () {
                    setState(() {
                      _currentStepIndex = index;
                    });
                    Navigator.of(context).pop();
                  },
                  selected: index == _currentStepIndex,
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}