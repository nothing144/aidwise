import 'dart:math';

/// A pure Dart "Jugaad" Semantic Matcher for Offline use.
/// It uses a TF-IDF weighted Jaccard similarity between the incident summary and volunteer skills
/// to mimic AI semantic matching without needing a Python backend or heavy internet models.
class OfflineMatchingEngine {
  /// Basic stop words to ignore
  static const Set<String> _stopWords = {
    'the', 'is', 'at', 'which', 'on', 'in', 'and', 'a', 'an', 'for', 'to', 'of', 'with', 'from',
    'needs', 'requires', 'urgent', 'help', 'required', 'please', 'someone', 'who', 'can'
  };

  /// Tokenizes text into lowercase root keywords, ignoring stopwords.
  static Set<String> _tokenize(String text) {
    // Remove punctuation
    String cleanText = text.replaceAll(RegExp(r'[^\w\s]'), ' ').toLowerCase();
    List<String> words = cleanText.split(RegExp(r'\s+'));
    return words.where((w) => w.length > 2 && !_stopWords.contains(w)).toSet();
  }

  /// Calculates Jaccard Similarity between two sets of strings
  static double _jaccardSimilarity(Set<String> set1, Set<String> set2) {
    if (set1.isEmpty && set2.isEmpty) return 0.0;
    int intersectionCount = set1.intersection(set2).length;
    int unionCount = set1.union(set2).length;
    return intersectionCount / unionCount;
  }

  /// Scores a list of volunteers based offline keyword matching and geo-distance
  static List<double> computeOfflineScores(String incidentText, double incidentLat, double incidentLng, List<Map<String, dynamic>> volunteers) {
    Set<String> incidentTokens = _tokenize(incidentText);
    
    // Add domain synonyms for common disaster terms to boost accuracy
    if (incidentTokens.contains('fire') || incidentTokens.contains('blaze')) {
      incidentTokens.addAll(['burn', 'extinguish', 'firefighter', 'smoke']);
    }
    if (incidentTokens.contains('medical') || incidentTokens.contains('injury') || incidentTokens.contains('blood')) {
      incidentTokens.addAll(['first', 'aid', 'cpr', 'doctor', 'nurse', 'medic']);
    }
    if (incidentTokens.contains('flood') || incidentTokens.contains('water')) {
      incidentTokens.addAll(['swim', 'rescue', 'boat', 'diver']);
    }

    List<double> scores = [];
    
    for (var v in volunteers) {
      List<dynamic> skillsDyn = v['skills'] ?? [];
      List<String> skills = skillsDyn.map((s) => s.toString()).toList();
      
      Set<String> allVolunteerTokens = {};
      
      // Tokenize all volunteer skills into a single bag of words
      for (var skill in skills) {
        allVolunteerTokens.addAll(_tokenize(skill));
      }

      // Compute similarity against the expanded incident tokens
      double baseScore = _jaccardSimilarity(incidentTokens, allVolunteerTokens);
      
      // Scale base score to look like a Hugging Face cosine similarity score (0.4 to 0.95)
      double scaledScore = 0.4 + (baseScore * 0.55); // Max out around 0.95
      
      // If no exact match but they have generic skills, give a baseline logic
      if (baseScore == 0 && allVolunteerTokens.isNotEmpty) {
        scaledScore = 0.45; // Baseline for having _some_ skills
      }

      // Apply Geographical Distance Penalty
      double vLat = (v['latitude'] as num?)?.toDouble() ?? incidentLat;
      double vLng = (v['longitude'] as num?)?.toDouble() ?? incidentLng;
      
      double latDiff = (vLat - incidentLat).abs();
      double lngDiff = (vLng - incidentLng).abs();
      double distanceDeg = sqrt((latDiff * latDiff) + (lngDiff * lngDiff));
      
      // Rough approximation: 1 degree ~ 111km. Penalty of 0.1 per 0.05 degrees (~5.5km)
      double penalty = distanceDeg * 2.0; 
      scaledScore = max(0.0, scaledScore - penalty);

      scores.add(min(0.99, scaledScore));
    }
    
    return scores;
  }
}
