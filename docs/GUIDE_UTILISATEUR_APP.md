# Guide utilisateur de l’application Wheello

Dernière mise à jour : 29 juin 2026.

Ce guide explique l’utilisation de l’application mobile Wheello pour les utilisateurs.

## Accès au guide dans l’application

Le guide complet est disponible depuis :

```text
Profil > Guide d’utilisation
```

Chaque grande page contient aussi une icône `?` qui affiche une aide courte adaptée à l’écran courant.

## Connexion

L’utilisateur se connecte avec son e-mail professionnel ou son identifiant prévu par l’organisation.

Le mot de passe technique est géré automatiquement côté serveur. Il n’est pas demandé à l’utilisateur.

La session mobile est protégée par un JWT stocké dans `flutter_secure_storage`.

## Accueil

L’accueil permet de choisir le bon parcours :

- départ immédiat ;
- réservation classique ;
- consultation des réservations ;
- notifications ;
- profil.

Si une action n’apparaît pas, cela signifie généralement qu’elle n’est pas disponible dans la situation actuelle.

## Véhicules

La page véhicules permet de :

- consulter les véhicules accessibles ;
- filtrer ou rechercher un véhicule ;
- ouvrir le détail d’un véhicule ;
- vérifier les disponibilités ;
- démarrer une réservation classique.

Un véhicule en maintenance, déjà réservé ou indisponible ne doit pas être proposé comme disponible.

## Réservation classique

Pour réserver :

1. Choisir un véhicule.
2. Choisir la date et les horaires.
3. Vérifier les disponibilités affichées.
4. Valider la réservation.

L’application applique les règles de conflit et le tampon d’une heure entre deux réservations du même véhicule.

## Départ immédiat

Le départ immédiat sert uniquement si l’utilisateur prend un véhicule maintenant.

Le parcours :

1. choisir le site ;
2. choisir un véhicule disponible ;
3. indiquer le retour prévu ;
4. valider.

La validation crée la réservation et démarre le trajet.

## Départ et retour

Au départ, l’utilisateur confirme le début du trajet et le kilométrage.

Au retour, l’utilisateur renseigne le kilométrage final et valide le retour. Le véhicule est alors libéré si le retour est accepté.

## Signalement

Un signalement sert à déclarer une anomalie liée au véhicule.

À respecter :

- décrire uniquement le problème du véhicule ;
- éviter les données personnelles ;
- ajouter une photo ou vidéo seulement si elle est utile ;
- ne pas filmer de personne identifiable sans nécessité.

## Notifications

Les notifications indiquent les événements utiles :

- rappel de départ ;
- rappel de retour ;
- réservation supprimée ou modifiée ;
- mise à jour de l’application disponible.

Les notifications locales doivent être autorisées dans l’application et dans les réglages du téléphone.

## Données personnelles

La page est disponible depuis :

```text
Profil > Données personnelles
```

Elle explique :

- qui traite les données ;
- pourquoi elles sont utilisées ;
- quelles données sont concernées ;
- combien de temps elles sont conservées ;
- qui peut y accéder ;
- comment exercer ses droits.

## Déconnexion

La déconnexion ferme la session côté application et demande au serveur de libérer la session mobile.

Si la session est libérée par un administrateur, l’utilisateur devra se reconnecter.

## En cas de problème

Si l’application indique que l’API est indisponible, le message attendu est :

```text
Nous sommes en maintenance, veuillez nous excuser
```

Si une information de compte, de site ou de véhicule semble incorrecte, contacter un administrateur Wheello.
