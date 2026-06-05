# Wheello

Wheello est une application Flutter de gestion de flotte de véhicules pour les utilisateurs mobiles d'Habitat Insertion.

L'application permet de consulter les véhicules disponibles, créer et modifier des réservations, suivre ses trajets, démarrer et terminer des constats, signaler une anomalie avec vidéo optionnelle et consulter ses notifications.

## Fonctionnalités

- Connexion mobile par e-mail ou identifiant interne.
- Session sécurisée par jeton JWT stocké avec `flutter_secure_storage`.
- Liste des véhicules rattachés aux sites de l'utilisateur.
- Recherche, filtres et tri des véhicules.
- Détail véhicule avec localisation, stationnement, énergie, kilométrage et anomalies connues.
- Calendrier de disponibilité par véhicule.
- Gestion des jours libres, partiels, réservés, en maintenance et indisponibles côté utilisateur.
- Création de réservation avec vérification des conflits.
- Modification et suppression de réservation selon les règles métier.
- Tampon obligatoire d'une heure entre deux réservations du même véhicule.
- Blocage des jours passés et des heures déjà passées.
- Suggestions automatiques d'heures sur les jours partiellement disponibles.
- Espace "Mes Réservations" avec calendrier visuel.
- Prise en charge du véhicule via constat de départ.
- Retour du véhicule via constat de fin.
- Bouton retour disponible immédiatement après le départ confirmé.
- Statut "En usage" calculé depuis les constats ouverts/non fermés.
- Signalement d'anomalie avec vidéo optionnelle.
- Notifications API et rappels locaux de départ/retour.
- Profil utilisateur, sites rattachés, permissions notifications et déconnexion.

## Stack technique

- Flutter / Dart
- Material 3
- `http` pour les appels API
- `flutter_dotenv` pour la configuration locale
- `flutter_secure_storage` pour la session
- `image_picker` et `camera` pour les vidéos de signalement
- `permission_handler` pour les permissions natives
- `flutter_test` pour les tests unitaires et widgets

## Prérequis

- Flutter installé et configuré.
- Dart compatible avec le SDK défini dans `pubspec.yaml`.
- Un émulateur, simulateur ou appareil physique.
- Accès à l'API métier Habitat Insertion.

Version SDK déclarée :

```yaml
environment:
  sdk: ^3.10.4
```

## Installation

Cloner le projet :

```bash
git clone <url-du-repo>
cd mobile_habitat_insertion
```

Installer les dépendances :

```bash
flutter pub get
```

Créer ou vérifier le fichier d'environnement :

```text
assets/.env.local
```

Exemple :

```env
API_BASE_URL=https://example.com/api
```

Si `API_BASE_URL` n'est pas défini, l'application utilise le fallback codé dans `lib/services/api_config.dart`.

## Lancement

Lancer l'application :

```bash
flutter run
```

Analyser le code :

```bash
flutter analyze
```

Lancer les tests :

```bash
flutter test
```

Formater le code :

```bash
dart format lib test
```

## Architecture

La logique applicative est principalement dans `lib`.

```text
lib/
├── data/          # Stores et données mock/dev
├── models/        # Modèles métier
├── navigation/    # Routes nommées
├── screens/fleet/ # Écrans principaux de l'application flotte
├── services/      # API, session, mappers, notifications, vidéos
├── theme/         # Couleurs, thème, assets, marque
├── utils/         # Règles transversales de réservation
├── widgets/       # Composants UI réutilisables
└── main.dart      # Point d'entrée Flutter
```

### Couches principales

`models`

Contient les objets métier utilisés dans toute l'application :

- `Vehicle`
- `VehicleStatus`
- `AvailabilityStatus`
- `VehicleAvailabilityMonth`
- `FleetReservation`
- `ReservationStatus`
- `AppNotification`

`services`

Centralise les échanges avec l'API et les services natifs :

- `ApiClient` : client HTTP commun.
- `ApiConfig` : configuration de la base API.
- `ApiException` : erreurs API lisibles.
- `AuthApiService` : connexion et refresh de session.
- `AuthSessionService` : stockage local sécurisé.
- `FleetApiService` : service métier flotte.
- `FleetApiMappers` : conversion JSON API vers modèles.
- `NotificationApiService` : notifications API.
- `ReservationVideoService` : capture vidéo.

`screens/fleet`

Regroupe les écrans utilisateur :

- connexion ;
- accueil à onglets ;
- liste véhicules ;
- détail véhicule et réservation ;
- modification réservation ;
- réservations ;
- prise en charge ;
- retour ;
- signalement ;
- profil ;
- notifications.

`widgets`

Contient les composants partagés :

- cartes ;
- barre de navigation ;
- barre supérieure ;
- calendriers ;
- cartes véhicules ;
- boutons d'action ;
- puces de statut ;
- upload vidéo.

`utils`

Contient les règles transversales de réservation :

- jours occupés ;
- chevauchements ;
- indisponibilités utilisateur ;
- tampon d'une heure.

