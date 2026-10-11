# Steal a Rift

Jeu Roblox inspiré de *Steal a Brainrot*, revisité autour de portails dimensionnels.
Au centre d'une île flottante, une faille géante (la **Rift**) libère des créatures qui
suivent un chemin circulaire. Les joueurs les achètent, les installent dans leur base pour
générer de l'argent, et volent celles des autres.

---

## Aperçu

| Vue générale | L'île flottante |
|---|---|
| ![Vue générale](docs/previews/monde_vue_generale.jpg) | ![Île](docs/previews/monde_ile_flottante.jpg) |
| **La Rift** | **Une base** |
| ![Rift](docs/previews/monde_rift.jpg) | ![Base](docs/previews/monde_base.jpg) |
| **Les 40 créatures (5 dimensions)** | **HUD** |
| ![Créatures](docs/previews/creatures.jpg) | ![HUD](docs/previews/ui_hud.jpg) |
| **Quêtes du jour** | **Cadeaux de session** |
| ![Quêtes](docs/previews/ui_quetes.jpg) | ![Cadeaux](docs/previews/ui_cadeaux.jpg) |
| **Tutoriel guidé** | **Inventaire** |
| ![Tutoriel](docs/previews/ui_tutoriel.jpg) | ![Inventaire](docs/previews/ui_inventaire.jpg) |
| **Index** | **Boutique** |
| ![Index](docs/previews/ui_index.jpg) | ![Boutique](docs/previews/ui_boutique.jpg) |

> Ces images sont des **aperçus générés hors Roblox** : rendu three.js de la géométrie exacte
> de la map et des créatures, rendu HTML de l'arbre d'interface produit par le vrai code.
> Le rendu dans Studio diffère (éclairage Future, matériaux, bloom), mais formes, couleurs
> et mise en page sont fidèles.

**Visuels de la page Roblox** (dossier `marketing/`) : icône 512×512 et 3 miniatures
1920×1080, générées à partir de la vraie map et des vraies créatures. Plan de lancement,
description FR/EN et points bloquants : **[docs/LAUNCH.md](docs/LAUNCH.md)**.

---

## Démarrage rapide (2 options)

### Option A : ouvrir le fichier de place (le plus simple)

1. Télécharge **`StealARift.rbxl`** (à la racine du dépôt).
2. Double-clique dessus : Roblox Studio l'ouvre. La map est déjà construite et visible.
3. Clique sur **Play** (F5). Tu apparais dans ta base, les créatures sortent de la Rift, le
   tutoriel te guide.
