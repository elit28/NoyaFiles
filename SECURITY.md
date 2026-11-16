# Sécurité

## Signaler une faille

Si vous pensez avoir trouvé une faille de sécurité dans NOYA Files, **ne l'exposez pas dans une issue publique**.

Signalez-la en privé depuis l'onglet **Security** du dépôt, avec **Report a vulnerability**. Si ce bouton n'apparaît pas, ouvrez une issue qui demande simplement un moyen de contact privé, sans aucun détail sur la faille.

Décrivez ce que vous avez trouvé, la version de NOYA Files et de macOS, et si possible les étapes pour reproduire le problème. Vous recevrez une réponse dès que possible, et la correction sera publiée dans une nouvelle version, avec votre accord pour vous citer.

## Versions suivies

Seule la dernière version publiée reçoit des corrections. Les apps installées se mettent à jour d'elles-mêmes ; sinon, téléchargez la dernière version depuis la [page des versions](https://github.com/elit28/NoyaFiles/releases/latest).

## Points sensibles

- **Les mises à jour** sont signées avec une clé EdDSA. L'app refuse tout fichier dont la signature ne correspond pas à la clé publique intégrée (`Config/Info.plist`). La clé privée n'est jamais dans le dépôt ; elle vit uniquement dans les secrets GitHub.
- **Les fichiers ne quittent pas le Mac.** L'app ne se connecte qu'à GitHub, pour vérifier les mises à jour, et l'assistant IA travaille sur le Mac.
- **Les suppressions passent par la Corbeille.** Seul « Vider la Corbeille » supprime pour de bon, après confirmation.
