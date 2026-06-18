# Tests Flutter

Le projet Flutter utilise plusieurs niveaux de tests.

## Outils

- `flutter_test` : tests unitaires et tests widgets.
- `mocktail` : mocks propres pour isoler les appels API et services.
- `golden_toolkit` : golden tests visuels.
- `integration_test` : parcours complets plus proches d'un vrai appareil.

## Installer les dépendances

```bash
flutter pub get
```

Si Flutter n'est pas dans le `PATH`, utiliser le SDK local :

```bash
/Users/raphael/dart-sdk/flutter/flutter/bin/flutter pub get
```

## Lancer les tests unitaires et widgets

```bash
flutter test
```

Avec le SDK local :

```bash
/Users/raphael/dart-sdk/flutter/flutter/bin/flutter test
```

## Générer la couverture

```bash
flutter test --coverage
```

Le rapport brut est créé ici :

```text
coverage/lcov.info
```

## Générer un rapport machine

Un script local est disponible :

```bash
FLUTTER_BIN=/Users/raphael/dart-sdk/flutter/flutter/bin/flutter bash tool/test_flutter.sh
```

Il lance :

- `flutter analyze` ;
- `flutter test --coverage` ;
- un rapport machine dans `test_reports/flutter-tests.json`.

`coverage/` et `test_reports/` sont ignorés par Git.

## Golden tests

Un golden test compare l'UI actuelle avec une image de référence.

Golden test actuellement ajouté :

```text
test/goldens/availability_calendar_golden_test.dart
```

Il verrouille le rendu du calendrier de disponibilité avec les états libre, partiel, réservé, maintenance, indisponibilité utilisateur et jours passés désactivés.

Pour générer ou mettre à jour volontairement les images de référence :

```bash
flutter test --update-goldens test/goldens
```

Ne pas utiliser `--update-goldens` pour corriger un test rouge sans vérifier visuellement le changement. Cette commande accepte le nouveau design comme référence.

## Tests d'intégration

Un premier smoke test existe :

```text
integration_test/app_smoke_test.dart
```

Il vérifie que l'application démarre jusqu'à l'écran de connexion mobile.

Commande :

```bash
flutter test integration_test
```

## Tests API mockés

Test mocktail actuellement ajouté :

```text
test/api_client_mocktail_test.dart
```

Il vérifie que l'`ApiClient` injecte correctement le token Bearer stocké dans la session.

## Tests prioritaires à ajouter ensuite

- bouton Départ si `demarre = false` ;
- bouton Retour si `demarre = true` et `termine = false` ;
- historique si `termine = true` ;
- signalement sans vidéo accepté ;
- bouton Envoyer bloqué pendant la préparation vidéo ;
- compression vidéo appelée avant l'upload ;
- erreur API affichée proprement ;
- golden tests sur `VehicleCard`, `BookingsScreen`, `VehicleDetailScreen`, `ReportIssueScreen` et `NotificationsScreen`.
