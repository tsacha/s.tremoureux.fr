---
layout: post
title: "Reconnaissance d'image et relevés de température"
description: Parce qu’une sonde qui communique c’était trop demandé.
category: technologies
image:
  caption: Hubble Shears a "Woolly" Galaxy — © ESA/Hubble & NASA and S. Smartt (Queen's University Belfast)
  captionlink: https://www.nasa.gov/image-feature/goddard/hubble-shears-a-woolly-galaxy
---

Hello,

Deuxième partie de mes bricolages avec le Raspberry. Une fois la
capture d'image réalisée, j'ai tenté d'automatiser le relevé des
températures sur les deux sondes reliées au four. Problème de taille :
la sonde ne communique pas vers un quelconque protocole, et mes
connaissances en électronique de suffiraient pas pour tenter quelque
chose. Je me suis donc contenté des images et d'essayer de faire de
l'OCR.

Après quelques tests j'utilise le logiciel ssocr trouvé
[ici](https://www.unix-ag.uni-kl.de/~auerswal/ssocr/) adapté aux
affichages 7 segments. Il me donne des meilleurs résultats que
d'autres logiciels plus généralistes.

Premièrement, l'image à analyser est celle-ci :

{% picture blog blog/7s_1.jpg %}

Afin de faciliter le travail du logiciel de reconnaissance, je découpe
l'image au bon endroit :

{% picture blog blog/7s_2.jpg %}
    convert output1.jpg -crop 165x63+345+185

J'applique ensuite une fonction de seuil pour supprimer les reflets,
simplifier l'image en ne conservant que du noir et blanc.

{% picture blog blog/7s_3.jpg %}
    convert output1.jpg -crop 165x63+345+185 -threshold 97%

L'image précédente me suffisait pour avoir des captures correctes dans
90% des cas. J'obtenais en revanche des erreurs sur les 3 et les 8.
Après quelques expérimentations, j'ai réussi à améliorer ce résultat
en redressant l'image.

{% picture blog blog/7s_4.jpg %}

    convert output1.jpg -crop 165x63+345+185 -threshold 97% -background black -shear -9,0

Je passe cette dernière image à la moulinette `sssocr` en lui
précisant que le nombre de digits peut varier et que c'est du blanc
sur du noir.

    ssocr -d -1 -b black -f white - 

Voilà pour la reconnaissance d'image. J'exécute ensuite cette commande
pour les deux zones représentant les deux compteurs à chaque mise à
jour de l'image exportée par ma caméra.

    while inotifywait -e close_write output1.jpg; do
        …
    done;

J'ai de temps à autre des ratés, le compteur peut mettre un peu de
temps à afficher un chiffre la caméra prenant une photo en mauvais
moment. Il peut y avoir des reflets à un moment donné ou encore une
simple erreur de capture. Pour réduire au maximum ces erreurs, je
vérifie tout d'abord de bien capturer un nombre positif (ssocr peut
sortir des nombres négatifs) et je vérifie que la différence avec la
capture précédente ne dépasse pas 3°C. En 5 secondes il est quasiment
impossible qu'une telle montée de température se produise. J'exporte
ensuite les résultats dans un fichier CSV horodaté.

Pour éviter de surexploiter Libreoffice, j'utilise ensuite Gnuplot qui
fait le travail pour générer un beau graphique.

Le script se chargeant de tout ça est lancé directement au démarrage
du Raspberry. L'horodatage des fichiers CSV/SVG permet de s'assurer
une rotation des données. Le dernier fichier en date pointe vers
data.csv/svg et est envoyé au navigateur via mon WebSocket. J'ai
effectué quelques modifications à ce dernier pour ne pas envoyer de
fichiers vides, Gnuplot ayant la fâcheuse habitude d'effacer le
fichier sur lequel il travaille avant de l'éditer.

Les scripts en questions sont disponibles ici :

- [client.js](/scripts/client.js)
- [server.js](/scripts/server.js)
- [ocr.sh](/scripts/ocr.sh)
 
