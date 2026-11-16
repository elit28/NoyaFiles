# Design

Les sources graphiques de NOYA Files.

| Fichier | Rôle |
| --- | --- |
| `AppIcon.svg` | L'icône de l'app : une feuille qui porte le N de NOYA 360, sur le bleu nuit de la marque. |
| `noya360-n.png` | Le N de NOYA 360, utilisé par l'icône. |
| `render-icon.js` | Dessine `docs/images/icon.png` à partir de l'icône, et toutes les tailles de l'icône de l'app avec `--icon-set`. |
| `dmg/background.html` | Le fond de la fenêtre d'installation (660 × 420 points). |
| `dmg/background.png`, `dmg/background@2x.png` | Ce fond, rendu pour les écrans normaux et Retina. |
| `dmg/render.js` | Dessine ces deux images à partir de `background.html`. |
| `dmg/settings.py` | Réglages de la fenêtre d'installation pour dmgbuild : taille, position des icônes, fond. |

## Redessiner

Les scripts utilisent [Playwright](https://playwright.dev) avec Chromium :

```bash
node Design/render-icon.js --icon-set
```

```bash
node Design/dmg/render.js
```

Si vous déplacez les cartes du fond de la fenêtre d'installation, gardez les positions des icônes de `dmg/settings.py` alignées sur `background.html` : l'app au centre de (180, 196), Applications au centre de (480, 196).

## Couleurs

| Nom | Valeur | Usage |
| --- | --- | --- |
| Bleu NOYA | `#0A3BC0` | Icône, fenêtre d'installation, badges |
| Bleu nuit | `#062061` → `#010A22` | Fond de l'icône |
| Sarcelle | `#0D9488` (clair), `#2DD4BF` (sombre) | Couleur d'accent par défaut de l'app |
