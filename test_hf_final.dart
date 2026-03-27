import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🚀 Final HF Integration Test...');
  const String hfToken = "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";
  const String hfEndpoint = "https://router.huggingface.co/hf-inference/models/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2";

  final response = await http.post(
    Uri.parse(hfEndpoint),
    headers: {'Authorization': 'Bearer $hfToken', 'Content-Type': 'application/json'},
    body: jsonEncode({
      "inputs": {
        "source_sentence": "Blood required urgently for a medical emergency at Sector 4",
        "sentences": [
          "Volunteer skilled in: Medical Provider, Blood Donor, First Aid",
          "Volunteer skilled in: IT Support, Logistics, Truck Driver", 
          "Volunteer skilled in: Teacher, Tutor, Education",
          "Volunteer skilled in: Animal Rescue, Veterinary Care",
          "Volunteer skilled in: Cooking, Food Distribution"
        ]
      }
    }),
  );

  print('Status: ${response.statusCode}');
  if (response.statusCode == 200) {
    final List<dynamic> scores = jsonDecode(response.body);
    print('\n📊 SEMANTIC SIMILARITY SCORES:');
    List<String> labels = ["Medical/Blood", "IT/Logistics", "Teacher", "Animal Rescue", "Food"];
    for (int i = 0; i < scores.length; i++) {
      double pct = (scores[i] as num).toDouble() * 100;
      print('  ${labels[i]}: ${pct.toStringAsFixed(1)}%');
    }
    
    // Write results to file too
    StringBuffer log = StringBuffer();
    log.writeln('STATUS: ${response.statusCode}');
    log.writeln('RAW: ${response.body}');
    for (int i = 0; i < scores.length; i++) {
      double pct = (scores[i] as num).toDouble() * 100;
      log.writeln('${labels[i]}: ${pct.toStringAsFixed(1)}%');
    }
    await File('final_test_results.txt').writeAsString(log.toString());
    print('\n✅ Results also written to final_test_results.txt');
  } else {
    print('❌ Error: ${response.body}');
  }
}
