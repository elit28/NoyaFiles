# Architecture

Comment NOYA Files est organisé, et où chercher quand on veut changer quelque chose.

## Vue d'ensemble

```
┌──────────────────────────── NoyaFiles (l'app) ─────────────────────────────┐
│  Vues SwiftUI          Views/, Settings/                                   │
│        │  lisent et modifient                                              │
│        ▼                                                                   │
│  Modèles @Observable   Model/  (WindowModel, BrowserModel, SearchModel…)   │
│        │  s'appuient sur                                                   │
│        ▼                                                                   │
│  Services du système   Spotlight, FileManager, Quick Look, Vision, PDFKit, │
│                        FoundationModels, Git, Sparkle                      │
└────────┬───────────────────────────────────────────────────────────────────┘
         │ importe
         ▼
┌──────────────── Packages/NoyaCore (logique pure, testée) ──────────────────┐
│  Lecture des dossiers, catégories, tailles, regroupements, doublons,       │
│  règles intelligentes, rangement, compréhension des demandes, noms         │
│  proposés. Sans AppKit ni SwiftUI : compile et se teste aussi sous Linux.  │
└────────────────────────────────────────────────────────────────────────────┘
```

Deux principes guident le découpage :

1. **Ce qui peut être testé sans Mac va dans NoyaCore.** Les règles (quel fichier est un installateur, quelles factures correspondent à une demande, où ranger une capture d'écran…) sont des fonctions pures, couvertes par des tests.
2. **L'interface ne fait que montrer l'état des modèles.** Les modèles sont des classes `@Observable` isolées sur le `MainActor`. Le travail lent part dans des fonctions `nonisolated`, et le résultat revient sur le fil principal.

## Le dépôt

| Dossier | Contenu |
| --- | --- |
| `NoyaFiles/App/` | Point d'entrée (`NoyaFilesApp`), menus et raccourcis (`BrowserCommands`). |
| `NoyaFiles/Model/` | Les modèles et les services : navigation, fenêtre, recherche, espaces, rangement, espace disque, développeur, assistant, mises à jour. |
| `NoyaFiles/Views/` | Les écrans, rangés par fonction : `Browser/`, `DualPane/`, `Workspaces/`, `Search/`, `Tools/`, `Insights/`, `Inspector/`, `Sidebar/`. |
| `NoyaFiles/Settings/` | La fenêtre Réglages (⌘,). |
| `NoyaFiles/Support/` | Petits outils partagés : couleurs et symboles par catégorie, formats, icônes et vignettes. |
| `NoyaFiles/Resources/` | Icône, couleur d'accent, traductions (`Localizable.xcstrings`, `InfoPlist.xcstrings`). |
| `Config/Info.plist` | Clés ajoutées à l'Info.plist généré par Xcode : adresse et clé publique des mises à jour. |
| `Packages/NoyaCore/` | La logique pure et ses tests. |
| `Design/` | Sources graphiques : icône, fenêtre d'installation. Voir [Design/README.md](../Design/README.md). |
| `scripts/` | Compilation, image disque, version, traductions. `scripts/ci/` contient ce qu'utilise la CI. |
| `.github/` | Workflows (CI et publication) et formulaires d'issues. |

Tout fichier ajouté dans `NoyaFiles/` est inclus automatiquement dans le projet Xcode (groupe synchronisé) : pas besoin de toucher au `.xcodeproj`.

## Une fenêtre

`ContentView` assemble la barre latérale (`SidebarView`) et la zone principale. Ce que montre la zone principale dépend de `WindowModel.destination` :

| Destination | Écran |
| --- | --- |
| `.browser` | `BrowserScreen`, ou `DualPaneScreen` quand le double volet est activé |
| `.workspace(id)` | `WorkspaceScreen` |
| `.search` | `SearchScreen` |
| `.tool(.freeUpSpace)` | `FreeUpSpaceScreen` |
| `.tool(.developer)` | `DeveloperScreen` |
| `.tool(.assistant)` | `AssistantScreen` |

Chaque fenêtre a son propre `WindowModel`. Les menus agissent sur la fenêtre active grâce aux `FocusedValues` (`browserModel`, `windowModel`) déclarées dans `NoyaFilesApp.swift`.

## Parcourir un dossier

- **`BrowserModel`** tient l'état d'un volet : dossier courant, historique, sélection, présentation, filtre, Coup d'œil, Corbeille avec annulation.
- La lecture du dossier passe par `DirectoryReader` (NoyaCore) dans une tâche détachée. Les tailles des sous-dossiers sont mesurées ensuite, quelques-unes à la fois (`FolderSizer`), et la barre d'état affiche la progression.
- **`NodeBuilder`** transforme les fichiers en nœuds affichables, regroupés par type ou par date (`Grouping`). Les trois vues (`FileGridView`, `FileListView`, `ColumnBrowserView`) affichent ces nœuds.
- **`DirectoryWatcher`** surveille le dossier affiché et recharge la vue quand son contenu change.
- Le panneau Analyse s'appuie sur `FolderInsights` et `CleanupAdvisor` (NoyaCore). Les doublons viennent de `DuplicateFinder`, et les installateurs déjà installés de `InstalledAppMatcher`.
- Copier et déplacer (glisser-déposer, F5 et F6) passent par **`FileOperationCenter`**, qui affiche la progression et évite d'écraser un fichier existant.

## Organiser

- **Espaces de travail** (`Workspaces.swift`) : un espace contient des entrées, c'est-à-dire des signets vers des fichiers qui restent à leur place, rangées en collections. Des règles (`RuleCondition`, dans NoyaCore) ajoutent les nouveaux fichiers qui correspondent : elles parcourent Téléchargements, Bureau et Documents toutes les 10 minutes. Le tout est enregistré dans `~/Library/Application Support/NOYA Files/workspaces.json`.
- **Recherche** (`SearchModel`) : `SearchCriteria` (NoyaCore) produit une requête Spotlight, exécutée par `NSMetadataQuery`. Les extraits de texte viennent de `SnippetMaker`. Les recherches enregistrées sont gardées dans les préférences.
- **Ranger les téléchargements** (`TidyController`, `TidySheet`) : `TidyPlanner` (NoyaCore) calcule un plan à partir des règles. L'app l'affiche, puis l'applique et garde de quoi tout annuler.
- **Libérer de l'espace** (`SpaceAnalyzer`) : gros fichiers trouvés par Spotlight, caches de développement connus, doublons, installateurs, Corbeille. Tout part à la Corbeille, jamais en suppression directe.

## Outils développeur

`DeveloperModel` liste les dossiers du dossier de projets choisi, puis lit pour chacun la branche, les modifications et le dernier commit. Il appelle `git` directement, sans passer par l'outil qui proposerait d'installer les outils Apple s'ils manquent. Il mesure aussi les caches qui se reconstruisent (`node_modules`, `.build`, `DerivedData`…). Le terminal intégré (`CommandRunner`) lance chaque commande dans `zsh -lc` et affiche la sortie au fil de l'eau.

## Assistant IA

1. `AssistantParser` (NoyaCore) comprend la demande, en français ou en anglais, sans modèle de langage : intention, type de document, année, espace de travail.
2. `AssistantModel` cherche les fichiers avec Spotlight. Si Spotlight ne trouve rien (désactivé ou index en retard), il parcourt directement Téléchargements, Documents et Bureau.
3. Pour les fichiers au nom peu clair (`FileNaming.isUnclear`), `LocalIntelligence` lit le texte : PDFKit, ou Vision pour les images et les PDF scannés. Il demande ensuite un nom au modèle d'Apple Intelligence quand il est disponible, sinon il applique `FileNaming.proposedName` (émetteur, mois et année).
4. L'assistant présente un plan. Rien ne change avant « Appliquer », et une notification permet de tout annuler.

Le code FoundationModels est entouré de `#if canImport(FoundationModels)` et `@available(macOS 26, *)`. Le framework est lié en mode faible, ce qui permet à l'app de démarrer sous macOS 14 et 15. `scripts/ci/check-weak-links.sh` le vérifie à chaque compilation.

## Mises à jour

`AppUpdater` pilote Sparkle. L'adresse du flux (`SUFeedURL`) pointe vers `appcast.xml`, joint à la dernière version GitHub. Une mise à jour n'est installée que si sa signature EdDSA correspond à `SUPublicEDKey`. Par défaut, les mises à jour se téléchargent en arrière-plan et s'installent quand on quitte l'app (`SUAutomaticallyUpdate`). La publication est décrite dans [RELEASING.md](RELEASING.md).

Quand l'app n'est pas signée avec un Developer ID, elle est construite sans « hardened runtime ». Avec lui, macOS refuserait de charger Sparkle, qui garde la signature de ses auteurs. `scripts/ci/check-library-validation.sh` vérifie à chaque compilation que l'app pourra charger ses modules.

## Préférences enregistrées

Les réglages sont dans les préférences de l'app (`com.noya360.NoyaFiles`). Les clés sont réunies dans `PreferenceKey` (`AppPreferences.swift`), à part celles du développeur (`developer.*`), du rangement (`tidy.*`) et de Sparkle (`SU…`).

Pour les captures automatiques, la CI lance l'app avec des arguments qui remplacent ces préférences le temps d'un lancement, par exemple `-noya.startDestination assistant` ou `-appearance dark`. Voir `scripts/ci/smoke-test.sh`.

## Traductions

Les textes sont écrits en anglais dans le code et traduits en français dans `Localizable.xcstrings`. SwiftUI traduit les textes littéraux passés à `Text`, `Button`, `Label`… Ailleurs, utilisez `String(localized:)`. Voir la section Traduire de [CONTRIBUTING.md](../CONTRIBUTING.md).