4. Pour tester à plusieurs : onglet **Test** > **Clients and Servers** > 2 ou 3 joueurs >
   **Start** (indispensable pour tester le vol, la vengeance et le bonus d'amis).

> Sans réglage, les données sont stockées **en mémoire** (perdues à l'arrêt) et la console
> l'indique. Pour la vraie sauvegarde : publie la place (File > Publish to Roblox), puis
> **Game Settings > Security > Enable Studio Access to API Services**.

### Option B : workflow Rojo (pour développer)

```bash
rokit install                 # Rojo 7.7.1, StyLua 2.6.0, Lune 0.10.5 (versions testées)
rojo serve                    # puis, dans Studio : plugin Rojo > Connect
```

Avec Rojo, la map n'existe pas dans le fichier : `MapService` la génère automatiquement au
lancement (Play). Pour régénérer le `.rbxl` complet (scripts + map pré-construite) :

```bash
rojo build default.project.json -o build/rojo.rbxl
lune run scripts/build-place.luau build/rojo.rbxl StealARift.rbxl
```

> **Correctif de cette version** : dans la version précédente du `.rbxl`, les bases étaient
> tournées de travers (45° ou 135°), la route était en dents de scie et les flèches
> pointaient à l'envers. Cause : `CFrame.lookAt` de Lune (l'outil qui « cuit » la map hors
> de Roblox) renvoie une orientation en miroir. `MapBuilder` utilise désormais son propre
> `lookAt` basé sur `CFrame.fromMatrix`, identique à Roblox dans les deux environnements.
> **Remplace ton ancien `StealARift.rbxl` par celui-ci.**

---

## Arborescence

```
default.project.json          Projet Rojo
StealARift.rbxl               Place prête à ouvrir (scripts + map)
scripts/build-place.luau      Construit StealARift.rbxl (Lune)
docs/MAP_BUILD.md             Construire / personnaliser la map dans Studio
docs/LAUNCH.md                Lancement : bloquants, tests, plan, description de la page
marketing/                    Icône + miniatures pour la page Roblox

src/shared/   -> ReplicatedStorage.Shared
  Config/
    GameConfig.luau           TOUS les réglages (économie, timers, social, tempête, cadeaux...)
    Creatures.luau            40 créatures (8 par dimension)
    Dimensions.luau           5 dimensions (Lave, Néant, Glace, Bonbon, Cyber)
    Rarities.luau             6 raretés (Commun -> Secret)
    Mutations.luau            Mutations de fusion (x2 à x5)
    Upgrades.luau             Améliorations de base
    Quests.luau               Quêtes du jour (pool, objectifs, récompenses)
    Sounds.luau               Sons et musique (Ids remplaçables)
    Monetization.luau         Ids des gamepasses / produits (à remplir)
  Modules/
    Economy.luau              Calculs purs (revenus, bonus, hors ligne, titres...)
    Odds.luau                 Probabilités d'apparition (tirage + affichage)
    PathMath.luau             Position sur le chemin (serveur ET client)
    StormSchedule.luau        Horaire de la tempête (identique sur tous les serveurs)
    QuestLogic.luau           Tirage déterministe des quêtes du jour
    CreatureVisuals.luau      Modèles de créatures (procéduraux ou vos assets)
    Remotes.luau              Liste des RemoteFunctions / RemoteEvents
    Format, Signal, LeaderboardCodec

src/server/   -> ServerScriptService.Server
  Main.server.luau            Démarrage (Init puis Start de chaque service, dans l'ordre)
  Config/Codes.luau           Codes promo (côté serveur : invisibles pour les clients)
  Lib/
    Guard.luau                Validation + rate limit de TOUTES les RemoteFunctions
    RateLimiter.luau          Token bucket par joueur et par action
    MapBuilder.luau           Génération procédurale de la map
    MockDataStore.luau        DataStore en mémoire (Studio sans API)
  Services/ (26)
    DataService               Sauvegarde avec verrou de session (anti-duplication)
    MapService                Map : génération ou validation du contrat de noms
    PlotService               Attribution des bases, modèles dans les emplacements
    CharacterService          Spawn dans sa base, vitesse, téléportations serveur
    IncomeService             Revenus/s, gains hors ligne ; seul service qui modifie l'argent
    SyncService               Envoi de l'état du joueur au client
    NotificationService       Toasts, annonces globales, effets, fil d'actualité
    RiftService               Dimensions, spawns, chance, portails instables, tempête
    ShopService               Achat sur le chemin, revente
    StealService              Vol (porter, livrer, récupérer, anti-téléportation)
    BaseDefenseService        Barrière + alarme anti-vol
    FusionService             Portail de fusion
    ShortcutService           Portail de raccourci + vengeance gratuite
    UpgradeService            Améliorations de base
    RebirthService            Rebirth
    IndexService              Index de collection + récompenses
    DailyRewardService        Récompenses quotidiennes
    LeaderboardService        leaderstats + classement global (OrderedDataStore)
    MonetizationService       Gamepasses, ProcessReceipt idempotent
    RewardService             Distribution des récompenses (argent, boost, créature)
    SocialBonusService        Bonus amis sur le serveur + bonus de groupe
    QuestService              Quêtes du jour (progression, réclamation, bonus)
    PlaytimeService           Cadeaux de session (temps compté côté serveur)
    CodesService              Codes promo (une fois par joueur, date d'expiration)
    TutorialService           Récompense de fin de tutoriel (une seule fois)
    NameTagService            Titre + stats au-dessus de la tête des joueurs

src/client/   -> StarterPlayer.StarterPlayerScripts.Client
  Main.client.luau
  Controllers/                État, réseau, chemin, bases, Rift, sons, effets ("juice"),
                              tutoriel, tableaux de classement
  UI/                         HUD, notifications, fil d'actualité, 12 panneaux (tout par code)
```

---

## Rétention et viralité

| Système | Ce que ça fait | Réglage |
|---|---|---|
| **Tutoriel** | 4 étapes avec flèche dans le monde (acheter, voir sa base, barrière, voler). Récompense à la fin. | `GameConfig.Tutorial` |
| **Gains hors ligne** | 50 % des revenus pendant l'absence (8 h max), popup « Bon retour ! » | `GameConfig.Offline` |
| **Bonus amis / groupe** | +10 % d'argent par ami présent sur le serveur (max +50 %), +10 % si membre du groupe | `GameConfig.Social` (`GroupId`) |
| **Invitation** | Bouton « Amis » qui ouvre l'invitation Roblox | HUD |
| **Quêtes du jour** | 3 quêtes tirées par joueur et par jour (identiques sur tous les serveurs), bonus si les 3 sont faites | `Config/Quests.luau` |
| **Cadeaux de session** | 9 cadeaux de 1 à 60 min de jeu (argent, boost x2, créature mystère) | `GameConfig.Playtime` |
| **Codes promo** | `RIFT`, `LANCEMENT`, `PORTAIL` (une fois par joueur) | `src/server/Config/Codes.luau` |
| **Tempête de la Rift** | Toutes les heures à HH:30 UTC, 4 min : chance x3, apparitions plus rapides, portail doré garanti, ciel et éclairs. Avertissement 5 min avant. | `GameConfig.Storm` |
| **Vengeance** | Après un vol, la victime a 90 s pour se téléporter gratuitement chez le voleur | `GameConfig.Revenge` |
| **Preuve sociale** | Fil d'actualité du serveur, titres au-dessus des têtes (Novice -> Divinité dimensionnelle), 2 classements géants dans le monde | `GameConfig.Titles` |
| **Juice** | Sons, « +$ » flottants au-dessus de tes créatures, confettis, secousses, piliers de lumière sur les créatures Légendaires+ | `Config/Sounds.luau` |

---

## Direction artistique

- **Interface "simulateur"** (`src/client/UI`) : système de design centralisé dans `Theme.luau`
  et `UIKit.luau` : boutons 3D, contours épais, textes Fredoka One, icônes emoji, pastilles,
  barres de progression, badges « ! » sur ce qui est réclamable. Toute l'UI est mise à
  l'échelle automatiquement (PC, tablette, téléphone) à partir d'un écran de référence 1280x760.
- **Créatures** (`CreatureVisuals.luau`) : corps arrondis (ellipsoïdes `SpecialMesh`, aucun
  asset à publier), gros yeux brillants, un style par dimension, couronne dès Légendaire,
  disque lumineux de rareté, aura pour les mutations. Elles se dandinent sur le chemin et
  « respirent » dans les bases.
- **Map** (`MapBuilder.luau`) : île flottante au-dessus d'une mer de nuages (cumulus en
  grappes), bosquets, îlots à l'horizon ; Rift entre deux piliers de roche ; route circulaire
  avec chevrons lumineux dans le sens de marche ; 8 bases tournées vers la Rift avec allées ;
  2 tableaux de classement géants entre deux bases. Tout ce qui brille se recolore selon la
  dimension active (et vire au violet pendant la tempête).
