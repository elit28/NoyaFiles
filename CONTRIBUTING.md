# Contribuer à NOYA Files

Merci de votre intérêt pour NOYA Files ! Signalements de bugs, idées, traductions et code sont tous les bienvenus.

## Signaler un bug ou proposer une idée

[Ouvrez une issue](https://github.com/elit28/NoyaFiles/issues/new/choose) et choisissez le formulaire qui correspond. Pour un bug, indiquez la version de NOYA Files et de macOS, ce que vous avez fait, et ce qui s'est passé. Si l'app refuse de démarrer, lancez-la depuis le Terminal : le message de macOS aide beaucoup.

```bash
"/Applications/NOYA Files.app/Contents/MacOS/NOYA Files"
```

Pour une faille de sécurité, suivez plutôt [SECURITY.md](SECURITY.md).

## Préparer son Mac

- macOS 14 Sonoma ou plus récent.
- Xcode 16 ou plus récent. Avec Xcode 26, l'assistant peut aussi utiliser Apple Intelligence (FoundationModels) ; avec Xcode 16, ce code est simplement ignoré.

```bash
git clone https://github.com/elit28/NoyaFiles.git
```

Ouvrez `NoyaFiles.xcodeproj`, choisissez le schéma **NoyaFiles**, puis lancez l'app avec ⌘R et les tests avec ⌘U. Xcode télécharge Sparkle tout seul au premier lancement.

## Compiler en ligne de commande

```bash
scripts/build-app.sh
```

```bash
scripts/make-dmg.sh
```

Le premier script produit `dist/NOYA Files.app`, une app universelle (Apple silicon et Intel). Le second l'emballe dans `dist/NOYA-Files-<version>.dmg`, avec la fenêtre d'installation décrite dans `Design/dmg/`. Sans certificat, l'app est signée « ad hoc » : elle tourne sur votre Mac, et macOS demande une confirmation sur les autres.

## Tester

La logique qui ne dépend pas de l'interface vit dans le paquet `Packages/NoyaCore`, avec ses tests (Swift Testing). Ils tournent sur Mac comme sous Linux :

```bash
swift test --package-path Packages/NoyaCore
```

Ajoutez un test à chaque règle que vous changez dans NoyaCore : classement des fichiers, doublons, règles intelligentes, rangement, compréhension des demandes de l'assistant, noms proposés…

La CI vérifie bien plus que ces tests (compilation avec Xcode 16 et 26, lancement de l'app, captures de chaque écran, signatures). Le détail, et la liste des essais à faire à la main, sont dans [docs/TESTING.md](docs/TESTING.md).

## Traduire

L'interface existe en anglais et en français. Les textes sont écrits en anglais dans le code et traduits dans `NoyaFiles/Resources/Localizable.xcstrings`.

- Chaque texte visible doit avoir sa traduction française. Le script suivant le vérifie, et la CI échoue s'il manque une traduction :

  ```bash
  python3 scripts/check-localizations.py
  ```

- Pour ajouter des traductions sans ouvrir Xcode, écrivez-les dans un fichier JSON (anglais → français), puis :

  ```bash
  python3 scripts/add-translations.py traductions.json
  ```

  Dans les clés, `%@` remplace un texte et `%lld` un nombre. Pour un texte qui varie au pluriel, la valeur est une liste : `["singulier anglais", "singulier français", "pluriel français"]`.

- Évitez d'écrire `flag ? "Texte A" : "Texte B"` directement dans `Text`, `Label` ou `Button` : SwiftUI afficherait ces textes sans les traduire. Enveloppez chacun dans `LocalizedStringKey(…)`. Le script de vérification le signale.

## Écrire du code

- **Swift 6, concurrence stricte.** Les modèles d'interface sont des classes `@Observable` isolées sur le `MainActor` ; le travail lourd (lecture des dossiers, tailles, Spotlight, Git) se fait hors du fil principal, dans des fonctions `nonisolated`.
- **NoyaCore d'abord.** Toute règle qui peut se passer d'AppKit ou de SwiftUI va dans `Packages/NoyaCore`, avec ses tests.
- **Des noms clairs et des commentaires qui expliquent pourquoi**, pas ce que fait la ligne suivante.
- **Pas de nouvelle dépendance** sans en discuter d'abord dans une issue.

L'organisation du code est décrite dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Proposer une modification

1. Créez une branche à partir de `main`.
2. Faites des commits courts, avec un message en français qui dit ce que change le commit, par exemple « Corriger le tri des dossiers dans la vue en colonnes ».
3. Ouvrez une demande de fusion (pull request) et remplissez le modèle proposé.
4. Attendez que la CI soit verte. Elle publie les captures de chaque écran dans l'artefact **screenshots** : vérifiez que votre changement s'y voit comme prévu.

Pour publier une nouvelle version après la fusion, voir [docs/RELEASING.md](docs/RELEASING.md).

## Esprit du projet

Soyez bienveillant et constructif dans les issues, les relectures et les discussions. NOYA Files est un logiciel libre sous licence [GPL v3 ou ultérieure](LICENSE) : en contribuant, vous acceptez que votre contribution soit distribuée sous cette licence.
