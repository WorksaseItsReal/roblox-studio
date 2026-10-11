# Direction artistique v3 : « propre »

Objectif : un jeu qui a l'air **propre et soigné**, dans la famille *Steal a Brainrot* /
*Grow a Garden* / *Pet Simulator 99* : lisible en 2 secondes, peu d'éléments, un style
cohérent, des matériaux Roblox, des couleurs franches mais **maîtrisées**. Le thème du jeu
(la Rift, portail dimensionnel, 5 dimensions) reste.

## 0. Pourquoi la v2 était « moche » (à ne plus faire)

- **Trop de choses à l'écran** : 13 boutons de 13 couleurs différentes, des pastilles
  partout, deux gros boutons en bas en permanence. Effet « arc-en-ciel », rien ne ressort.
- **Typographie criarde** : tout en Luckiest Guy majuscule avec des contours noirs épais.
- **Monde chargé et plat** : 5 000 pièces en SmoothPlastic (aucun matériau), ~2 000 pièces
  néon, murs de base arc-en-ciel, 28 socles gris par base (effet « parking »), décor en vrac.

## 1. Principes

1. **Moins mais mieux.** Chaque écran a un point focal. HUD : 8 éléments permanents maximum.
2. **Un seul style par type d'élément** (toutes les tuiles du HUD identiques, tous les
   boutons d'action identiques). La couleur porte un **sens**, pas de la décoration.
3. **Matériaux Roblox** (Grass, Concrete, Fabric, WoodPlanks, Brick, Slate) plutôt que
   SmoothPlastic partout.
4. **Néon rare** : la Rift, les lasers d'une base verrouillée, l'anneau de rareté des créatures.
5. **Pensé téléphone** : grosses cibles, rien sous le bouton de saut.

Références (recherche web, voir sources dans le README) : *Grow a Garden* place ses boutons
principaux en haut au centre et un bouton Boutique à gauche ; ses stands sont des étals en
bois à toile rayée (bleu/blanc pour les graines, rouge/blanc pour la vente) sur une île
herbeuse. *Steal a Brainrot* : tapis central où défilent les personnages, bases de chaque
côté, boutons Rebirth / Index / Boutique à gauche, verrou de base minuté.

## 2. Interface

### Polices
- **Fredoka One** partout, en casse normale (« Créatures », pas « CRÉATURES »).
- **Luckiest Guy** uniquement pour : le montant d'argent du HUD, les gros textes de
  célébration, les prix et revenus des étiquettes de créatures.

### Couleurs (jetons du Theme)
| Jeton | Valeur | Usage |
|---|---|---|
| Encre | `(28, 31, 58)` bleu nuit | tous les contours (jamais de noir pur) |
| Fenêtre | `(255,255,255)` → `(241,244,250)` | corps des fenêtres |
| Carte | `(244,246,251)`, contour `(217,223,234)` 2 px | cartes dans les fenêtres |
| Texte foncé | `(31, 37, 68)` | texte DANS les fenêtres (sans contour) |
| Texte secondaire | `(110, 118, 150)` | descriptions |
| Marque | `(122, 92, 255)` → `(91, 63, 224)` | en-têtes de fenêtres, sélection, onglets actifs |
| Action / argent | `(47, 203, 85)` → `(31, 165, 68)` | acheter, réclamer, argent |
| Info | `(61, 139, 255)` | navigation |
| Danger | `(255, 77, 77)` | vol, barrière, fermer |
| Récompense | `(255, 201, 60)` | cadeaux, revenus/s |
| Désactivé | `(201, 207, 219)` | boutons indisponibles |

### Éléments
- **Boutons d'action** : hauteur 44–56, coins 12, dégradé léger (haut un peu plus clair),
  rebord inférieur 4 px plus foncé, contour encre 2,5 px, texte blanc Fredoka avec contour
  encre 1,5 px. Couleur selon le sens (vert, bleu, rouge, or, gris).
- **Fenêtres** : 760×520 (hauteur adaptée au contenu), corps blanc, coins 20, contour encre
  3 px, **en-tête violet de marque** de 64 px avec icône + titre Fredoka 30 blanc (contour
  encre 2), bouton fermer rond rouge 44 px avec « X » blanc. Ombre portée douce.
