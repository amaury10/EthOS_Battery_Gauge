# Battery Indicator Widget — Ethos (FrSky)

**Date :** 2026-05-13
**Cibles matérielles :** Tandem X18/X18S (480×320), Twin X-Lite S
**Version Ethos :** 26 (dernière en date)
**Forme :** Widget Lua Ethos (pas un tool ni un script système)

---

## Objectif

Indicateur de niveau de batterie pour radio FrSky sous Ethos, basé sur la tension globale du pack (lue via la télémétrie — typiquement module multiprotocole). Affichage visuel + annonce audio périodique du pourcentage estimé.

## Périmètre

**Inclus :**
- Lecture de la tension via une source télémétrie sélectionnable par l'utilisateur
- Détection automatique du nombre de cellules (avec override manuel)
- Estimation du % via courbe de décharge réaliste (3 chimies : LiPo / LiHV / Li-Ion)
- Affichage : tension, nombre de cellules, %, jauge colorée
- Annonce audio périodique configurable (off / 5 / 10 / 15 / 30 / 60 / 120 s — défaut **30 s**)
- Layout adaptatif selon résolution écran

**Hors périmètre (YAGNI) :**
- Alarmes seuils (Ethos a déjà des alarmes télémétrie natives — pas la peine de doublonner)
- Historique / graphe (un widget ≠ une station de monitoring)
- Compensation effort moteur (sag dynamique) — trop d'hypothèses sur le setup
- Multi-pack (un seul indicateur = un seul pack)

## Architecture

Un seul plugin Ethos, structure standard :

```
/scripts/battind/
  main.lua          -- widget logic + UI
  battind.png       -- icône (optionnel, fourni si simple à générer)
```

Pas de modules séparés : la logique est compacte (~300 lignes max), un seul fichier reste plus lisible et plus simple à transférer sur la radio. Si ça dépasse, on découpe.

### Cycle de vie Ethos utilisé

| Callback        | Rôle                                                   |
|-----------------|--------------------------------------------------------|
| `create()`      | initialise l'état (config par défaut, timers)          |
| `configure(w)`  | construit le formulaire de config (UI Ethos native)    |
| `read(w)` / `write(w)` | sérialise/désérialise la config persistante      |
| `wakeup(w)`     | lit la tension, calcule cellules + %, déclenche audio  |
| `paint(w)`      | dessine l'écran (adaptatif via `lcd.getWindowSize()`)  |

## Composants logiques

### 1. Source tension
- `form.addSourceField` → l'utilisateur pique son capteur (RxBt, A1, VFR, custom multi…)
- En `wakeup`, `source:value()` lit la tension en V. Si `nil` ou 0 → état "no telemetry".

### 2. Détection cellules
**Champ choix :** `Auto | 1S | 2S | 3S | 4S | 5S | 6S | 8S | 10S | 12S`

**Algo Auto :**
1. Attendre 3 lectures consécutives (~1 s) où la tension varie de <0.1 V → tension "stable"
2. `cells = ceil(V_stable / V_max_cell)` où `V_max_cell` dépend de la chimie (4.25 LiPo, 4.40 LiHV, 4.25 Li-Ion)
3. Mémorisé en RAM pour la session (pas écrit en storage : si on change de pack, ré-détection au démarrage)
4. Si `Auto` et pas encore détecté → affichage "—S", pas d'audio

### 3. Type chimie
**Champ choix :** `LiPo | LiHV | Li-Ion` (défaut LiPo)

Courbe de décharge par cellule (% en fonction de V/cell), interpolation linéaire :

| %    | LiPo  | LiHV  | Li-Ion |
|------|-------|-------|--------|
| 100  | 4.20  | 4.35  | 4.20   |
| 90   | 4.10  | 4.25  | 4.06   |
| 80   | 4.00  | 4.15  | 3.98   |
| 70   | 3.90  | 4.05  | 3.92   |
| 60   | 3.85  | 4.00  | 3.87   |
| 50   | 3.82  | 3.97  | 3.82   |
| 40   | 3.79  | 3.94  | 3.79   |
| 30   | 3.77  | 3.92  | 3.71   |
| 20   | 3.73  | 3.88  | 3.59   |
| 10   | 3.70  | 3.85  | 3.45   |
| 0    | 3.30  | 3.30  | 2.80   |

Clamp à [0, 100]. Tables stockées en constantes Lua.

