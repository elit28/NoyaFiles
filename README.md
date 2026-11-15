# NOYA Files

**Français** · [English](README.en.md)

**Un chez-soi plus intelligent pour vos fichiers.**

NOYA Files est un gestionnaire de fichiers libre et open source, natif pour macOS, développé avec SwiftUI et AppKit.

Notre mission : rendre la gestion de fichiers plus belle, plus intuitive, plus puissante et plus efficace.

## État du projet

🚧 **En développement actif.** Aucune version publique stable n'est encore disponible.

## Fonctionnalités prévues

- [ ] Interface macOS native et élégante
- [ ] Affichage en liste, en grille et en colonnes
- [ ] Organisation intelligente des fichiers
- [ ] Gestion des téléchargements
- [ ] Espaces de travail et collections personnalisés
- [ ] Analyse de l'espace de stockage et outils de nettoyage
- [ ] Navigation à double volet
- [ ] Recherche avancée
- [ ] Intégration de Coup d'œil (Quick Look)
- [ ] Outils pour développeurs
- [ ] Fonctionnalités optionnelles basées sur l'IA
- [ ] Thèmes sombre et clair
- [ ] Interface en anglais et en français

Les fonctionnalités ci-dessus sont prévues ; chacune sera indiquée comme disponible une fois implémentée et testée.

## Téléchargement

Les versions officielles pour macOS seront publiées dans les [versions GitHub du projet](https://github.com/elit28/NoyaFiles/releases) dès qu'elles seront disponibles.

En attendant, chaque compilation automatique produit une image disque de test : ouvrez l'onglet [Actions](https://github.com/elit28/NoyaFiles/actions), choisissez la dernière exécution réussie du workflow **CI**, puis téléchargez l'artefact **NOYA-Files-macOS**.

Tant que l'app n'est pas signée avec un certificat Apple Developer ID, macOS affiche un avertissement au premier lancement. Pour l'ouvrir quand même : glissez **NOYA Files** dans **Applications**, lancez-la une fois, puis ouvrez **Réglages Système › Confidentialité et sécurité** et cliquez sur **Ouvrir quand même**.

## Compiler depuis les sources

Prérequis : macOS 14 Sonoma ou plus récent, et Xcode 16 ou plus récent.

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
| `Packages/NoyaCore/` | La logique indépendante de l'interface (lecture des dossiers, catégories, tailles, suggestions) et ses tests. Elle compile aussi sous Linux. |
| `scripts/` | Compilation, création du `.dmg` et vérification des traductions. |
| `.github/workflows/` | Compilation et tests automatiques, publication des versions. |
| `Design/` | Sources graphiques, dont l'icône de l'app. |

## Publier une version

Poussez un tag de version, par exemple `v0.2.0`. Le workflow **Release** compile l'app, crée le `.dmg` et prépare une version en brouillon à relire avant de la publier.

Pour que l'app s'ouvre sans aucun avertissement, ajoutez ces secrets au dépôt : `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_ID` et `APPLE_APP_SPECIFIC_PASSWORD`. Il faut pour cela un compte Apple Developer. Le détail se trouve en tête de `.github/workflows/release.yml`.

## Technologies

- Swift 6
- SwiftUI
- AppKit
- Frameworks natifs de macOS

## Confidentialité

NOYA Files privilégie le traitement local de vos fichiers et vous en laisse le contrôle.

## Contribuer

Les contributions, les signalements de bogues et les suggestions de fonctionnalités sont les bienvenus.

## Licence

NOYA Files est distribué sous la [licence publique générale GNU (GPL), version 3 ou toute version ultérieure](LICENSE).

## Crédits

Développé par NOYA 360.

NOYA Files est un projet indépendant, sans aucun lien avec FileOS ni avec Apple.
