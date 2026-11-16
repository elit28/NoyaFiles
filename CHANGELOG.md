# Journal des modifications

Toutes les évolutions notables de NOYA Files, de la plus récente à la plus ancienne. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et les numéros de version suivent [la gestion sémantique de version](https://semver.org/lang/fr/).

## [0.2.4] — 2026-11-16

### Ajouté

- Lien de téléchargement permanent : chaque version publie aussi `NOYA-Files.dmg`, et [ce lien](https://github.com/elit28/NoyaFiles/releases/latest/download/NOYA-Files.dmg) donne toujours la dernière version.
- Documentation complète : README avec captures, guide d'installation, questions fréquentes, guide de contribution, architecture, publication et tests.
- Formulaires pour signaler un bug ou proposer une idée, et modèle de demande de fusion.

### Modifié

- Captures de la CI prises dans de vrais dossiers (Téléchargements, `~/Developer`) plutôt que dans des dossiers temporaires.

L'app elle-même ne change pas par rapport à la 0.2.3.

## [0.2.3] — 2026-11-16

### Corrigé

- La fenêtre d'installation montre son fond en entier : la ligne du bas était coupée par la barre de titre.

## [0.2.2] — 2026-11-16

### Corrigé

- L'app démarre à nouveau sur les Mac récents (macOS 27). Elle s'arrêtait au lancement, car macOS refusait de charger le module de mise à jour, signé par une autre équipe que l'app.

### Ajouté

- Nouvelle fenêtre d'installation : fond aux couleurs de NOYA 360, flèche vers Applications et consigne d'installation.
- Contrôles automatiques : la compilation échoue si macOS risquait de refuser un module de l'app, et une copie de l'app marquée « téléchargée d'Internet » doit démarrer.

## [0.2.1] — 2026-11-16

### Ajouté

- Les mises à jour s'installent toutes seules : téléchargées en arrière-plan, installées quand vous quittez l'app. Réglage « Installer les mises à jour automatiquement » pour être prévenu avant.
- Après chaque publication, une machine de test installe la version précédente et vérifie qu'elle se met à jour toute seule.

### Problème connu

- Ne démarre pas sur macOS 27 ; corrigé dans la 0.2.2.

## [0.2.0] — 2026-11-16

### Ajouté

- Mises à jour intégrées (Sparkle) : vérification quotidienne, menu « Rechercher les mises à jour… » et réglages. Chaque mise à jour est signée et vérifiée avant installation.

### Problème connu

- Ne démarre pas sur macOS 27 ; corrigé dans la 0.2.2.

## [0.1.0] — 2026-11-16

Première version de test.

### Ajouté

- Navigation en grille par type, liste et colonnes, taille de chaque dossier, panneau Analyse, infos du fichier et Coup d'œil.
- Double volet avec copie (F5), déplacement (F6) et comparaison.
- Espaces de travail, collections et règles intelligentes.
- Recherche avancée dans les noms et le contenu, avec filtres et recherches enregistrées.
- Rangement des téléchargements avec aperçu et annulation.
- Libérer de l'espace : gros fichiers, caches de développement, doublons, installateurs, Corbeille.
- Outils développeur : dépôts Git, caches, terminal intégré.
- Assistant IA facultatif et local, avec Apple Intelligence sous macOS 26.
- Premier lancement en trois étapes, notifications avec annulation, nouveau dossier, « Ouvrir avec ».
- Thème clair ou sombre, couleur d'accent, interface en français et en anglais.

[0.2.4]: https://github.com/elit28/NoyaFiles/releases/tag/v0.2.4
[0.2.3]: https://github.com/elit28/NoyaFiles/releases/tag/v0.2.3
[0.2.2]: https://github.com/elit28/NoyaFiles/releases/tag/v0.2.2
[0.2.1]: https://github.com/elit28/NoyaFiles/releases/tag/v0.2.1
[0.2.0]: https://github.com/elit28/NoyaFiles/releases/tag/v0.2.0
[0.1.0]: https://github.com/elit28/NoyaFiles/releases/tag/v0.1.0
