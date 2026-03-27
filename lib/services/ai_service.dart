import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class AIService {
  // Master Switch: false = 0 cost/fast testing, true = real Gemini API calls
  static const bool isLiveMode = true; 

  static const String _apiKey = "AIzaSyA5zfFBETmHyBQgozYaNT_xkL3tj9PVjlI"; 

  // ─────────────────────────── SKILL TAXONOMY ───────────────────────────
  // Maps report "type" keywords to relevant volunteer skills.
  // This acts as a lightweight "feature vector" for local ML scoring.
  static const Map<String, List<String>> _skillRelevanceMap = {
    'medical':     ['Medical Provider', 'Blood Donor', 'Counselling'],
    'blood':       ['Blood Donor', 'Medical Provider'],
    'education':   ['Teacher / Tutor', 'IT Support', 'Counselling'],
    'food':        ['Food Distribution', 'Logistics & Transport'],
    'logistics':   ['Logistics & Transport', 'Food Distribution'],
    'search':      ['Search & Rescue', 'Logistics & Transport'],
    'fire':        ['Search & Rescue', 'Logistics & Transport'],
    'rescue':      ['Search & Rescue', 'Medical Provider'],
    'counselling': ['Counselling', 'Teacher / Tutor'],
    'it':          ['IT Support', 'Teacher / Tutor'],
    'animal':      ['Animal Welfare', 'Veterinary', 'Search & Rescue'],
    'clothing':    ['Clothing Drive', 'Logistics & Transport'],
    'sanitation':  ['Sanitation & Hygiene', 'Labor Support'],
    'shelter':     ['Shelter Management', 'Logistics & Transport'],
    'elderly':     ['Elderly Care', 'Medical Provider', 'Counselling'],
  };

  // ─────────────────────── FIELD REPORT ANALYZER ───────────────────────
  static Future<Map<String, dynamic>> analyzeFieldReport({String? textInput, Uint8List? imageBytes}) async {
    if (!isLiveMode) {
      await Future.delayed(const Duration(seconds: 1));
      return { 
        "urgency": "High", 
        "type": "Blood Required", 
        "location": "Detected from text" 
      };
    }
    
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash', 
        apiKey: _apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json')
      );
      
      final promptString = 'Analyze this NGO field incident report. If there is an image, describe the emergency visible. If there is text, use it too. Text provided: "${textInput ?? 'None'}". '
      'CRITICAL: If the image does NOT depict an emergency, disaster, or relevant NGO incident (e.g. it is a normal selfie, meme, random object, normal scenery), you MUST return "type": "Irrelevant" and "urgency": "None" and "location": "Unknown". '
      'If it IS an emergency, return a strict JSON object with: 1) "urgency" (Low/Medium/High/Critical), 2) "type" (Short 2-word need type, e.g. "Medical Need", "Blood Required", "Education Support", "Food Drive", "Logistics Help", "Search Rescue", "Fire Hazard"), 3) "location" (Extracted location, or "Unknown").';
      
      late GenerateContentResponse response;
      if (imageBytes != null) {
        final imagePart = DataPart('image/jpeg', imageBytes);
        response = await model.generateContent([
          Content.multi([TextPart(promptString), imagePart])
        ]);
      } else {
        response = await model.generateContent([
          Content.text(promptString)
        ]);
      }
      return jsonDecode(response.text!);
    } catch (e) {
      print("Gemini API Error: $e");
      return { 
        "urgency": "Error", 
        "type": "API_ERROR", 
        "location": "API Connection Failed" 
      };
    }
  }

  // ───────── MULTI-FACTOR SCORING ENGINE (Local ML + HF Sentence Transformer) ─────────

  static const String _hfToken = "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";
  static const String _hfEndpoint = "https://api-inference.huggingface.co/models/wtfharsh144Pandey/aidwise";

  /// Batch computes semantic skill similarity scores using the custom Hugging Face trained model.
  static Future<List<double>> batchComputeHFSkillScores(String need, List<String> volunteerSkillSentences) async {
    if (!isLiveMode || volunteerSkillSentences.isEmpty) {
      return List.filled(volunteerSkillSentences.length, 0.8);
    }
    
    try {
      final response = await http.post(
        Uri.parse(_hfEndpoint),
        headers: {
          'Authorization': 'Bearer $_hfToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "inputs": {
            "source_sentence": need,
            "sentences": volunteerSkillSentences
          }
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonResp = jsonDecode(response.body);
        return jsonResp.map((e) => (e as num).toDouble()).toList();
      } else {
        print("HF API Error: ${response.statusCode} - ${response.body}");
        return List.filled(volunteerSkillSentences.length, 0.5); // Fallback
      }
    } catch (e) {
      print("HF Network Error: $e");
      return List.filled(volunteerSkillSentences.length, 0.5); // Fallback
    }
  }

  /// Computes a weighted composite score. Allows injecting the HF-computed skillScore.
  static Map<String, dynamic> computeLocalScore(
    Map<String, dynamic> volunteer,
    Map<String, dynamic> report,
    {double? injectedSkillScore}
  ) {
    double skillScore = injectedSkillScore ?? _computeSkillScore(volunteer, report);
    double distanceScore = _computeDistanceScore(volunteer, report);
    double availabilityScore = _computeAvailabilityScore(volunteer);

    // Weighted combination (Skills most important for hackathon context)
    // Skills: 50%, Distance: 30%, Availability: 20%
    double totalScore = (skillScore * 0.50) + (distanceScore * 0.30) + (availabilityScore * 0.20);

    return {
      'skill_score': (skillScore * 100).round(),
      'distance_score': (distanceScore * 100).round(),
      'availability_score': (availabilityScore * 100).round(),
      'total_score': (totalScore * 100).round(),
    };
  }

  /// Skill Matching: Checks how many of the volunteer's skills are relevant to the report type.
  static double _computeSkillScore(Map<String, dynamic> volunteer, Map<String, dynamic> report) {
    List<String> volSkills = List<String>.from(volunteer['skills'] ?? []);
    if (volSkills.isEmpty) return 0.2; // Some base score even if no skills entered

    String reportType = (report['type'] ?? '').toString().toLowerCase();

    // Find the best matching skill category
    List<String> relevantSkills = [];
    for (var key in _skillRelevanceMap.keys) {
      if (reportType.contains(key)) {
        relevantSkills.addAll(_skillRelevanceMap[key]!);
      }
    }
    if (relevantSkills.isEmpty) return 0.4; // Neutral if report type is unknown

    // Count how many of the volunteer's skills match
    int matchCount = volSkills.where((s) => relevantSkills.contains(s)).length;
    return min(1.0, matchCount / max(1, relevantSkills.toSet().length) + 0.3); // 0.3 base
  }

  /// Distance Scoring: Uses Haversine formula for actual geographic distance.
  static double _computeDistanceScore(Map<String, dynamic> volunteer, Map<String, dynamic> report) {
    double? volLat = _toDouble(volunteer['latitude']);
    double? volLng = _toDouble(volunteer['longitude']);
    double? repLat = _toDouble(report['latitude']);
    double? repLng = _toDouble(report['longitude']);

    if (volLat == null || volLng == null || repLat == null || repLng == null) {
      return 0.5; // Neutral if location data is missing
    }

    double distKm = _haversine(volLat, volLng, repLat, repLng);
    // Scoring: < 5km = 1.0, 5-20km = 0.7, 20-50km = 0.4, > 50km = 0.2
    if (distKm < 5) return 1.0;
    if (distKm < 20) return 0.7;
    if (distKm < 50) return 0.4;
    return 0.2;
  }

  /// Availability: Checks if volunteer has the vehicle to respond quickly.
  static double _computeAvailabilityScore(Map<String, dynamic> volunteer) {
    String vehicle = (volunteer['vehicleType'] ?? '').toString().toLowerCase().trim();
    // Has a vehicle = higher availability score
    if (vehicle.contains('truck') || vehicle.contains('van') || vehicle.contains('ambulance')) return 1.0;
    if (vehicle.contains('car') || vehicle.contains('bike') || vehicle.contains('motorcycle')) return 0.8;
    if (vehicle.isNotEmpty) return 0.6;
    return 0.3; // No vehicle
  }

  /// Haversine formula to calculate distance between two lat/lng points in km
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in km
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // ─────────── GEMINI AI REASONING (for Top Candidates) ───────────
  /// Generates a human-readable reasoning sentence for why this volunteer is a good/bad match.
  static Future<Map<String, dynamic>> generateMatchReasoning(
    Map<String, dynamic> volunteer,
    Map<String, dynamic> report,
    Map<String, dynamic> localScores,
  ) async {
    if (!isLiveMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return { 
        "reasoning": "Strong skill overlap with ${report['type']}. Vehicle available for rapid deployment."
      };
    }
    
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash', 
        apiKey: _apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json')
      );
      
      final prompt = '''You are an intelligent resource allocation engine for NGOs.
Given the following data, explain in 1 concise sentence WHY this volunteer is suitable for this task.

Volunteer: Name=${volunteer['displayName']}, Skills=${volunteer['skills']}, Vehicle=${volunteer['vehicleType']}
Incident Report: Type=${report['type']}, Urgency=${report['urgency']}, Location=${report['location']}
Pre-computed Scores: SkillMatch=${localScores['skill_score']}%, Proximity=${localScores['distance_score']}%, Availability=${localScores['availability_score']}%

Return JSON: {"reasoning": "1 short professional sentence"}''';
      
      final response = await model.generateContent([Content.text(prompt)]);
      return jsonDecode(response.text!);
    } catch (e) {
      print("Gemini Reasoning Error: $e");
      return { 
        "reasoning": "Matched based on skill relevance (${localScores['skill_score']}%) and proximity (${localScores['distance_score']}%)."
      };
    }
  }

  // ─────────── AI SITUATION SUMMARY (for Admin Dashboard) ───────────
  /// Generates a 1-paragraph strategic summary of all open incidents.
  static Future<String> generateSituationSummary(List<Map<String, dynamic>> openReports, int volunteerCount) async {
    if (openReports.isEmpty) {
      return 'No active incidents. All systems nominal.';
    }

    if (!isLiveMode) {
      await Future.delayed(const Duration(seconds: 1));
      return 'SITUATION BRIEF: ${openReports.length} active incidents across multiple clusters. '
          'Primary concern: Medical emergencies (60%). $volunteerCount volunteers available for deployment. '
          'Recommend prioritizing critical cases in high-density areas first.';
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final reportSummaries = openReports.map((r) =>
        'Type: ${r['type']}, Urgency: ${r['urgency']}, Location: ${r['location']}'
      ).join(' | ');

      final prompt = '''You are an NGO operations AI. Analyze these ${openReports.length} active field incident reports and generate a 2-3 sentence STRATEGIC SITUATION BRIEF for the operations commander.

Reports: $reportSummaries
Available Volunteers: $volunteerCount

Be specific about patterns you see (e.g., what % are medical vs food, which areas are hotspots). End with one actionable recommendation. Keep it under 80 words. Do NOT use markdown.''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Unable to generate summary.';
    } catch (e) {
      print("Gemini Summary Error: $e");
      return 'SUMMARY: ${openReports.length} active incidents detected. $volunteerCount volunteers on standby. Manual review recommended.';
    }
  }

  // ─────────── LEGACY: Simple Synergy (kept for backward compat) ───────────
  static Future<Map<String, dynamic>> calculateSynergy(Map<String, dynamic> volunteer, Map<String, dynamic> report) async {
    final scores = computeLocalScore(volunteer, report);
    final reasoning = await generateMatchReasoning(volunteer, report, scores);
    return {
      'match_percentage': scores['total_score'],
      'reasoning': reasoning['reasoning'],
    };
  }
}
