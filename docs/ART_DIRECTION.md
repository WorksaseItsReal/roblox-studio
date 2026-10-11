# Direction artistique : style « Steal a … »

Objectif : que le jeu se lise au premier coup d'œil comme un jeu de la famille
*Steal a Brainrot* / *Steal an Egg* : couleurs **vives et saturées**, **contours noirs
épais**, gros textes ronds, tapis central où défilent les créatures, bases alignées de
chaque côté. Notre différence reste le thème : la **Rift** (portail dimensionnel) au bout
du tapis et les 5 dimensions.

Règles générales
- Zéro pastel délavé, zéro lavande. Couleurs franches, contrastes forts.
- Noir pur (`0, 0, 0`) pour tous les contours d'interface et de texte.
- Un code couleur constant : **vert** = argent / acheter, **jaune-or** = récompenses,
  **rouge** = danger / vol / barrière, **bleu** = navigation / infos, **violet** = rare / magique.
- Lisibilité d'abord : un joueur doit comprendre l'écran en 2 secondes, sur téléphone.

---

## 1. Monde

### Disposition (repère monde, Y vers le haut)
```
                 Z = -195   [ RIFT (portail géant, face à +Z) ]  + 2 tableaux de classement
                              |      tapis rouge      |
   Plot1 (ouest)  ◄ entrée    |   ↓ ↓ ↓ créatures ↓   |    entrée ►  Plot2 (est)     Z = -105
   Plot3                      |                       |               Plot4           Z =  -35
   Plot5                      |                       |               Plot6           Z =  +35
   Plot7                      |                       |               Plot8           Z = +105
                 Z = +195   [ portail de sortie (plus petit, sombre) ]
```
- **Tapis** (le chemin des créatures) : ligne droite le long de l'axe Z, centré en X = 0,
  de Z = -185 à Z = +185, largeur 14, surélevé de 0,5. Rouge vif `(215, 38, 52)` avec
  bordures or `(255, 200, 60)` de chaque côté. Chevrons blancs/or animés dans le sens de
  marche (+Z) — mêmes noms qu'avant (`Chevron`, attribut `Index`).
- **Trottoirs** : de chaque côté du tapis, X = ±8 à ±18, gris très clair `(232, 232, 240)`,
  bordures blanches. Lampadaires tous les ~35 studs.
- **Bases** : 4 par côté, centres en X = ±66 et Z = -105, -35, +35, +105. Chaque base fait
  face au tapis (son -Z local pointe vers X = 0). Numérotation alternée ouest/est en partant
  de la Rift (Plot1 = ouest Z=-105, Plot2 = est Z=-105, …) : les premiers joueurs ont les
  bases les plus proches de la Rift.
- **Rift** : au bout nord du tapis (centre ~ (0, 17, -195)), face à +Z, les créatures en
  sortent. **Portail de sortie** au bout sud (~ (0, 10, 195)), plus petit et sombre : les
  créatures non achetées y disparaissent.
- **Île** : on garde l'île flottante ronde (rayon 300), les falaises, la mer de nuages et les
  îlots. Arbres et rochers sur le pourtour, hors des bases et des bouts du tapis.
- Plus d'anneau : `PathData` n'a plus `RingRadius`. Les créatures achetées marchent
  du tapis vers le trottoir, longent le trottoir puis entrent dans la base.

### Palette du monde
| Élément | Couleur |
|---|---|
| Herbe | `(86, 196, 70)` (variante plus foncée `(66, 168, 58)` pour les touffes) |
| Tapis | `(215, 38, 52)` + bordures or `(255, 200, 60)` |
| Trottoir | `(232, 232, 240)`, bordures `(255, 255, 255)` |
| Sol des bases | blanc cassé `(245, 245, 250)`, quadrillage léger couleur d'équipe |
| Murs des bases | couleur d'équipe saturée (voir ci-dessous), montants blancs |
| Socles (emplacements) | blancs, anneau néon couleur d'équipe |
| Couleurs d'équipe | rouge `(255, 64, 64)`, orange `(255, 140, 30)`, jaune `(255, 210, 40)`, vert `(60, 210, 90)`, cyan `(30, 200, 255)`, bleu `(50, 110, 255)`, violet `(160, 80, 255)`, rose `(255, 80, 190)` |

