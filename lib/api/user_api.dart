import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// Nom de la méthode permettant d'envoyer les données d'inscription à l'API.
Future<int> registerUser(
  String firstName,
  String lastName,
  String email,
  String password,
) async {
  final baseUrl = dotenv.env['API_BASE_URL'];

  if (baseUrl == null || baseUrl.trim().isEmpty) {
    if (kDebugMode) {
      debugPrint('Variable API_BASE_URL manquante dans assets/.env.local');
    }
    return 0;
  }

  final uri = Uri.parse('${baseUrl.trim()}/users');

  // API Platform demande application/ld+json pour le Content-Type et le Accept.
  final headers = {
    'Content-Type': 'application/ld+json',
    'Accept': 'application/ld+json',
  };

  // Construction du corps de la requête avec les données d'inscription.
  final body = jsonEncode({
    'prenom': firstName,
    'nom': lastName,
    'email': email,
    'password': password,
  });

  try {
    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 201) {
      return 201;
    }

    if (kDebugMode) {
      debugPrint('Echec inscription : ${response.statusCode}');
    }
    return response.statusCode;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Exception lors de la requete : $e');
    }
    return 0; // Erreur reseau
  }
}
