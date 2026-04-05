# GPhone Addon (Garry's Mod)

Addon complet de téléphone in-game avec:

- Appels entre joueurs (SteamID64)
- Messages texte
- Capture photo (screenshot JPEG) et envoi par message
- UI DHTML (HTML/CSS/JS) reliée à Lua

## Installation

1. Copier le dossier dans `garrysmod/addons/gphone_addon`.
2. Vérifier que les chemins existent:
   - `lua/autorun/sh_gphone.lua`
   - `lua/autorun/server/sv_gphone.lua`
   - `lua/autorun/client/cl_gphone.lua`
   - `html/gphone/index.html`
3. Redémarrer le serveur.

## Utilisation

- Côté client:
  - Tape `!phone` dans le chat, ou
  - Ouvre la console et tape `gphone_open`.
- Renseigne le SteamID64 du joueur cible.
- Utilise les boutons pour:
  - envoyer un message,
  - capturer/envoyer une photo,
  - appeler/raccrocher.

## Notes

- Les photos sont limitées à 60 KB pour éviter de saturer `net`.
- Les appels gèrent les états: incoming/outgoing/connected/declined/ended/no_answer.
- Un anti-spam simple est inclus côté serveur.