### Bases (la vitrine du joueur)
- Murs pleins de couleur d'équipe (hauteur ~8) avec bandeau blanc en haut, montants aux
  coins. Pas de verre teinté pastel.
- **Arche d'entrée** côté tapis avec un grand panneau : `BASE DE {Nom}` en très gros
  (police Luckiest Guy, blanc contour noir) sur fond couleur d'équipe.
- **Barrière = lasers** : quand la base est verrouillée, des faisceaux néon rouges
  horizontaux barrent l'entrée (au lieu d'un mur ForceField). Le bouton de verrouillage est
  un gros bouton rouge rond au sol, bien visible.
- Socles ronds blancs alignés, anneau néon couleur d'équipe sur ceux qui sont débloqués,
  gris foncé sur ceux qui sont verrouillés.

### Éclairage
- Plein jour franc : `ClockTime` 13, `Brightness` ~3, ombres activées, technologie Future.
- Atmosphère légère (pas de brume laiteuse) : `Density` ~0,18, `Haze` ~0,3.
- `ColorCorrection` : saturation +0,2, contraste +0,08. Bloom discret (seuil haut).
- Les teintes de dimension restent subtiles (proches du blanc) : elles colorent la Rift,
  les chevrons et l'ambiance, sans délaver le reste.

---

## 2. Créatures

- Couleurs de corps **saturées** par dimension (Lave orange/rouge vif, Néant violet profond,
  Glace bleu glacier vif, Bonbon rose bonbon, Cyber gris métal + néon vert).
- Gros yeux brillants, joues roses, silhouettes rondes et lisibles de loin.
- Rareté visible de loin : disque néon au sol, particules à partir de Légendaire, aura
  arc-en-ciel pour Secret.
- **Étiquette au-dessus de chaque créature** (style du genre, texte seul, sans pastille) :
  ```
  [Mutation x3]            (si mutée, couleur de la mutation)
  Nom de la créature       blanc, contour noir
  LÉGENDAIRE               dégradé de la couleur de rareté (arc-en-ciel pour Secret)
  $1,2K/s                  jaune-or
  $25K                     vert vif (seulement sur le tapis)
  ```
  Police : Luckiest Guy pour la rareté et les montants, Fredoka One pour le nom.
  Contours de texte noirs épais (2–3 px).

### Raretés (couleurs de référence)
| Rareté | Couleur |
|---|---|
| Commun | `(200, 200, 200)` |
| Rare | `(40, 140, 255)` |
| Épique | `(170, 70, 255)` |
| Légendaire | `(255, 190, 0)` |
| Mythique | `(255, 40, 70)` |
| Secret | arc-en-ciel (dégradé multicolore) |

---

## 3. Interface

### Polices
- `Enum.Font.LuckiestGuy` : titres de fenêtres, boutons, montants, grands chiffres.
- `Enum.Font.FredokaOne` : textes courants, descriptions, étiquettes.

### Jetons de couleur (Theme)
| Jeton | Valeur |
|---|---|
| Contour (Ink) | `(0, 0, 0)` |
| Texte | `(255, 255, 255)` |
| Texte secondaire | `(225, 235, 255)` |
| Fenêtre (dégradé) | `(66, 160, 255)` → `(30, 92, 220)` (bleu vif) |
| Carte (dégradé) | `(110, 190, 255)` → `(60, 130, 240)` |
| Encart | `(18, 52, 140)` |
| Argent | `(80, 255, 90)` |
| Or | `(255, 215, 40)` |
| Danger | `(255, 60, 60)` |

Boutons : dégradé vertical vif + rebord inférieur plus foncé (effet 3D), contour noir 3–4 px,
coins arrondis moyens (pas des pilules partout). Texte blanc contour noir.

### Principes
- Argent toujours en vert vif, gros, avec contour noir.
- Les fenêtres ont un en-tête coloré avec le titre en Luckiest Guy, un bouton fermer rouge
  rond, un corps bleu vif ; les cartes à l'intérieur sont plus claires.
- Moins de texte, plus d'icônes et de chiffres. Rien ne doit déborder ni se chevaucher.
