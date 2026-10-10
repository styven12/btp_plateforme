# BTP Platform

Application Flutter de suivi de chantiers. L’application mobile ne se connecte jamais directement à MySQL : elle utilise l’API REST Express du dossier `backend/`. Le serveur est l’unique source de vérité pour les comptes, projets, demandes d’accès et journaux de chantier.

## Pré-requis

- Flutter/Dart compatible avec la version déclarée dans `pubspec.yaml`.
- Node.js 18 ou plus récent.
- MySQL 8 ou plus récent.

## Base MySQL et serveur API

1. Créer la base et les tables en exécutant `backend/schema.sql` dans MySQL.
   Pour une base existante, appliquer chaque script `backend/migrations/*.sql` dans l’ordre.
2. Dans le dossier `backend`, copier `.env.example` vers `.env`, puis renseigner l’hôte, le nom de base, l’utilisateur, son mot de passe et un secret JWT long et aléatoire. Ne jamais committer `.env`.
3. Installer les dépendances serveur avec `npm install` depuis `backend`, puis démarrer avec `npm run dev`.
4. Vérifier `http://localhost:3000/api/health` : la réponse attendue contient `status: ok` et `database: mysql`.

Pour limiter les privilèges, créez un utilisateur MySQL dédié à l’application avec accès uniquement à `btp_platform` et évitez le compte `root`.

## Application Flutter

À la racine, lancer `flutter pub get`, puis démarrer Flutter en indiquant l’URL de l’API :

- Émulateur Android : `http://10.0.2.2:3000/api` (valeur par défaut sur Android).
- Simulateur iOS : `http://127.0.0.1:3000/api`.
- Téléphone physique : utilisez l’adresse IP LAN de l’ordinateur, par exemple `http://192.168.1.20:3000/api`, et autorisez le port 3000 sur le pare-feu.

Exemple pour un téléphone physique : `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api`. `localhost` ne désigne pas l’ordinateur depuis un téléphone. Pour un déploiement, utiliser HTTPS et un domaine API public. Le trafic HTTP clair est uniquement prévu pour le développement.

### Déploiement web sur Vercel

La configuration Vercel à la racine installe Flutter 3.47.7 (canal stable) pendant le build, configure l’application pour utiliser `https://btp-plateforme-backend.onrender.com/api` et déploie `build/web`. Le script récupère le tag de version exact afin que Flutter puisse identifier correctement son numéro de version et satisfaire les contraintes SDK des dépendances. Les chemins de navigation web sont réécrits vers `index.html` pour permettre le routage de l’application.

Les builds Vercel et locaux restent indépendants : pour lancer l’application localement avec l’API locale, utilisez `flutter run` (ou `flutter run --dart-define=API_BASE_URL=http://localhost:3000/api`). Pour générer localement une version web de développement, utilisez `flutter build web --release` ; la valeur locale par défaut reste `http://localhost:3000/api`. `build.sh` est réservé au build Vercel ; vous pouvez remplacer l’URL Render pour ce script en définissant `API_BASE_URL` dans l’environnement avant de le lancer.

## Fonctionnalités implémentées

- Création de comptes client, entrepreneur (RCCM unique) et technicien ; connexion par téléphone/mot de passe.
- Mots de passe hachés côté serveur avec bcrypt, jetons JWT et routes authentifiées.
- Création de chantiers et codes d’accès uniques `BTP-XXXX`.
- Demande d’accès par client ou technicien, validation/refus par l’entrepreneur.
- Tableau de bord par profil, détails projet, journal d’avancement et avis client.
- Téléversement sécurisé des photos de chantier vers Vercel Blob.
- Réseau professionnel par rôle, statistiques des profils et demandes de travail reçues/envoyées.
- Schéma relationnel avec clés étrangères, index, contraintes et unicité des téléphones, RCCM et codes.

## Routes API principales

- `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`
- `GET /api/projects`, `POST /api/projects`, `POST /api/projects/join`
- `GET /api/projects/requests`, `PATCH /api/projects/requests/:id`
- `GET/POST /api/projects/:id/journal`, `POST /api/projects/:id/reviews`
- `GET /api/professionals`, `GET/POST /api/work-requests`, `PATCH /api/work-requests/:id`

## Utilisateur de test

inviter: Ando, password: qwerty12
mo: test, password: qwerty12 code: BTP-C79C
techicien: Styven password: qwerty12
