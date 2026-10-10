# Steal a Rift

Jeu Roblox inspiré de *Steal a Brainrot*, revisité autour de portails dimensionnels.
Au centre de la map, une faille géante (la **Rift**) libère des créatures qui suivent un
chemin circulaire. Les joueurs les achètent, les installent dans leur base pour générer de
l'argent, et volent celles des autres.

---

## Démarrage rapide (2 options)

### Option A : ouvrir le fichier de place (le plus simple)

1. Télécharge **`StealARift.rbxl`** (à la racine du dépôt).
2. Double-clique dessus : Roblox Studio l'ouvre. La map (Rift, chemin, 8 bases) est déjà
   construite et visible.
3. Clique sur **Play** (F5). Tu apparais dans ta base, les créatures sortent de la Rift.
4. Pour tester à plusieurs : onglet **Test** > **Clients and Servers** > 2 ou 3 joueurs >
   **Start** (indispensable pour tester le vol).

> Sans réglage, les données sont stockées **en mémoire** (perdues à l'arrêt) et la console
> l'indique. Pour la vraie sauvegarde : publie la place (File > Publish to Roblox), puis
> **Game Settings > Security > Enable Studio Access to API Services**.

### Option B : workflow Rojo (pour développer)

```bash
rokit install                 # ou installe Rojo 7.4+ manuellement
rojo serve                    # puis, dans Studio : plugin Rojo > Connect
```

Avec Rojo, la map n'existe pas dans le fichier : `MapService` la génère automatiquement au
lancement (Play). Pour régénérer le `.rbxl` complet (scripts + map pré-construite) :

```bash
rojo build default.project.json -o build/rojo.rbxl
lune run scripts/build-place.luau build/rojo.rbxl StealARift.rbxl
```

---

## Arborescence

```
default.project.json          Projet Rojo
StealARift.rbxl               Place prête à ouvrir (scripts + map)
scripts/build-place.luau      Construit StealARift.rbxl (Lune)
docs/MAP_BUILD.md             Construire / personnaliser la map dans Studio

src/shared/   -> ReplicatedStorage.Shared
  Config/
    GameConfig.luau           TOUS les réglages d'équilibrage (timers, coûts, limites...)
    Creatures.luau            40 créatures (8 par dimension)
    Dimensions.luau           5 dimensions (Lave, Néant, Glace, Bonbon, Cyber)
    Rarities.luau             6 raretés (Commun -> Secret)
    Mutations.luau            Mutations de fusion (x2 à x5)
    Upgrades.luau             Améliorations de base
    Monetization.luau         Ids des gamepasses / produits (à remplir)
  Modules/
    Economy.luau              Calculs purs (revenus, emplacements, coûts...)
    Odds.luau                 Probabilités d'apparition (tirage + affichage)
    PathMath.luau             Position sur le chemin (serveur ET client)
    CreatureVisuals.luau      Modèles de créatures (procéduraux ou vos assets)
    Remotes.luau              Liste des RemoteFunctions / RemoteEvents
    Format, Signal, LeaderboardCodec

src/server/   -> ServerScriptService.Server
  Main.server.luau            Démarrage (Init puis Start de chaque service)
  Lib/
    Guard.luau                Validation + rate limit de TOUTES les RemoteFunctions
    RateLimiter.luau          Token bucket par joueur et par action
    MapBuilder.luau           Génération procédurale de la map
    MockDataStore.luau        DataStore en mémoire (Studio sans API)
  Services/
    DataService               Sauvegarde avec verrou de session (anti-duplication)
    MapService                Map : génération ou validation du contrat de noms
    PlotService               Attribution des bases, modèles dans les emplacements
    CharacterService          Spawn dans sa base, vitesse, téléportations serveur
    IncomeService             Revenus/s, seul service qui modifie l'argent
    SyncService               Envoi de l'état du joueur au client
    NotificationService       Toasts, annonces globales, effets
    RiftService               Dimensions, spawns, chance serveur, portails instables
    ShopService               Achat sur le chemin, revente
    StealService              Vol (porter, livrer, récupérer, anti-téléportation)
    BaseDefenseService        Barrière + alarme anti-vol
    FusionService             Portail de fusion
    ShortcutService           Portail de raccourci
    UpgradeService            Améliorations de base
    RebirthService            Rebirth
    IndexService              Index de collection + récompenses
    DailyRewardService        Récompenses quotidiennes
    LeaderboardService        leaderstats + classement global (OrderedDataStore)
    MonetizationService       Gamepasses, ProcessReceipt idempotent

src/client/   -> StarterPlayer.StarterPlayerScripts.Client
  Main.client.luau
  Controllers/                État, réseau, animation du chemin, bases, visuels, effets
  UI/                         HUD, notifications, 9 panneaux (tout créé par code)
```

---

## Boucle de jeu

| Étape | Où | Détail |
|---|---|---|
| Les créatures sortent de la Rift | `RiftService` | 1 toutes les ~3,5 s, tirage rareté puis créature (`Odds`) |
| Achat | `ShopService` | Touche **E** près d'une créature sur le chemin |
| Trajet jusqu'à la base | `ShopService` + `ConveyorController` | Contourne l'anneau puis entre dans la base |
| Revenus | `IncomeService` | Toutes les secondes, revenu x rebirth x index x gamepass |
| Vol | `StealService` | Maintenir **E** sur une créature adverse, rentrer dans SA base |
| Récupération | `StealService` | Le propriétaire touche le voleur |
| Barrière | `BaseDefenseService` | 60 s (+ améliorations, + gamepass), puis 90 s de recharge |
| Fusion | `FusionService` | 2 créatures identiques non mutées -> mutation x2 à x5 |
| Raccourci | `ShortcutService` | Téléportation devant une base adverse, propriétaire alerté |
| Rebirth | `RebirthService` | Reset argent + créatures, +50 % de revenus permanents, +1 emplacement |

**Dimensions** : changement toutes les 5 min, annonce globale, faille et ambiance recolorées.
Chaque dimension modifie les chances de rareté, la cadence et la vitesse des créatures.

**Portails instables** : toutes les 30 s, 4 % de chance (au moins 4 min d'écart) qu'un portail
doré s'ouvre sur le chemin et libère la créature **Secrète** de la dimension active.

---

## Sécurité : ce que le serveur vérifie

Le client ne fait que **demander**. Chaque RemoteFunction passe par `Guard` :
rate limit -> profil chargé -> nombre et types d'arguments stricts -> `pcall` -> réponse normalisée.

- **Achat** : la position de la créature est recalculée par le serveur (même formule que le
  client) ; distance, argent et place vérifiés ; débit et retrait du chemin sans aucune
  attente entre les deux (impossible d'acheter deux fois la même créature).
- **Vol** : barrière, distance réelle, place libre, créature non déjà portée. Pendant le
  transport, contrôle 5 fois par seconde (mort, délai, récupération, **vitesse anormale =
  annulation**). La créature reste dans les données de la victime jusqu'à la livraison.
- **Barrière** : la vraie protection est le refus serveur des vols ; le mur n'est qu'un visuel
  (un tricheur peut traverser un mur en local, il ne peut pas voler).
- **Argent** : modifié uniquement par `IncomeService` (côté serveur).
- **Robux** : `ProcessReceipt` idempotent (PurchaseId mémorisé), confirmé seulement après sauvegarde.

---

## Sauvegarde (DataService)

Verrou de session façon ProfileService/ProfileStore, sans dépendance externe :
- chargement uniquement si aucun autre serveur ne détient le profil (sinon on attend qu'il le
  libère, puis on le force à la dernière tentative) ;
- chaque écriture vérifie que le verrou appartient toujours à cette session (sinon arrêt et
  expulsion : impossible d'écraser une progression plus récente) ;
- autosave 60 s, sauvegarde rapide après les actions importantes, libération au départ et
  dans `BindToClose`.

Sauvegardé : argent, argent total, créatures (Id, mutation, emplacement), rebirths,
améliorations, raccourci, index, récompenses réclamées, série quotidienne, stats, cache des
gamepasses, reçus Robux traités.

**Limite connue (assumée)** : un vol modifie 2 profils sauvegardés séparément. Un crash serveur
pile entre les deux écritures pourrait dupliquer la créature (fenêtre de quelques secondes).
Les DataStores n'ont pas de transaction multi-clés ; le risque est réduit (`SaveSoon` sur les
deux joueurs) mais pas nul.

---

## Monétisation : à configurer

1. Creator Dashboard > ton expérience > **Monetization** : crée les 4 Passes et les 2
   Developer Products.
2. Copie leurs Ids dans `src/shared/Config/Monetization.luau` (remplace les `Id = 0`).

Tant qu'un Id vaut 0, le bouton affiche « non configuré » au lieu de planter.
Le **pack de chance** et **forcer une dimension** sont des effets de **serveur** : le chemin
étant partagé, une chance « personnelle » n'aurait aucun effet réel. Les chances exactes sont
affichées dans la boutique et l'index (règle Roblox sur les achats influençant un tirage).

---

## Réglages Studio recommandés

- **Game Settings > Security** : *Enable Studio Access to API Services* (sauvegarde réelle).
- **Players max = 8** (une base par joueur ; au-delà, le joueur est renvoyé poliment).
- `Workspace.StreamingEnabled = false` (déjà réglé par le projet ; les créatures du chemin
  sont de toute façon en `ModelStreamingMode.Persistent`).
- Debug rapide : `GameConfig.Debug` (argent de départ, tous les gamepasses, portails instables
  fréquents) ; ignoré en jeu publié.

---

## Vérifications effectuées

- Analyse de types `luau-lsp` (définitions Roblox officielles) : 0 diagnostic.
- Exécution réelle des modules partagés (Lune) : somme des probabilités = 100 % dans chaque
  dimension, calculs de revenus / emplacements / coûts / récompenses vérifiés, encodage du
  classement vérifié, géométrie du chemin vérifiée.
- `StealARift.rbxl` relu : 8 bases complètes (28 emplacements chacune), chemin de 545 studs,
  19 services serveur, 9 panneaux UI.

**Non testé ici** : une vraie session de jeu dans Studio (environnement Linux sans Roblox).
Lance un test à 2-3 joueurs (Test > Clients and Servers) avant de publier.
