# Construire la map dans Roblox Studio

Trois niveaux, du plus rapide au plus personnalisé.

## 1. Ne rien faire (map automatique)

`StealARift.rbxl` contient déjà la map. Avec Rojo, `MapService` la génère au lancement si
`Workspace.Map` n'existe pas. Rien à construire.

La map générée (`src/server/Lib/MapBuilder.luau`) suit le style « Steal a … »
(`docs/ART_DIRECTION.md`) : une île flottante, un **long tapis rouge en ligne droite** où
défilent les créatures, et **4 bases de chaque côté**, entrée face au tapis.

```
                    Z = -195   [ RIFT ]  portail géant face à +Z, sur une esplanade
           [Classement]          |  |          [Classement]
                                 |  |  tapis rouge (X = 0, largeur 14, bordures or)
   Plot1 (ouest)  ◄── entrée     |  |     entrée ──►  Plot2 (est)       Z = -105
   Plot3                         |  |                 Plot4             Z =  -35
   Plot5                         |  |                 Plot6             Z =  +35
   Plot7                         |  |                 Plot8             Z = +105
                    Z = +195   [ sortie ]  petit portail sombre
```

- Trottoirs de X = ±8 à ±18 (lampadaires tous les 35 studs), bases centrées en X = ±66.
- La Rift est l'emblème du jeu : anneau de rayon 22, centre (0, 22.5, -195), le bas de
  l'anneau au ras du tapis (les créatures sortent du vortex). C'est plus grand que le
  centre « vers Y = 17 » de `docs/ART_DIRECTION.md`, volontairement : elle doit se lire
  depuis l'autre bout du tapis et dominer les tableaux de classement (X = ±54).
- Les créatures marchent vers +Z : elles sortent de la Rift et disparaissent dans le
  portail de sortie (~385 studs, ~77 s à `GameConfig.Rift.CreatureWalkSpeed`).
- Numérotation alternée ouest/est en partant de la Rift : les premiers joueurs arrivés ont
  les bases les plus proches de la Rift.
- Une créature achetée quitte le tapis, longe le trottoir de son côté, entre par l'arche
  de sa base, remonte l'allée puis rejoint son emplacement en passant entre deux rangées
  de socles (jamais à travers un socle, le bouton de verrouillage ou le portail de fusion).
- Socles : construits « verrouillés » (socle gris perle, anneau gris foncé mat) ; le serveur
  passe ceux que le joueur a débloqués en blanc avec un anneau néon couleur d'équipe.

## 2. Décorer la map générée

1. Ouvre `StealARift.rbxl`.
2. Ajoute librement des décors **en dehors** de `Workspace.Map`, ou dans `Workspace.Map`
   sans renommer ni supprimer les instances listées plus bas.
3. Tu peux recolorer / changer les matériaux des sols, murs, du tapis, de la Rift.
   Garde les couleurs franches (pas de pastel) : voir la palette de `docs/ART_DIRECTION.md`.
4. Sauvegarde. Au lancement, `MapService` valide le contrat de noms et signale dans la
   sortie toute pièce manquante.

## 3. Construire ta propre map

Respecte ce **contrat de noms** (vérifié au démarrage par `MapService`) :

```
Workspace
└── Map (Folder)
    ├── Rift (Model)                 décor libre. Optionnel pour les effets client :
    │     Core, Swirl, Swirl2, RiftDeep (disques), RingSegment, RiftTooth, Shard, Crack,
    │     RiftBeam, SwirlArm (bras de la spirale) ; attribut ShardOrbit (rayon des éclats)
    ├── PathWaypoints (Folder)       chemin des créatures : pièces WP1, WP2, ..., WPn
    │     (OU PathData : Configuration avec attributs Count + WP1..WPn en Vector3,
    │      et LaneOffset optionnel, voir plus bas)
    ├── Plots (Folder)
    │   └── Plot1 ... PlotN (Model)  attribut PlotId (nombre) ou nom terminé par un nombre
    │       ├── Floor            (Part)  sol ; sa face -Z = côté ENTRÉE ; son volume = la base
    │       ├── Barrier          (Part)  mur LOGIQUE de l'entrée (Transparency 1, CanCollide false)
    │       ├── Lasers           (Folder, optionnel) pièces montrées quand la base est
    │       │                            verrouillée (attribut ActiveTransparency, défaut 0)
    │       ├── LaserLens        (Parts, optionnelles) lentilles des émetteurs : néon rouge
    │       │                            quand la base est verrouillée, éteintes sinon
    │       ├── Spawn            (Part)  apparition du propriétaire (debout, face au chemin)
    │       ├── Entrance         (Part)  point devant l'entrée (trajet des créatures achetées)
    │       ├── ShortcutLanding  (Part)  arrivée du portail de raccourci (DEVANT la barrière)
    │       ├── LockButton       (Part)  + ProximityPrompt "LockPrompt"
    │       ├── FusionPortal     (Part)  + ProximityPrompt "FusionPrompt"
    │       ├── Sign             (Part, optionnel) + SurfaceGui "SignGui" > TextLabel "Text"
    │       │                            (+ TextLabel "Status" et SurfaceGui "SignGuiBack" optionnels)
    │       └── Slots (Folder)   Slot1 ... Slot28 (Parts, face du haut = où se pose la créature)
    ├── Boards (Folder, optionnel)   tableaux de classement remplis par le client :
    │     MoneyBoard, StealsBoard (Parts) + SurfaceGui "BoardGui" > ... > Frame "Rows"
    └── (Movers, Portals : créés automatiquement)
```