- Pour aller plus loin : remplace les créatures procédurales par de vrais modèles 3D
  (`ReplicatedStorage.Assets.Creatures`, voir `docs/MAP_BUILD.md`). C'est le levier visuel n°1.

---

## Boucle de jeu

| Étape | Où | Détail |
|---|---|---|
| Les créatures sortent de la Rift | `RiftService` | 1 toutes les ~3,5 s, tirage rareté puis créature (`Odds`) |
| Achat | `ShopService` | Touche **E** près d'une créature sur le chemin |
| Trajet jusqu'à la base | `ShopService` + `ConveyorController` | Contourne l'anneau puis entre dans la base |
| Revenus | `IncomeService` | Toutes les secondes, revenu x rebirth x index x gamepass x amis/groupe x boost |
| Vol | `StealService` | Maintenir **E** sur une créature adverse, rentrer dans SA base |
| Récupération | `StealService` | Le propriétaire touche le voleur |
| Vengeance | `ShortcutService` | Téléportation gratuite chez le voleur pendant 90 s |
| Barrière | `BaseDefenseService` | 60 s (+ améliorations, + gamepass), puis 90 s de recharge |
| Fusion | `FusionService` | 2 créatures identiques non mutées -> mutation x2 à x5 |
| Raccourci | `ShortcutService` | Téléportation devant une base adverse, propriétaire alerté |
| Rebirth | `RebirthService` | Reset argent + créatures, +50 % de revenus permanents, +1 emplacement, titre qui évolue |