## API

L'application communique avec une API métier sous `/metier/...`.

Endpoints principaux :

| Usage | Méthode | Endpoint |
|---|---:|---|
| Connexion | `POST` | `/mobile/session` |
| Session utilisateur | `GET` | `/me` |
| Sites utilisateur | `GET` | `/metier/mes-sites` |
| Véhicules d'un site | `GET` | `/metier/sites/{siteId}/vehicules` |
| Réservations utilisateur | `GET` | `/metier/mes-reservations` |
| Constats utilisateur | `GET` | `/metier/mes-constats` |
| Disponibilité mensuelle | `GET` | `/metier/vehicules/{id}/disponibilites` |
| Disponibilité exacte | `GET` | `/metier/vehicules-disponibles` |
| Créer réservation | `POST` | `/metier/reservations` |
| Modifier réservation | `PATCH` | `/metier/reservations/{id}` |
| Supprimer réservation | `DELETE` | `/metier/reservations/{id}` |
| Démarrer constat | `POST` | `/metier/constats/demarrer` |
| Terminer constat | `POST` | `/metier/constats/{id}/terminer` |
| Signalement | `POST` | `/metier/signalements` |
| Upload vidéo | `POST multipart` | `/metier/videos` |
| Notifications | `GET` | `/metier/mes-notifications` |

## Règles métier importantes

### Disponibilité

Le calendrier mensuel utilise la route :

```text
GET /metier/vehicules/{id}/disponibilites?mois=YYYY-MM
```

Les jours absents de la réponse sont considérés libres.

Une réponse vide signifie donc : aucun blocage connu sur le mois.

La validation finale d'une réservation utilise ensuite la route exacte :

```text
GET /metier/vehicules-disponibles?dateDebut=...&dateFin=...
```

Cette vérification est faite avec un tampon d'une heure avant et après la réservation.

### Jours partiels

Une journée est partielle lorsqu'une réservation ne couvre pas toute la journée.

Exemple :

- réservation du 4 juin 18:00 au 7 juin 10:00 ;
- le 4 juin est partiel ;
- les 5 et 6 juin sont réservés ;
- le 7 juin est partiel.

Les jours partiels restent sélectionnables, mais les heures proposées tiennent compte des réservations voisines.

### Tampon d'une heure

La constante métier est définie dans `lib/utils/reservation_calendar_days.dart` :

```dart
const reservationTurnaroundDuration = Duration(hours: 1);
```

Exemples :

- véhicule rendu à 08:00 : prochaine prise possible à 09:00 ;
- prochain départ à 13:00 : retour précédent requis au plus tard à 12:00.

### Véhicule en usage

Un véhicule est considéré "En usage" uniquement s'il existe une réservation non historique avec :

- un constat ouvert ;
- aucun constat fermé.

Un véhicule avec constat ouvert puis constat fermé est considéré libre.

### Retour véhicule

Dès qu'un constat de départ est ouvert, le bouton `Retour` devient disponible.

Il n'y a plus de contrainte d'heure minimum pour rendre le véhicule.

### Historique

Une réservation entre dans l'historique lorsque son statut API est terminé.

Un constat fermé seul ne suffit pas à la déplacer dans l'historique.

## Tests

La suite actuelle couvre les règles critiques :

- mapping API ;
- statuts de réservation ;
- constats ouverts/fermés ;
- disponibilité mensuelle ;
- jours partiels ;
- conflits de réservation ;
- tampon d'une heure ;
- retour disponible immédiatement après départ ;
- absence de fallback jour par jour sur 404 ;
- création, modification, suppression de réservation ;
- rendu des calendriers ;
- absence d'overflow sur la liste véhicules.

Commande :

```bash
flutter test
```

À la dernière validation locale :

```text
78 tests passed
```

Analyse statique :

```bash
flutter analyze
```

Dernier résultat :

```text
No issues found
```

## Documentation technique complète

Une documentation détaillée du projet est disponible ici :

[docs/DOCUMENTATION_APP.md](docs/DOCUMENTATION_APP.md)

Elle couvre l'architecture, les modèles, les services, les écrans, les widgets, les flux métier, les règles de réservation, les endpoints API et les points de vigilance.

## Points de vigilance

- Le fichier `assets/.env.local` est embarqué comme asset Flutter : ne pas y stocker de secret critique.
- Les permissions iOS caméra/micro doivent être vérifiées avant distribution sur appareil réel ou App Store.
- Les champs API sont volontairement mappés de manière tolérante (`statut`, `statue`, `statu`, etc.) car le contrat backend peut varier.
- Les champs carburant sont validés dans l'interface pour les véhicules thermiques/hybrides, mais ne sont pas encore transmis dans les bodies de constat.
- Les cases de retour "clés remises" et "véhicule propre et branché" sont affichées mais ne bloquent pas encore la finalisation.

## Licence

Licence non définie dans le dépôt pour le moment.
