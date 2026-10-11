# Construire la map dans Roblox Studio

Trois niveaux, du plus rapide au plus personnalisé.

## 1. Ne rien faire (map automatique)

`StealARift.rbxl` contient déjà la map. Avec Rojo, `MapService` la génère au lancement si
`Workspace.Map` n'existe pas. Rien à construire.

## 2. Décorer la map générée

1. Ouvre `StealARift.rbxl`.
2. Ajoute librement des décors **en dehors** de `Workspace.Map`, ou dans `Workspace.Map`
   sans renommer ni supprimer les instances listées plus bas.
3. Tu peux recolorer / changer les matériaux des sols, murs, routes, de la Rift.
4. Sauvegarde. Au lancement, `MapService` valide le contrat de noms et signale dans la
   sortie toute pièce manquante.

## 3. Construire ta propre map

Respecte ce **contrat de noms** (vérifié au démarrage par `MapService`) :

```
Workspace
└── Map (Folder)
    ├── Rift (Model)                 décor libre. Optionnel pour les effets client :
    │     Core, Swirl (cylindres), RingSegment, Shard (pièces)
    ├── PathWaypoints (Folder)       chemin des créatures : pièces WP1, WP2, ..., WPn
    │     (OU PathData : Configuration avec attributs Count + WP1..WPn en Vector3)
    ├── Plots (Folder)
    │   └── Plot1 ... PlotN (Model)  attribut PlotId (nombre) ou nom terminé par un nombre
    │       ├── Floor            (Part)  sol ; sa face -Z = côté ENTRÉE ; son volume = la base
    │       ├── Barrier          (Part)  mur de l'entrée (Transparency 1, CanCollide false)
    │       ├── Spawn            (Part)  apparition du propriétaire
    │       ├── Entrance         (Part)  point devant l'entrée (trajet des créatures achetées)
    │       ├── ShortcutLanding  (Part)  arrivée du portail de raccourci (DEVANT la barrière)
    │       ├── LockButton       (Part)  + ProximityPrompt "LockPrompt"
    │       ├── FusionPortal     (Part)  + ProximityPrompt "FusionPrompt"
    │       ├── Sign             (Part, optionnel) + SurfaceGui "SignGui" > TextLabel "Text"
    │       └── Slots (Folder)   Slot1 ... Slot28 (Parts, face du haut = où se pose la créature)
    ├── Boards (Folder, optionnel)   tableaux de classement remplis par le client :
    │     MoneyBoard, StealsBoard (Parts) + SurfaceGui "BoardGui" > Frame > Frame "Rows"
    └── (Movers, Portals : créés automatiquement)
```

### Étapes conseillées

1. **La Rift (centre)** : crée un Model `Rift` au centre (0, 0, 0). Un grand anneau vertical
   en pièces Neon nommées `RingSegment` + un disque `Core` (Cylinder, Neon) suffisent : le
   client les recolore à chaque changement de dimension.
2. **Le chemin** : pose des petites pièces ancrées `WP1`, `WP2`... dans `Map.PathWaypoints`,
   au niveau du sol, dans l'ordre de marche. `WP1` doit être à la sortie de la Rift, le
   dernier point au retour dans la Rift. Comptez 25 à 40 points pour un anneau de ~70 studs
   de rayon. Si le chemin est un cercle centré, ajoute à `Map.PathData` (Configuration) les
   attributs `RingRadius` (nombre) et `RingCenter` (Vector3) : les créatures achetées
   contourneront la Rift au lieu de la traverser.
3. **Les bases** : construis une base complète (`Plot1`), vérifie-la en jeu, puis duplique-la
   (8 bases = 8 joueurs max). Garde l'entrée tournée vers le chemin (face -Z du `Floor`).
   Ferme les 3 autres côtés par des murs d'au moins 12 studs (sinon on contourne la barrière).
4. **Emplacements** : 28 pièces `Slot1`..`Slot28` (tu peux en mettre plus, jamais moins que
   `GameConfig.Slots.MaxPhysical`). L'ordre compte : les premiers sont débloqués d'abord.
5. **Spawn** : une `SpawnLocation` neutre près du centre sert à l'apparition avant
   l'attribution de la base.
6. Lance **Play** : la sortie affiche `[MapService] N bases, chemin de X studs` si tout va bien,
   sinon le nom exact de la pièce manquante.

### Brancher les scripts

- **Avec le fichier `.rbxl`** : rien à faire, les scripts sont déjà en place
  (`ServerScriptService.Server`, `StarterPlayer.StarterPlayerScripts.Client`,
  `ReplicatedStorage.Shared`).
- **Avec Rojo** : `rojo serve` puis plugin Rojo > Connect. Rojo ne touche pas à
  `Workspace.Map` : ta map construite à la main est conservée.

### Utiliser tes propres modèles de créatures

Place un Model dans `ReplicatedStorage.Assets.Creatures` nommé comme l'`Id` de la créature
(ex. `Lava_Braisillon`) ou comme son champ `Model` dans `Config/Creatures.luau`. Il remplacera
automatiquement le modèle procédural (aura de rareté et effets de mutation conservés).