### 4. Annonce audio
- Champ choix : `Off | 5s | 10s | 15s | 30s | 60s | 120s` (défaut **30s**)
- En `wakeup` : si `os.clock() - last_announce >= period and audio_enabled and telemetry_ok`, appeler `system.playNumber(pct, UNIT_PERCENT)` et `last_announce = os.clock()`
- Pas d'annonce tant que la détection cellules n'a pas convergé
- Première annonce : décalée de la période depuis le démarrage du widget (pas immédiate, pour laisser le pack se stabiliser)

### 5. Affichage adaptatif

**Layout grand (≥ 320 px largeur) — X18 :**
```
┌──────────────────────────────┐
│  87%        4S  16.42 V      │
│  ████████████████░░░░        │
└──────────────────────────────┘
```

**Layout compact (< 320 px) — X-Lite S :**
```
┌────────────────┐
│ 87%   4S 16.4V │
│ ████████░░░    │
└────────────────┘
```

Couleurs jauge :
- Vert : ≥ 50 %
- Ambre : 20–49 %
- Rouge : < 20 %

État "no telemetry" : affichage `"— %"` et `"— V"`, jauge vide grise.

## Flux de données

```
Source télémétrie ──► wakeup() ──► lissage 3 lectures ──► cellules (auto/manuel)
                                          │
                                          ▼
                                  V/cell ──► % via table chimie ──► state
                                                                      │
                                                  ┌───────────────────┤
                                                  ▼                   ▼
                                              paint()          audio (si timer)
```

## Gestion d'erreurs / edge cases

| Cas                                          | Comportement                                    |
|----------------------------------------------|-------------------------------------------------|
| Pas de source configurée                     | Affichage "Configure source", pas d'audio       |
| Source = nil ou 0 V (pas de télémétrie)      | Affichage "—", pas d'audio                      |
| Tension < V_min × cellules détectées         | % clampé à 0, jauge rouge                       |
| Tension > V_max × cellules (charge en cours) | % clampé à 100                                  |
| Auto + tension instable >5 s                 | Reste en "—S" jusqu'à stabilisation             |
| Changement de pack en cours de session       | Re-détection si Auto + tension stable change >0.5 V/cell |

## Tests

Pas de framework de test Lua sur Ethos. Plan de test manuel :

1. **Sans télémétrie** → "—" affiché, pas de plantage, pas d'audio
2. **3S LiPo simulé à 12.6 V** → 100%, jauge verte pleine, 3 cellules auto-détectées (12.6/4.25 = 2.96 → ceil = 3) ✓
3. **3S LiPo à 11.1 V** → ~50%, jauge ambre
4. **3S LiPo à 9.9 V** → 0%, jauge rouge
5. **Audio 30s** → annonce toutes les 30s ±1s, valeur cohérente avec affichage
6. **Audio Off** → aucune annonce
7. **Override manuel 4S sur pack 3S** → % aberrant mais pas de crash
8. **X18 et X-Lite S** → layout lisible sur les deux

Pour la simulation : Ethos Suite a un simulateur PC qui permet d'injecter des valeurs télémétrie — c'est là que se feront les tests 1-6 avant de flasher la radio.

## Configuration utilisateur (UI Ethos)

Formulaire de config du widget :

```
┌──────────────────────────────────────┐
│ Voltage source     │  [RxBt      ▼] │
│ Cell count         │  [Auto      ▼] │
│ Battery chemistry  │  [LiPo      ▼] │
│ Audio period       │  [30 s      ▼] │
└──────────────────────────────────────┘
```

## Persistance

Sérialisée via `read(w)` / `write(w)` :
- Source télémétrie (référence)
- Cellules : "Auto" ou nombre
- Chimie : "LiPo" / "LiHV" / "Li-Ion"
- Période audio en secondes (0 = off)

## Risques / inconnues

1. **API Ethos exacte** — je code d'après la doc Ethos 26. Si certaines signatures de l'API Lua diffèrent à l'usage, prévoir un petit cycle d'ajustement à l'installation.
2. **Comportement audio sur X-Lite S** — la radio a un petit haut-parleur, le débit audio est OK mais le delay entre `playNumber()` peut varier. Pas critique mais à vérifier.
3. **Source télémétrie en mode simulateur** — on devra peut-être créer manuellement une source factice dans le simulateur pour tester.

## Livrables

- `scripts/battind/main.lua` — code du widget
- `scripts/battind/icon.png` (optionnel) — icône 32×32 ou laissée à l'icône par défaut
- `README.md` à la racine — installation (copier dans `/scripts/` de la carte SD), config, dépannage
