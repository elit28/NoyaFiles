# Publier une version

Une nouvelle version se publie en changeant son numéro sur `main`. Tout le reste est automatique : compilation, image disque, signature de la mise à jour, publication, puis test de mise à jour sur une vraie machine.

## En bref

1. Sur une branche, changez la version :

   ```bash
   scripts/set-version.sh 0.3.0
   ```

2. Ajoutez une section à [CHANGELOG.md](../CHANGELOG.md).
3. Ouvrez une demande de fusion vers `main`, attendez que la CI soit verte, puis fusionnez.

Le workflow **Release** démarre aussitôt. Une dizaine de minutes plus tard, la version est en ligne dans [Releases](https://github.com/elit28/NoyaFiles/releases), et les apps installées la proposent, puis l'installent quand on les quitte.

## Numéros de version

- `MAJEUR.MINEUR.CORRECTIF`, par exemple `0.3.0`. Une correction seule augmente le dernier chiffre.
- Un suffixe comme `0.3.0-beta.1` publie une préversion. Elle n'est pas proposée en mise à jour, car le flux suit la dernière version stable.
- La version vit dans `MARKETING_VERSION` du projet Xcode (champ **Version** de la cible NoyaFiles). `scripts/set-version.sh` change les configurations Debug et Release d'un coup.
- Le numéro de build est fixé par le workflow : `0.3.0.<numéro d'exécution>`. Il augmente toujours, ce qui permet à Sparkle de savoir quelle version est la plus récente.

## Ce que fait le workflow Release

Le workflow (`.github/workflows/release.yml`) se lance quand le projet Xcode change sur `main`, quand on pousse un tag `v*`, ou à la main depuis l'onglet Actions (**Run workflow**). Il enchaîne trois jobs.

1. **Check the version.** Il lit la version du projet (`scripts/ci/release-version.sh`). Si un tag ou une version, même en brouillon, existe déjà pour ce numéro, il s'arrête là : une version n'est jamais publiée deux fois. Un tag poussé ou un **Run workflow** construisent toujours.
2. **Build, sign and publish**, sur une machine macOS 26 avec Xcode 26 :
   - traductions vérifiées, tests de NoyaCore, compilation universelle ;
   - contrôles de signature et de liens ;
   - image disque avec sa fenêtre d'installation ;
   - signature de la mise à jour et `appcast.xml` (`scripts/ci/make-appcast.sh`) ;
   - copie `NOYA-Files.dmg` pour le lien permanent ;
   - publication de la version, avec ses notes générées à partir des demandes de fusion.
3. **Check that installed apps update themselves.** Il installe la version précédente sur une machine de test, la laisse trouver, télécharger et installer la nouvelle, puis vérifie le numéro de version obtenu (`scripts/ci/check-update.sh`).

Chaque version publie :

| Fichier | Rôle |
| --- | --- |
| `NOYA-Files-<version>.dmg` | L'image disque de cette version |
| `NOYA-Files-<version>.dmg.sha256` | Sa somme de contrôle |
| `NOYA-Files.dmg` | La même image sous un nom fixe, pour le lien de téléchargement permanent |
| `appcast.xml` | Le flux que lisent les apps installées pour se mettre à jour |

Le README pointe vers `releases/latest/download/NOYA-Files.dmg`, et les apps vers `releases/latest/download/appcast.xml` : ces deux adresses suivent toujours la dernière version.

## Secrets du dépôt

Ils se règlent dans **Settings › Secrets and variables › Actions** sur GitHub.

| Secret | Obligatoire | Rôle |
| --- | --- | --- |
| `SPARKLE_PRIVATE_KEY` | Oui, pour les mises à jour | Clé privée qui signe chaque mise à jour. Elle doit correspondre à `SUPublicEDKey` dans `Config/Info.plist`. Sans elle, la version est publiée sans `appcast.xml`, et les apps installées ne la voient pas. |
| `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID` | Non | Certificat Developer ID (compte Apple Developer). L'app est alors signée à votre nom. |
| `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD` | Non | Notarisation par Apple. Avec le certificat, l'app s'ouvre sans aucun avertissement. |

### La clé des mises à jour

- **Ne la perdez pas.** Les apps installées n'acceptent que les mises à jour signées par cette clé. Gardez-en une copie dans un gestionnaire de mots de passe, en plus du secret GitHub.
- **Ne la mettez jamais dans le dépôt.** Le workflow vérifie qu'elle correspond à la clé publique de l'app avant de signer (`scripts/ci/ed25519-sign.swift`).
- Pour changer de clé, publiez d'abord une version qui contient la nouvelle clé publique, signée avec l'ancienne. Ce n'est qu'ensuite que vous changez le secret. Si la clé est perdue, chacun devra réinstaller l'app à la main.

### Signer avec un Developer ID

Sans certificat, l'app est signée « ad hoc » et construite sans *hardened runtime*. macOS demande alors une confirmation au premier lancement (Réglages Système › Confidentialité et sécurité › Ouvrir quand même).

Avec les secrets du certificat, `scripts/build-app.sh` signe l'app et chaque partie de Sparkle avec votre identité, et active le *hardened runtime*. `scripts/make-dmg.sh` fait ensuite notariser l'image disque par Apple. Le contrôle `scripts/ci/check-library-validation.sh` vérifie que tout est signé par la même équipe.

## En cas de problème

- **Le workflow s'arrête après « Check the version ».** Cette version existe déjà. Augmentez le numéro, ou supprimez la version et son tag sur GitHub si elle était ratée.
- **Avertissement « No update feed ».** Le secret `SPARKLE_PRIVATE_KEY` manque. La version est publiée, mais les apps installées ne la verront pas : ajoutez le secret, puis publiez une nouvelle version.
- **« does not match the app's SUPublicEDKey ».** Le secret ne correspond pas à la clé publique de l'app. Ne changez pas la clé publique : vérifiez le contenu du secret.
- **Le test de mise à jour échoue.** La version est déjà publiée. Le journal du job montre les messages de Sparkle ; corrigez, puis publiez une version suivante.
