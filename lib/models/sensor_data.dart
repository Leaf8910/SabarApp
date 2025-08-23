// models/sensor_data.dart
class SensorData {
  final int timestamp;
  final PirData pir;
  final FsrData fsr1;
  final FsrData fsr2;
  final FsrData fsr3;
  final MicrophoneData microphone;
  final DateTime receivedAt;

  SensorData({
    required this.timestamp,
    required this.pir,
    required this.fsr1,
    required this.fsr2,
    required this.fsr3,
    required this.microphone,
    required this.receivedAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      timestamp: json['timestamp']?.toInt() ?? 0,
      pir: PirData.fromJson(json['pir'] ?? {}),
      fsr1: FsrData.fromJson(json['fsr1'] ?? {}),
      fsr2: FsrData.fromJson(json['fsr2'] ?? {}),
      fsr3: FsrData.fromJson(json['fsr3'] ?? {}),
      microphone: MicrophoneData.fromJson(json['microphone'] ?? {}),
      receivedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'pir': pir.toJson(),
      'fsr1': fsr1.toJson(),
      'fsr2': fsr2.toJson(),
      'fsr3': fsr3.toJson(),
      'microphone': microphone.toJson(),
      'receivedAt': receivedAt.toIso8601String(),
    };
  }

  bool get hasMovement => pir.motion;
  bool get hasSound => microphone.soundDetected;
  bool get hasPressure => fsr1.value > 10 || fsr2.value > 10 || fsr3.value > 10;
  
  // Calculate overall activity level (0-100)
  int get activityLevel {
    int level = 0;
    if (hasMovement) level += 40;
    if (hasSound) level += 30;
    if (hasPressure) level += 30;
    return level.clamp(0, 100);
  }

  // Get a human-readable summary
  String get summary {
    List<String> activities = [];
    
    if (hasMovement) activities.add('Movement');
    if (hasSound) activities.add('Sound');
    if (hasPressure) activities.add('Pressure');
    
    if (activities.isEmpty) {
      return 'All quiet';
    } else {
      return activities.join(', ') + ' detected';
    }
  }

  @override
  String toString() {
    return 'SensorData(timestamp: $timestamp, motion: ${pir.motion}, sound: ${microphone.soundDetected}, activity: $activityLevel%)';
  }
}

class PirData {
  final bool motion;
  final String status;

  PirData({
    required this.motion,
    required this.status,
  });

  factory PirData.fromJson(Map<String, dynamic> json) {
    return PirData(
      motion: json['motion'] ?? false,
      status: json['status'] ?? 'No Motion',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'motion': motion,
      'status': status,
    };
  }
}

class FsrData {
  final int value;
  final String status;
  final int baseline;

  FsrData({
    required this.value,
    required this.status,
    required this.baseline,
  });

  factory FsrData.fromJson(Map<String, dynamic> json) {
    return FsrData(
      value: json['value']?.toInt() ?? 0,
      status: json['status'] ?? 'no pressure',
      baseline: json['baseline']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'status': status,
      'baseline': baseline,
    };
  }

  // Get pressure level as percentage
  double get pressurePercentage {
    if (value <= 0) return 0.0;
    return (value / 1000.0).clamp(0.0, 1.0); // Assuming max reading around 1000
  }
}

class MicrophoneData {
  final int soundLevel;
  final int peakToPeak;
  final bool soundDetected;
  final String status;
  final int baseline;

  MicrophoneData({
    required this.soundLevel,
    required this.peakToPeak,
    required this.soundDetected,
    required this.status,
    required this.baseline,
  });

  factory MicrophoneData.fromJson(Map<String, dynamic> json) {
    return MicrophoneData(
      soundLevel: json['sound_level']?.toInt() ?? 0,
      peakToPeak: json['peak_to_peak']?.toInt() ?? 0,
      soundDetected: json['sound_detected'] ?? false,
      status: json['status'] ?? 'silent',
      baseline: json['baseline']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sound_level': soundLevel,
      'peak_to_peak': peakToPeak,
      'sound_detected': soundDetected,
      'status': status,
      'baseline': baseline,
    };
  }

  // Get sound level as percentage
  double get soundLevelPercentage {
    if (soundLevel <= 0) return 0.0;
    return (soundLevel / 500.0).clamp(0.0, 1.0); // Assuming max useful reading around 500
  }
}