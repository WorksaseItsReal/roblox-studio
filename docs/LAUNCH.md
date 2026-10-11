# Lancer Steal a Rift : guide honnête

Ce guide liste ce qu'il reste à faire avant la mise en ligne, les leviers de viralité
déjà intégrés au jeu, et un plan de lancement. Il ne promet pas le succès : aucun
système ne garantit qu'un jeu devienne viral. Le but est de mettre toutes les chances
de ton côté et de **mesurer** au lieu de deviner.

---

## 1. Ce qui manque encore (bloquant ou presque)

| Priorité | Sujet | Pourquoi | Où |
|---|---|---|---|
| 🔴 | **Langue : 100 % français** | La grande majorité des joueurs Roblox ne lit pas le français. Un jeu uniquement en français plafonne fortement son audience, quel que soit son niveau de finition. C'est **le principal frein à la viralité** aujourd'hui. | Tous les textes de l'UI et les messages serveur |
| 🔴 | Ids des Game Passes / Developer Products | Tant qu'un Id vaut `0`, l'achat est désactivé (proprement). | `src/shared/Config/Monetization.luau` |
| 🟠 | Modèles 3D des créatures | Les créatures procédurales sont propres mais simples. Des modèles soignés sont le meilleur gain visuel possible (miniatures, partages, envie de collectionner). | Dossier `ReplicatedStorage.Assets.Creatures` (voir `docs/MAP_BUILD.md`) |
| 🟠 | Groupe Roblox | Le bonus de groupe (+10 % d'argent) est désactivé tant que `GroupId = 0`. | `GameConfig.Social.GroupId` |
| 🟡 | Musique | Aucune musique par défaut (`Id = ""`). Choisis une piste sous licence de la bibliothèque audio Roblox. | `src/shared/Config/Sounds.luau` |
| 🟡 | Questionnaire de maturité / conformité | Obligatoire pour publier. Réponds honnêtement (vol de créatures « cartoon », pas de violence réaliste). | Creator Dashboard |

**Traduction.** Roblox propose une traduction automatique des textes capturés dans
l'interface (Creator Dashboard > Localization). Elle aide pour les textes fixes, mais
gère mal les textes dynamiques (compteurs, montants, noms). Pour viser vraiment le public
anglophone, la solution fiable est une couche de localisation dans le code (tables de
traduction + langue du joueur). C'est la prochaine grosse étape que je recommande.

---

## 2. Tests avant publication

1. **Multijoueur local** : Studio > Test > *Local Server* avec 3 ou 4 joueurs. Vérifier :
   vol + barrière, alarme, vengeance gratuite, fusion, raccourci, tempête (tu peux
   baisser `GameConfig.Storm.IntervalMinutes` pour la déclencher vite, puis remettre 60).
2. **Mobile** : émulateur d'appareil de Studio (téléphone et tablette). Les boutons doivent
   rester cliquables au pouce, rien ne doit être coupé.
3. **Sauvegarde** : activer *Studio Access to API Services*, jouer, quitter, revenir.
   Vérifier argent, créatures, emplacements, index, codes déjà utilisés.
4. **Achats** : avec les vrais Ids, tester chaque pass et produit (les achats en Studio
   ne coûtent rien).
5. **Performance** : 8 joueurs, base pleine, tempête active. Surveiller le *MicroProfiler*
   et la mémoire côté client.

---

## 3. Leviers de viralité déjà intégrés

| Levier | Effet attendu | Réglage |
|---|---|---|
| Vol + vengeance gratuite (90 s) | Moments forts, envie de revanche, clips à partager | `GameConfig.Steal`, `GameConfig.Revenge` |
| Bonus amis (+10 %/ami, max +50 %) + bouton d'invitation | Incite à venir à plusieurs et à inviter | `GameConfig.Social` |
| Bonus de groupe (+10 %) | Fait grossir le groupe = canal pour annoncer les mises à jour | `GameConfig.Social.GroupId` |
| Codes promo | Raison de suivre tes réseaux | `src/server/Config/Codes.luau` (côté serveur, illisible par les tricheurs) |
| Tempête de la Rift chaque heure (HH:30 UTC) | Rendez-vous fixe, tous les serveurs en même temps | `GameConfig.Storm` |
| Récompenses quotidiennes, quêtes du jour, cadeaux de session | Retour quotidien, sessions plus longues | `GameConfig.Daily`, `Config/Quests.luau`, `GameConfig.Playtime` |
| Gains hors ligne (50 %, 8 h max) | Satisfaction au retour | `GameConfig.Offline` |
| Fil d'actualité du serveur, titres au-dessus des têtes, classements géants | Preuve sociale, statut visible | `NameTagService`, `BoardController` |
| Tutoriel guidé + récompense | Moins d'abandons dans les 2 premières minutes | `GameConfig.Tutorial` |

---

## 4. Plan de lancement

**Semaine 0 : test fermé.** 5 à 15 amis. Note chaque bug et chaque moment où quelqu'un
ne comprend pas quoi faire. Corrige avant d'ouvrir.

**Semaine 1 : ouverture.**
- Publie avec l'icône et les 3 miniatures du dossier `marketing/`.
- Crée le groupe, renseigne `GroupId`, annonce un code de lancement (ex. `LANCEMENT`).
- Poste 2 ou 3 clips courts par jour (TikTok, YouTube Shorts) : un vol réussi au dernier
  moment, une fusion qui donne une mutation Céleste, une tempête avec portail doré.
  Le format qui marche : accroche dans la première seconde, 10 à 20 secondes, texte à l'écran.

**Semaines 2 à 4 : rythme.**
- Une mise à jour par semaine, même petite (nouvelle créature, nouveau code, équilibrage).
  Change le titre de la page avec la mise à jour (ex. « [🌀 MAJ 3] Steal a Rift »).
- Contacte de petits créateurs de contenu Roblox (quelques milliers d'abonnés) : ils
  répondent plus souvent et leur public est très engagé. Offre-leur un code personnalisé.
- Si tu as un budget : campagnes sponsorisées via l'Ads Manager de Roblox. Commence petit
  et compare le coût par joueur qui revient le lendemain, pas seulement le coût par clic.

**À surveiller (Creator Dashboard > Analytics) :** rétention à J1 et J7, durée moyenne de
session, taux de clic des miniatures, conversion en payeurs. Ne change qu'une chose à la
fois pour savoir ce qui a eu de l'effet.

**Miniatures :** alterne plusieurs versions et compare le taux de clic (outils de test du
Creator Dashboard s'ils sont disponibles pour ton expérience, sinon une version par semaine).

---

## 5. Règles à respecter

- **Probabilités visibles** : la Boutique affiche les chances par rareté (avec et sans
  chance boostée). Garde-les à jour si tu modifies `Config/Rarities` ou `Odds`.
- **Pas de promesse trompeuse** sur la page ou dans les miniatures (montre ce qui existe
  vraiment dans le jeu).
- **Musique et sons** : uniquement des pistes sous licence ou que tu possèdes.

---

## 6. Description de la page Roblox

### Français

> 🌀 **STEAL A RIFT** 🌀
>
> Une faille dimensionnelle crache des créatures rares… à toi de les attraper !
>
> 💰 Achète des créatures sur le tapis de la Rift : elles rejoignent ta base et te rapportent de l'argent chaque seconde.
> 🦹 **Vole** les créatures des autres joueurs et ramène-les chez toi avant qu'on te rattrape !
> 🛡️ Active ta **barrière** pour protéger ta base, puis prends ta **revanche** gratuitement.
> 🧬 **Fusionne** deux créatures identiques pour obtenir une mutation jusqu'à x5.
> 🌪️ Chaque heure (à la demi-heure), la **Tempête de la Rift** triple la chance et ouvre un portail doré !
> 🔥 5 dimensions • 40 créatures • 6 raretés, jusqu'aux créatures **Secrètes**.
>
> 👥 Joue avec tes amis : +10 % d'argent par ami sur le serveur !
> 🔑 Codes : RIFT • PORTAIL

### English

> 🌀 **STEAL A RIFT** 🌀
>
> A dimensional rift is spitting out rare creatures… catch them before anyone else!
>
> 💰 Buy creatures from the Rift conveyor: they walk to your base and earn you money every second.
> 🦹 **Steal** other players' creatures and carry them home before you get caught!
> 🛡️ Raise your **barrier** to protect your base, then take your **revenge** for free.
> 🧬 **Fuse** two identical creatures to unlock mutations up to x5.
> 🌪️ Every hour (at half past), the **Rift Storm** triples your luck and opens a golden portal!
> 🔥 5 dimensions • 40 creatures • 6 rarities, up to **Secret** creatures.
>
> 👥 Play with friends: +10% money per friend in your server!
> 🔑 Codes: RIFT • PORTAIL

⚠️ La description anglaise promet un jeu en anglais : tant que l'interface est en
français, garde uniquement la version française (ou ajoute la localisation d'abord).
