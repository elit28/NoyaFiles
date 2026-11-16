# Tests

Ce que la CI vérifie à chaque modification, et ce qu'il reste à essayer à la main avant une version importante.

## Tests automatiques

### À chaque push et à chaque demande de fusion

Le workflow **CI** (`.github/workflows/ci.yml`) lance trois jobs.

| Job | Ce qu'il vérifie |
| --- | --- |
| **Core tests (Linux)** | Les tests de NoyaCore : catégories, regroupements, tailles, doublons, règles intelligentes, rangement, recherche, compréhension des demandes de l'assistant, noms proposés, résumés. |
| **Build app (Xcode 16)** | Sur macOS 15 : traductions complètes, tests de NoyaCore, compilation, puis lancement de l'app dans chaque scénario de capture. |
| **Build app (Xcode 26)** | Sur macOS 26, la version qui est publiée : compilation, contrôles de signature, lancement dans chaque scénario, image disque, puis les tests ci-dessous. |

La CI enchaîne ces contrôles :

- **Traductions** (`scripts/check-localizations.py`) : chaque texte visible a sa traduction française, et aucun texte n'est affiché sans être traduit.
- **Signatures** (`scripts/ci/check-library-validation.sh`) : macOS pourra charger chaque module de l'app. C'est l'erreur qui empêchait les 0.2.0 et 0.2.1 de démarrer.
- **Liens** (`scripts/ci/check-weak-links.sh`) : les frameworks récents, comme FoundationModels, sont liés de façon à ce que l'app s'ouvre aussi sous macOS 14 et 15.
- **Lancement** (`scripts/ci/smoke-test.sh`) : l'app est lancée douze fois, en clair et en sombre, en français et en anglais. Chaque lancement doit tenir sans planter, et chacun produit une capture : premier lancement, grille, liste, colonnes, double volet, espace de travail, recherche, Libérer de l'espace, rangement, outils développeur, assistant. Les dossiers, projets Git, factures PDF et espaces de démonstration sont créés par `scripts/ci/make-demo-*`.
- **Image disque** (`scripts/ci/check-dmg.sh`) : la fenêtre d'installation est capturée telle que le Finder l'affiche. Une copie de l'app, marquée « téléchargée d'Internet » comme le fait un navigateur, doit démarrer.
- **Signature des mises à jour** (`scripts/ci/make-appcast.sh --self-test`) : signature et `appcast.xml` avec une clé jetable.

Les captures sont dans les artefacts **screenshots** (macOS 26) et **screenshots-macos15** de chaque exécution. L'image disque de test est dans l'artefact **NOYA-Files-macOS**.

### À chaque publication

Après chaque publication, le workflow **Release** fait un vrai test de mise à jour : il installe la version précédente, la laisse se mettre à jour toute seule, puis vérifie qu'elle est passée à la nouvelle. Voir [RELEASING.md](RELEASING.md).

### Lancer les tests sur son Mac

```bash
swift test --package-path Packages/NoyaCore
```

```bash
python3 scripts/check-localizations.py
```

```bash
scripts/build-app.sh
```

```bash
scripts/ci/smoke-test.sh
```

Sur votre Mac, `smoke-test.sh` crée ses dossiers de démonstration dans un dossier temporaire et ne touche pas à vos fichiers. Les captures sont dans `dist/screenshots`.

## Ce que la CI ne vérifie pas

Les machines de test lancent l'app et prennent des captures, mais ne cliquent sur rien. Avant une version importante, essayez ceci sur un vrai Mac, de préférence avec des copies de fichiers.

**Installation**

- [ ] Le `.dmg` s'ouvre sur la fenêtre d'installation ; le glisser vers Applications fonctionne.
- [ ] Le premier lancement passe par « Ouvrir quand même », puis les trois écrans d'accueil s'affichent.

**Navigation**

- [ ] ⌘1, ⌘2, ⌘3 changent la présentation ; double-clic pour entrer dans un dossier, ⌘[ pour revenir.
- [ ] La taille des dossiers apparaît, avec la progression dans la barre d'état.
- [ ] Espace ouvre Coup d'œil.
- [ ] Clic droit › Ouvrir avec propose les bonnes apps.

**Fichiers**

- [ ] ⇧⌘N crée un dossier.
- [ ] ⌘⌫ met à la Corbeille, et « Annuler » dans la notification remet le fichier en place.
- [ ] Glisser-déposer entre deux dossiers déplace le fichier, et copie quand il change de disque.
- [ ] Un nouveau téléchargement déclenche la notification « Nouveau téléchargement ».

**Outils**

- [ ] Double volet (⌥⌘P) : F5 copie, F6 déplace vers l'autre volet.
- [ ] Recherche (⌘F) : un mot présent dans un PDF le retrouve.
- [ ] Ranger les téléchargements (⌥⌘T) : aperçu, rangement, puis annulation.
- [ ] Libérer de l'espace : rien n'est supprimé sans confirmation, et tout part à la Corbeille.
- [ ] Espace de travail : création, ajout d'un fichier, règle intelligente.
- [ ] Outils développeur : branche et modifications justes, terminal intégré.
- [ ] Assistant IA : « Trouve mes factures », puis Appliquer et Annuler.

**Réglages et mises à jour**

- [ ] Apparence Système, Clair, Sombre ; couleur d'accent.
- [ ] NOYA Files › Rechercher les mises à jour… répond sans erreur.
