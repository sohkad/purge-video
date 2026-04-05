# iPhone "style iOS 26" pour serveur Garry's Mod

Ce document propose une architecture **réaliste** pour créer un téléphone in-game dans Garry’s Mod avec:

- interface inspirée d’iOS,
- appels entre joueurs,
- SMS/messages,
- prise de photo,
- envoi de photo par message.

## 1) Attention légale (important)

Reprendre "exactement" les logos Apple/iOS est risqué (marques, propriété intellectuelle).
Pour éviter les problèmes:

- crée des icônes **originales** au style proche,
- change les noms des apps (ex: "Messages" -> "Chat"),
- évite le logo Apple officiel.

## 2) Stack conseillée

- **UI**: DHTML (HTML/CSS/JS) dans Garry’s Mod.
- **Gameplay/serveur**: Lua (client + serveur).
- **Transport réseau**: `net.Start` / `net.Receive`.
- **Données persistantes**: SQLite (`sql.Query`) ou MySQL (mysqloo/ttt2-lib).
- **Audio appel**: système VoIP de GMod (canaux + logique d'appel en Lua).

## 3) Architecture globale

### Côté client (Lua)

- Ouvre un `DFrame` qui contient un `DHTML` fullscreen "smartphone".
- Charge une page locale `asset://garrysmod/html/phone/index.html`.
- Reçoit les actions JS (`console.log` + `DHTML:AddFunction` / `OnCallback`) et les traduit en `net`.
- Reçoit les événements serveur (nouveau message, appel entrant, photo reçue) et met à jour la page JS via `QueueJavascript`.

### Côté UI (HTML/JS)

- Écran d’accueil + apps (Téléphone, Messages, Appareil photo, Galerie).
- Un pont JS -> Lua pour:
  - composer un numéro,
  - envoyer un texte,
  - prendre/choisir une photo,
  - envoyer une photo.
- Un pont Lua -> JS pour afficher:
  - liste des conversations,
  - messages live,
  - état d’appel (ringing, connected, ended),
  - miniatures photos.

### Côté serveur (Lua)

- Validation stricte de toutes les entrées.
- Routage des messages vers le bon joueur.
- Stockage des messages/photos (métadonnées + lien).
- Gestion des états d’appel:
  - `idle` -> `ringing` -> `connected` -> `ended`.

## 4) Flux "envoyer photo par message"

1. Joueur A ouvre Messages.
2. Clique "joindre photo".
3. Côté client, photo capturée ou sélectionnée.
4. Encodage (base64 ou upload HTTP vers backend).
5. Envoi au serveur via net (ou URL si upload externe).
6. Serveur valide taille/type, stocke référence.
7. Serveur push au joueur B.
8. Client B reçoit l’événement et affiche la photo dans le fil.

## 5) Recommandation importante pour les photos

**Évite d’envoyer des grosses images brutes dans `net`** (risque de lag + limites).

Approche robuste:

- faire un screenshot côté client,
- compresser/redimensionner,
- upload HTTP vers un stockage (S3/minio/API web),
- envoyer seulement une URL + métadonnées via `net`.

## 6) Squelette minimal (Lua)

```lua
-- shared.lua
util.AddNetworkString("phone_send_message")
util.AddNetworkString("phone_incoming_message")
util.AddNetworkString("phone_call_request")
util.AddNetworkString("phone_call_state")

-- server.lua
net.Receive("phone_send_message", function(_, ply)
  local toSteamID64 = net.ReadString()
  local msgType = net.ReadString() -- "text" | "image"
  local payload = net.ReadString() -- texte ou URL

  if #payload > 4096 then return end -- garde-fou
  -- TODO: valider destinataire + permissions + anti-spam

  local target = player.GetBySteamID64(toSteamID64)
  if not IsValid(target) then return end

  net.Start("phone_incoming_message")
    net.WriteString(ply:SteamID64())
    net.WriteString(msgType)
    net.WriteString(payload)
  net.Send(target)
end)
```

## 7) Squelette minimal (DHTML/JS)

```html
<script>
function sendText(to, text) {
  // pont JS->Lua: selon ton binding DHTML
  console.log(JSON.stringify({ action: "send_text", to, text }));
}

function sendImage(to, imageUrl) {
  console.log(JSON.stringify({ action: "send_image", to, imageUrl }));
}

function onIncomingMessage(from, type, payload) {
  // rendu UI
}
</script>
```

## 8) Appels vocaux

- Tu peux simuler un "appel" avec un état Lua + sonnerie UI.
- Une fois "accepté", utilise la proximité/route vocale serveur selon ton mode.
- Ajoute des timeouts:
  - no answer (30s),
  - joueur déco,
  - busy state.

## 9) Sécurité & anti-abus

- Rate limit des messages et appels.
- Taille max image (ex 500 KB).
- Whitelist de formats (`jpg`, `png`, `webp`).
- Journalisation minimale (qui envoie à qui).
- Option admin: mute téléphone / blocage.

## 10) Plan de production en 4 phases

1. **MVP UI**: home + app Messages avec texte seulement.
2. **Call System**: demande d’appel, décrocher/raccrocher.
3. **Photos**: capture + upload + affichage dans messages.
4. **Polish**: animations, contacts, notifications, batterie fictive, lock screen.

## 11) Réponse directe à ta question

Oui: ton idée est bonne.

- Interface en **HTML/CSS/JS (DHTML)**,
- logique gameplay et réseau en **Lua**,
- pont entre les deux pour envoyer actions/événements,
- et pour les photos, privilégie **URL + stockage externe** plutôt que de gros blobs via net.

