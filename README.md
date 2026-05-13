# BattInd — Battery Indicator Widget for FrSky Ethos

Widget Ethos affichant le niveau d'une batterie à partir d'une source télémétrie de tension, avec annonce audio périodique configurable.

Compatible **Ethos 26+**. Conçu pour Tandem X18/X18S et Twin X-Lite S (layout adaptatif), portable sur autres radios Ethos.

---

## Installation

1. Sur la carte SD de la radio, créer (s'il n'existe pas) le dossier `/scripts/`.
2. Copier le dossier `scripts/battind/` (avec ses 3 fichiers `.lua`) dans `/scripts/` de la SD.

   Arborescence finale sur la SD :
   ```
   /scripts/battind/main.lua
   /scripts/battind/chemistry.lua
   /scripts/battind/cells.lua
   ```

3. Insérer la SD, démarrer la radio.
4. Sur un écran principal, **longue-presse une zone vide** → **Add widget** → **Battery Indicator**.

## Configuration

Une fois le widget ajouté, entrer en config (long-press dessus → Settings) :

| Champ                | Description                                                                 | Défaut |
|----------------------|-----------------------------------------------------------------------------|--------|
| **Voltage source**   | Capteur télémétrie de tension globale (RxBt, A1, VFR, sensor custom du module multiprotocole…) | —     |
| **Cell count**       | `Auto` (détection automatique) ou nombre fixe : 1S / 2S / 3S / 4S / 5S / 6S / 8S / 10S / 12S | Auto   |
| **Battery chemistry**| `LiPo` (3.30–4.20 V/cell) / `LiHV` (3.30–4.35 V/cell) / `Li-Ion` (2.80–4.20 V/cell) | LiPo   |
| **Audio period**     | Intervalle entre annonces vocales du pourcentage : Off / 5 s / 10 s / 15 s / 30 s / 60 s / 120 s | 30 s   |

### Détection automatique du nombre de cellules

En `Auto`, le widget attend 3 lectures consécutives de tension avec une variation inférieure à 0,1 V (≈ 1 s), puis calcule :

```
cellules = ceil(V_moyen / V_max_par_cellule)
```

où `V_max_par_cellule` dépend de la chimie choisie (4,25 V pour LiPo et Li-Ion, 4,40 V pour LiHV).

Une fois le pack détecté, un changement de pack (tension par cellule différente de plus de 0,5 V) déclenche une re-détection. Un sag normal en vol (chute < 0,5 V/cellule) ne déclenche pas de re-détection.

### Estimation du pourcentage

Le widget utilise une **table d'interpolation par chimie** (11 points), bien plus juste qu'une rampe linéaire entre tension min et max. Exemple : à 50 % d'une LiPo, on est à **3,82 V/cellule**, pas à mi-chemin entre 3,30 V et 4,20 V.

### Annonce audio

La première annonce est différée d'une période complète après le boot du widget (laisse le pack se stabiliser). Pas d'annonce tant que la détection de cellules n'a pas convergé ou si la télémétrie est absente.

## Affichage

- **Grand écran (≥ 320 px, X18/X20) :** pourcentage en gros à gauche, tension et nombre de cellules à droite, jauge horizontale colorée en bas.
- **Écran compact (< 320 px, X-Lite S) :** tout sur une ligne en haut, jauge en bas.

Couleurs de la jauge :
- 🟢 Vert : ≥ 50 %
- 🟠 Ambre : 20–49 %
- 🔴 Rouge : < 20 %

## Dépannage

| Symptôme                                  | Cause probable                                | Remède                                         |
|-------------------------------------------|-----------------------------------------------|------------------------------------------------|
| `-- %` en permanence                      | Source non configurée ou pas de télémétrie    | Vérifier la source dans la config, et que le récepteur est lié |
| `--S` en mode Auto, indéfiniment          | Tension instable au branchement (vol en cours) | Brancher le pack au repos pour la première détection |
| Cellules détectées fausses                | Pack très déchargé au branchement initial     | Forcer manuellement le nombre de cellules en config |
| Audio jamais déclenchée                   | Audio period = Off, ou pas de télémétrie      | Mettre une période > 0 ; vérifier la source    |
| Audio déclenchée immédiatement au démarrage | (Ne devrait pas arriver — la première annonce est différée d'une période) | Vérifier la version du widget |
| Widget ne s'affiche pas dans le picker    | Fichiers `.lua` mal copiés                    | Vérifier que les 3 fichiers sont dans `/scripts/battind/` sur la SD |

## Développement (tests unitaires)

La logique pure (chimie, détection de cellules) est testée en TDD avec Lua vanille :

```powershell
cd J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge
lua tests/test_chemistry.lua
lua tests/test_cells.lua
```

Nécessite Lua 5.4 (ou ≥ 5.3) dans le PATH. Sur Windows :

```powershell
winget install -e --id DEVCOM.Lua
```

Le widget lui-même (intégration Ethos) se teste dans le **simulateur Ethos Suite** ou directement sur la radio.

## Structure du projet

```
EthOS_Battery_Gauge/
├── scripts/battind/
│   ├── main.lua        Widget glue Ethos (registration, paint, wakeup, configure)
│   ├── chemistry.lua   Tables de décharge + interpolation V/cell → %
│   └── cells.lua       Détection automatique du nombre de cellules
├── tests/
│   ├── helpers.lua
│   ├── test_chemistry.lua
│   └── test_cells.lua
└── docs/superpowers/   Spec et plan d'implémentation
```

## Licence

À définir.