- **Cartes** : fond clair, texte foncé, prix en vert, raretés en pastille colorée.
- **Espacement** : grille de 8 px, marges internes 16–20 px.

### HUD (écran de référence 1280×760)
- **Haut gauche** : argent (icône + `$1.23M` en Luckiest Guy, contour encre) et
  `+$4.32K/s` (or, Fredoka) dessous. Pas de cadre.
- **Haut centre** : une seule pilule d'événement sombre semi-transparente
  (`🔥 Lave · 3:07`, puis `🌪️ 7:11` si la tempête approche).
- **Gauche** : grille 2×3 de **tuiles identiques** 72×72 (fond blanc, contour encre 3 px,
  emoji 34, libellé Fredoka 14 blanc à contour encre sous la tuile) : Boutique, Créatures,
  Index, Quêtes, Rebirth, Plus. **Plus** ouvre un tiroir (grille) : Fusion, Base, Portail,
  Classement, Cadeaux, Récompense du jour, Codes, Inviter. Pastille rouge « ! » sur la
  tuile concernée (ou sur Plus) quand quelque chose est réclamable.
- **Droite** : rien en permanence ; une bulle or « 🎁 Cadeau prêt ! » seulement quand un
  cadeau est réclamable.
- **Bas centre** : uniquement contextuel (barrière quand le joueur est dans sa base,
  bandeau de vol pendant un vol, vengeance quand disponible).
- **Notifications** : cartes blanches avec liseré coloré à gauche, texte foncé.
- **Fil d'actualité** : 3 lignes max, pilules sombres semi-transparentes, texte blanc.

## 3. Monde

Disposition inchangée : tapis rouge nord-sud, Rift au nord, sortie au sud, 4 bases de chaque
côté face au tapis (voir `docs/MAP_BUILD.md`).

| Élément | Matériau | Couleur |
|---|---|---|
| Sol de l'île | Grass | `(93, 181, 71)` |
| Tapis | Fabric | `(200, 32, 47)`, bordures or `(242, 182, 50)` |
| Flèches du tapis | SmoothPlastic (pas néon) | blanc, transparence 0,35 |
| Trottoirs | Concrete | `(207, 207, 214)`, bordures `(233, 233, 238)` |
| Sol des bases | WoodPlanks | `(231, 201, 160)` |
| Murs des bases | Brick | blanc cassé `(240, 237, 230)`, chaperon couleur d'équipe |
| Socles débloqués | Plastic | blanc, anneau fin couleur d'équipe (SmoothPlastic) |
| Socles verrouillés | — | **invisibles** |
| Rift | Slate sombre + vortex | néon autorisé |

- **Bases homogènes** : la couleur d'équipe n'apparaît que sur le chaperon des murs, l'arche
  et le panneau « Base de {nom} ». Murs bas (lisibles par-dessus), piliers d'angle.
- **Décor groupé** : arbres d'un seul style en bosquets sur le pourtour, rochers Slate,
  buissons le long des murs extérieurs (traversables). Pas de fleurs éparpillées partout.
- **Stands** façon *Grow a Garden* sur l'esplanade de la Rift : étals en bois à toile
  rayée avec enseigne (Boutique, Index), qui ouvrent la fenêtre correspondante.
- **Éclairage** : plein jour doux. Future, `ClockTime` 14, `Brightness` 2,2, Atmosphere
  légère (densité 0,28, haze 1,2), ColorCorrection quasi neutre (saturation 0,08, contraste
  0,05), Bloom discret (intensité 0,35, seuil 2,2). Teintes de dimension très légères.

## 4. Créatures

- Garder les modèles ; **moins de néon** (accents en couleur pleine), une seule couleur
  d'accent par créature, rien qui clignote en permanence.
- Étiquette : nom en Fredoka One blanc (contour encre), rareté en Luckiest Guy (dégradé de
  la couleur de rareté, arc-en-ciel pour Secret), revenu `$1.2K/s` en or, prix en vert sur le
  tapis. Contours encre bleu nuit, pas noirs.

| Rareté | Couleur |
|---|---|
| Commun | `(190, 196, 206)` |
| Rare | `(61, 139, 255)` |
| Épique | `(168, 85, 247)` |
| Légendaire | `(255, 190, 30)` |
| Mythique | `(255, 64, 96)` |
| Secret | arc-en-ciel |
