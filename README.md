# NOYA Files

**Français** · [English](README.en.md)

**Un chez-soi plus intelligent pour vos fichiers.**

NOYA Files est un gestionnaire de fichiers libre et open source, natif pour macOS, développé avec SwiftUI et AppKit.

Notre mission : rendre la gestion de fichiers plus belle, plus intuitive, plus puissante et plus efficace.

## État du projet

🚧 **En développement actif.** La première version de test, [**0.1.0**](https://github.com/elit28/NoyaFiles/releases/tag/v0.1.0), est disponible (voir [Téléchargement](#téléchargement)).

## Fonctionnalités

À chaque compilation, l'app est lancée sur macOS 15 et sur macOS 26, en français et en anglais, en thème clair et sombre, et chaque écran ci-dessous est capturé. Les cases cochées sont vérifiées de cette façon ; les autres sont codées mais restent à valider à la main sur un Mac.

- [x] Interface macOS native, thème clair ou sombre selon le système ou au choix, couleur d'accent
- [x] Affichage en grille par type, en liste et en colonnes, groupement par type ou par date
- [x] Taille de chaque dossier et panneau Analyse : ce qui occupe l'espace, suggestions de nettoyage
- [x] Navigation à double volet : copier (F5), déplacer (F6), comparer les deux dossiers
- [x] Espaces de travail et collections, avec règles intelligentes qui y rassemblent des fichiers
- [x] Recherche avancée : noms et contenu des documents, filtres, recherches enregistrées
- [x] Libérer de l'espace : gros fichiers, caches de développement, doublons, installateurs, Corbeille
- [x] Ranger les téléchargements, avec aperçu avant chaque déplacement
- [x] Outils pour développeurs : dépôts Git, branches, modifications, caches, terminal intégré
- [x] Assistant IA facultatif et local : trouver, rassembler, renommer d'après le contenu (Apple Intelligence sur macOS 26)
- [x] Premier lancement guidé : accès au disque, langue, présentation, favoris
- [x] Interface en français et en anglais
- [ ] Coup d'œil (Quick Look) avec la barre d'espace
- [ ] Annulation après la mise à la Corbeille, nouveau dossier (⇧⌘N), « Ouvrir avec »
- [ ] Avertissement à chaque nouveau téléchargement
- [ ] Mises à jour intégrées : l'app propose elle-même chaque nouvelle version (Sparkle), à partir de la 0.2.0

## Téléchargement

**[Télécharger la dernière version](https://github.com/elit28/NoyaFiles/releases/latest)** : prenez le fichier `NOYA-Files-<version>.dmg`, ouvrez-le, puis glissez **NOYA Files** dans **Applications**. L'app fonctionne sur macOS 14 Sonoma et plus récent, sur Apple silicon comme sur Intel. Une somme de contrôle SHA-256 est publiée à côté de chaque image disque.

Tant que l'app n'est pas signée avec un certificat Apple Developer ID, macOS affiche un avertissement au premier lancement. Pour l'ouvrir quand même : lancez-la une fois, puis ouvrez **Réglages Système › Confidentialité et sécurité** et cliquez sur **Ouvrir quand même**.

Pour essayer les nouveautés pas encore publiées, chaque compilation automatique produit aussi une image disque de test : ouvrez l'onglet [Actions](https://github.com/elit28/NoyaFiles/actions), choisissez la dernière exécution réussie du workflow **CI**, puis téléchargez l'artefact **NOYA-Files-macOS** (il faut être connecté à GitHub).

## Compiler depuis les sources

Prérequis : macOS 14 Sonoma ou plus récent, et Xcode 16 ou plus récent. Avec Xcode 26, l'assistant peut en plus utiliser Apple Intelligence sur les Mac sous macOS 26 ; avec Xcode 16, il se contente de règles locales.

1. Ouvrez `NoyaFiles.xcodeproj` dans Xcode.
2. Choisissez le schéma **NoyaFiles**, puis lancez l'app avec ⌘R. Les tests se lancent avec ⌘U.

En ligne de commande :

```bash
scripts/build-app.sh
```

```bash
scripts/make-dmg.sh
```

Le premier script produit `dist/NOYA Files.app`, une app universelle pour Apple silicon et Intel. Le second l'emballe dans `dist/NOYA-Files-<version>.dmg`.

## Organisation du projet

| Dossier | Contenu |
| --- | --- |
| `NoyaFiles/` | L'app SwiftUI : modèle, vues, ressources et traductions. Tout fichier ajouté ici est inclus automatiquement dans le projet Xcode. |
| `Config/` | Réglages de l'app qui ne passent pas par Xcode, comme l'adresse et la clé publique des mises à jour. |
| `Packages/NoyaCore/` | La logique indépendante de l'interface (lecture des dossiers, catégories, tailles, suggestions) et ses tests. Elle compile aussi sous Linux. |
| `scripts/` | Compilation, création du `.dmg`, vérification des traductions et, dans `scripts/ci/`, les données de démonstration et les captures automatiques. |
| `.github/workflows/` | Compilation et tests automatiques, publication des versions. |
| `Design/` | Sources graphiques, dont l'icône de l'app. |

## Publier une version

Changez le numéro de version, puis fusionnez ce changement dans `main` :

```bash
scripts/set-version.sh 0.2.0
```

Dans Xcode, c'est le champ **Version** de la cible NoyaFiles. Dès que la nouvelle version arrive sur `main`, le workflow **Release** se lance tout seul : il compile l'app, crée le `.dmg` et publie la version dans [Releases](https://github.com/elit28/NoyaFiles/releases), sans autre action. Une version déjà publiée n'est jamais reconstruite.

Le workflow se lance aussi à la main : en poussant un tag comme `v0.2.0`, ou avec **Run workflow** dans l'onglet [Actions](https://github.com/elit28/NoyaFiles/actions/workflows/release.yml).

Pour que les apps déjà installées proposent la nouvelle version, le dépôt doit avoir le secret `SPARKLE_PRIVATE_KEY` : c'est la clé qui signe chaque mise à jour, et elle doit correspondre à la clé publique `SUPublicEDKey` de `Config/Info.plist`. Le workflow signe alors le `.dmg` et joint un fichier `appcast.xml` à la version ; l'app le lit pour savoir qu'une mise à jour existe. Sans ce secret, la version est publiée sans ce fichier et seul le téléchargement manuel fonctionne.

Pour que l'app s'ouvre sans aucun avertissement, ajoutez ces secrets au dépôt : `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_ID` et `APPLE_APP_SPECIFIC_PASSWORD`. Il faut pour cela un compte Apple Developer. Le détail se trouve en tête de `.github/workflows/release.yml`.

## Technologies

- Swift 6
- SwiftUI
- AppKit
- Frameworks natifs de macOS
- [Sparkle](https://sparkle-project.org) pour les mises à jour

## Confidentialité

Tout se passe sur votre Mac : pas de compte, pas de statistiques, aucun fichier envoyé sur Internet. Seule exception, si vous le laissez activé : une fois par jour, l'app demande à GitHub si une nouvelle version existe, sans rien envoyer sur votre Mac ni vos fichiers (Réglages › Général › Mises à jour). L'assistant IA est désactivé par défaut ; une fois activé, il traite vos demandes et vos fichiers sur le Mac (Apple Intelligence quand il est disponible), propose un plan et ne change rien sans votre accord.

## Contribuer

Les contributions, les signalements de bogues et les suggestions de fonctionnalités sont les bienvenus.

## Licence

NOYA Files est distribué sous la [licence publique générale GNU (GPL), version 3 ou toute version ultérieure](LICENSE).

## Crédits

Développé par NOYA 360.

NOYA Files est un projet indépendant, sans aucun lien avec FileOS ni avec Apple.