**Dimensions** : changement toutes les 5 min, annonce globale, faille et ambiance recolorées.
Chaque dimension modifie les chances de rareté, la cadence et la vitesse des créatures.

**Portails instables** : toutes les 30 s, 4 % de chance (au moins 4 min d'écart) qu'un portail
doré s'ouvre sur le chemin et libère la créature **Secrète** de la dimension active
(un portail est garanti au début de chaque tempête).

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
- **Barrière** : la vraie protection est le refus serveur des vols ; le mur n'est qu'un visuel.
- **Argent** : modifié uniquement par `IncomeService` (côté serveur).
- **Récompenses** : quêtes, cadeaux (temps compté par le serveur), codes, tutoriel : tout est
  vérifié et mémorisé côté serveur (impossible de réclamer deux fois).
- **Codes promo** : stockés dans `ServerScriptService`, jamais répliqués aux clients.
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
améliorations, raccourci, index, récompenses réclamées, série quotidienne, quêtes du jour,
codes utilisés, tutoriel, boosts, dernière connexion (gains hors ligne), stats, cache des
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
- `Workspace.StreamingEnabled = false` (déjà réglé par le projet).
- `GameConfig.Social.GroupId` : Id de ton groupe Roblox (bonus de groupe).
- `Config/Sounds.luau` : sons par défaut de Roblox (basiques) ; ajoute une musique de la
  bibliothèque audio (`Music.Id`) et remplace les sons par de meilleurs si tu veux.
- Debug rapide : `GameConfig.Debug` (argent de départ, tous les gamepasses, portails instables
  fréquents) ; ignoré en jeu publié. Pour tester la tempête, baisse temporairement
  `GameConfig.Storm.IntervalMinutes`.

---

## Vérifications effectuées

- Analyse de types `luau-lsp` (définitions Roblox officielles) sur tout `src/` : 0 diagnostic.
- `stylua --check` : OK.
- Exécution réelle des modules partagés (Lune) : probabilités = 100 % dans chaque dimension,
  revenus / emplacements / coûts / récompenses, gains hors ligne, horaire de la tempête,
  tirage des quêtes (déterministe, sans doublon), encodage du classement, géométrie du chemin.
- Contrôles croisés statiques : chaque appel entre services, chaque champ `ctx` / `State` /
  `ctx.UI` / `ctx.Net` et chaque nom de remote existe ; chaque RemoteFunction a un handler
  serveur.
- `StealARift.rbxl` relu : 8 bases orientées vers la Rift (entrée côté route, emplacements de
  l'entrée vers le fond), éclairage Future + effets, 26 services, 12 panneaux.
- Rendus de contrôle (aperçus ci-dessus) de la map, des créatures et de chaque écran.

**Non testé ici** : une vraie session de jeu dans Studio (environnement Linux sans Roblox).
Lance un test à 2-3 joueurs (Test > Clients and Servers) avant de publier.