### Étapes conseillées

1. **La Rift** : crée un Model `Rift` au début du chemin. Un grand anneau vertical en
   pièces Neon nommées `RingSegment` + un disque `Core` (Cylinder, Neon) suffisent : le
   client les recolore à chaque changement de dimension (ainsi que les pièces `Chevron`
   et `Lamp` du tapis). Effets optionnels : `RiftDeep` (disque plus petit, recoloré dans
   la couleur de la faille assombrie), `SwirlArm` (pièces devant le disque, qui tournent
   autour de l'axe du `Core`), `Shard` (éclats en orbite horizontale ; rayon = attribut
   `ShardOrbit` du Model, sinon leur distance de départ au centre : garde-les hors des
   piliers). Les pièces des créatures (`Movers`, `Creatures`) et des portails instables
   (`Portals`) ne sont jamais recolorées, même si elles portent ces noms.
2. **Le chemin** : pose des petites pièces ancrées `WP1`, `WP2`... dans `Map.PathWaypoints`,
   au niveau du sol, dans l'ordre de marche. `WP1` doit être à la sortie de la Rift, le
   dernier point là où les créatures disparaissent. Un chemin droit n'a besoin que de 2
   points (ajoutes-en un tous les 30 à 40 studs pour t'y retrouver) ; un chemin courbe en
   demande davantage. Vise 70 à 80 s de traversée : longueur ÷
   `GameConfig.Rift.CreatureWalkSpeed`.
3. **La voie des créatures achetées** : elles rejoignent leur base en longeant le chemin
   à une distance fixe, du côté de leur base, puis entrent par `Entrance`. Avec
   `Map.PathData` (Configuration), l'attribut `LaneOffset` (nombre, en studs) fixe cette
   distance : mets-la au milieu de ton trottoir. Sans lui, elles marchent aux deux tiers
   de la distance entre le chemin et les entrées. Aucune base ni aucun mur ne doit se
   trouver sur cette voie.
4. **Les bases** : construis une base complète (`Plot1`), vérifie-la en jeu, puis duplique-la
   (8 bases = 8 joueurs max). L'entrée (face -Z du `Floor`) doit faire face au chemin.
   Ferme les 3 autres côtés et le reste de la façade par des murs d'au moins 9 studs (sinon
   on contourne la barrière). La `Barrier` bouche l'ouverture de l'entrée ; dessine le
   verrou avec des pièces dans `Lasers` (sinon la `Barrier` elle-même devient visible).
5. **Emplacements** : 28 pièces `Slot1`..`Slot28` (tu peux en mettre plus, jamais moins que
   `GameConfig.Slots.MaxPhysical`). L'ordre compte : les premiers sont débloqués d'abord.
   Laisse une allée dégagée dans l'axe de l'entrée : les créatures achetées la remontent,
   puis longent la rangée de leur emplacement côté entrée, à (rayon du socle + 1,3) studs
   de son centre. Espace donc les rangées d'au moins 2 × (rayon + 1,3) studs (9 studs pour
   les socles de 6,4 de diamètre) et garde ce passage libre devant la première rangée.
6. **Spawn** : une `SpawnLocation` neutre près de la Rift sert à l'apparition avant
   l'attribution de la base. `Spawn` et `ShortcutLanding` doivent rester debout (pas de
   Part Cylinder couché) : le joueur téléporté prend leur orientation.
7. Lance **Play** : la sortie affiche `[MapService] N bases, chemin de X studs` si tout va bien,
   sinon le nom exact de la pièce manquante.

### Brancher les scripts

- **Avec le fichier `.rbxl`** : rien à faire, les scripts sont déjà en place
  (`ServerScriptService.Server`, `StarterPlayer.StarterPlayerScripts.Client`,
  `ReplicatedStorage.Shared`).
- **Avec Rojo** : `rojo serve` puis plugin Rojo > Connect. Rojo ne touche pas à
  `Workspace.Map` : ta map construite à la main est conservée.
- **Régénérer la map procédurale dans le .rbxl** (après une modification de
  `MapBuilder.luau`) :
  ```
  rojo build default.project.json -o build/rojo.rbxl
  lune run scripts/build-place.luau build/rojo.rbxl StealARift.rbxl
  ```
  Le script règle aussi l'éclairage par défaut (plein jour, technologie Future).

### Utiliser tes propres modèles de créatures

Place un Model dans `ReplicatedStorage.Assets.Creatures` nommé comme l'`Id` de la créature
(ex. `Lava_Braisillon`) ou comme son champ `Model` dans `Config/Creatures.luau`. Il remplacera
automatiquement le modèle procédural (aura de rareté et effets de mutation conservés).
