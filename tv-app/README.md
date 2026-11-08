# 📺 Ma TV Libre

Application web (HTML/JS, sans installation ni serveur) pour regarder sur votre télévision :

- **Chaînes TV en direct** pour la France et environ 200 pays, à partir des playlists publiques
  [iptv-org](https://github.com/iptv-org/iptv), qui ne recensent que des flux diffusés gratuitement.
  Filtres par pays, catégorie, nom et **qualité** (1080p et plus par défaut, avec un badge Full HD / 4K).
  Listes spéciales : **chaînes Films 24h/24**, **chaînes Séries 24h/24** et **chaînes en français** de tous pays.
  Vous pouvez aussi charger votre propre fichier `.m3u`.
- **Films et séries gratuits et légaux** (Internet Archive) : longs métrages, séries TV classiques, films noirs,
  science-fiction, comédies, films muets, dessins animés, avec un filtre « En français » et un bouton « Plus de résultats ».
- **Plateformes officielles gratuites** : france.tv, ARTE, TF1+, M6+, Pluto TV, Rakuten TV, Plex, Samsung TV Plus…
- Navigation à la **télécommande** (flèches, OK, Retour) et lecture en plein écran.

> Les sites de streaming « gratuits » qui diffusent des films récents sans les droits sont illégaux en France
> (contrefaçon, blocage par l'Arcom) et sont souvent remplis de malwares et de publicités piégées.
> L'application n'utilise donc que des sources légales.

## Utilisation

1. Ouvrez `index.html` dans un navigateur, ou hébergez gratuitement le dossier (GitHub Pages, Netlify…)
   et ouvrez l'adresse obtenue dans le navigateur de votre TV connectée.
2. Sur la TV, vous pouvez aussi utiliser un Chromecast / Google TV, un Fire TV Stick, une Apple TV, ou
   « caster » l'onglet depuis un ordinateur.
3. Si une chaîne ne se lance pas dans le navigateur (protection CORS, géo-restriction, flux hors ligne),
   cliquez sur **Copier l'URL** et ouvrez-la dans **VLC** ou **Kodi**.

## Se passer de la box TV

- Vous aurez toujours besoin d'**Internet** : prenez une offre **fibre seule, sans TV** (souvent moins chère)
  ou une box 4G/5G.
- TNT : avec une antenne râteau et une TV récente, les 25 chaînes gratuites restent accessibles sans box ni Internet.
- Les chaînes nationales sont gratuites en direct sur france.tv, TF1+, M6+, arte.tv, ainsi que dans les applis Molotov, Pluto TV, Samsung TV Plus et LG Channels.

## Taxes sur le streaming (Netflix, YouTube…)

À vérifier sur impots.gouv.fr / service-public.fr, car les lois de finances changent tous les ans :

- **TVA à 20 %**, déjà comprise dans le prix des abonnements.
- **Taxe sur les services de vidéo (TSV, versée au CNC)** : elle est payée par les plateformes (Netflix, Disney+, YouTube…)
  sur leur chiffre d'affaires et leurs recettes publicitaires en France. Vous ne la payez pas directement,
  mais elle peut se répercuter sur le prix des abonnements.
- La **redevance TV** a été supprimée en 2022 : arrêter la box ne crée aucune taxe et ne permet pas d'en économiser une.
- **Projet de « taxe au gigaoctet » (budget 2026, non adopté à ce jour)** : un amendement voté de justesse
  en commission à l'Assemblée prévoit 0,055 € par Go de trafic, payé par les grandes plateformes (Netflix, Google/YouTube,
  Meta, Amazon…) et plafonné à 15 % de leur chiffre d'affaires en France. Les abonnés ne la paieraient pas
  directement, mais les plateformes pourraient augmenter leurs prix pour la répercuter. Le texte peut encore être modifié ou supprimé.
