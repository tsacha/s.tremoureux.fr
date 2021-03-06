---
title: "Configuration Emacs"
description: "Résumé de mes personnalisations"
date: 2015-08-06
image:
  caption: Octopus — © Dani Barchana
  captionlink: http://www.pbase.com/dani_barchana
---

Hello,

Un petit billet qui résume deux-trois trucs à partager sur Emacs. Je
ne suis pas développeur Lisp, ce sont juste des choses trouvées sur
Internet. Bizarrement, je n'ai pas croisé beaucoup de ressources
françaises alors j'en profite pour diffuser le savoir dans cette
langue.

Une grande partie de la base de ma configuration est basée sur celle
de [Sacha Chua](http://sachachua.com/blog/), qui en plus de partager
ce super prénom fait un travail remarquable sur Emacs. Le reste est
basé ça et là au fil de mes recherches sur GitHub.

## Emacs Server

Premièrement, Emacs n'est pas l'OS le plus rapide à se lancer, par
chance l'utilisation du mode serveur règle ce souci et apporte un
certain confort en centralisant les buffers.

Disposant de systemd (je suis sous Fedora), j'ai créé un service local
pour mon utilisateur pour lancer le serveur à sa connexion. Dans le
fichier `~/.config/systemd/user/emacs.service` :

{{< highlight text >}}
[Unit]
Description=Emacs: the extensible, self-documenting text editor

[Service]
Type=forking
Environment="SSH_AUTH_SOCK=%h/.gnupg/S.gpg-agent.ssh"
ExecStart=/usr/bin/emacs --daemon
ExecStop=/usr/bin/emacsclient --socket-name /tmp/emacs$(id -u)/server --eval "(progn (setq kill-emacs-hook 'nil) (kill-emacs))"
Restart=always
User=%i
WorkingDirectory=%h

[Install]
WantedBy=default.target
Wants=gpg-agent.service
{{< /highlight >}}

La gestion du service se fera avec les commandes suivantes :

{{< highlight shell >}}
# lancement
systemctl --user start emacs
# arrêt
systemctl --user stop emacs
# mise à jour du fichier de service
systemctl --user daemon-reload
# lancement au démarrage
systemctl --user enable emacs
{{< /highlight >}}

Désormais, au lieu de lancer emacs avec la commande `emacs`, il faut
utiliser `emacsclient`. Je lui passe un argument de socket lié à mon
id d'utilisateur permettant ainsi de faire tourner un serveur par
utilisateur (dans mon cas `sacha` et `root`). J'ai un petit alias dans
`/usr/local/bin/e` :

{{< highlight shell >}}
#!/usr/bin/env bash
emacsclient -c --socket-name /tmp/emacs$(id -u)/server $1
{{< /highlight >}}

À présent, j'ouvre emacs avec `e toto.txt`.

## init.el

Mon fichier de configuration `init.el` tient en une dizaine de lignes :

{{< highlight lisp >}}
;;; init.el — Where all the magic begins
(package-initialize nil)
(add-to-list 'load-path "~/.emacs.d/elisp/use-package")
(add-to-list 'load-path "~/.emacs.d/elisp/org-mode/lisp")
(add-to-list 'load-path "~/.emacs.d/elisp/org-mode/contrib/lisp")
;; Load the rest of the packages
(package-initialize t)
(setq package-enable-at-startup nil)

(require 'org)
(org-babel-load-file (concat (getenv "HOME") "/.emacs.d/sacha.org"))
{{< /highlight >}}

Il se contente de charger `use-package` et Org-mode. Toute la magie
est dans la dernière ligne où est chargé un fichier `.org` qui
contient tout le reste de la configuration.

Au sein de ce fichier, on mêlera du code et la syntaxe Org, permettant
ainsi d'organiser proprement l'ensemble de la configuration. On va
pouvoir y placer des titres, des liens, des commentaires etc… Avantage
supplémentaire GitHub et ses consorts lisent très bien les fichiers
`.org` ([pour le
mien](https://github.com/tsacha/.emacs.d/blob/master/sacha.org)).

## Contenu de `sacha.org`

Sans vouloir faire le listing de toute la configuration, quelques
points peuvent valoir le détour.

### use-package ([source](https://github.com/jwiegley/use-package))

`use-package` est quasiment indispensable pour gérer le chargement
d'un nombre important de paquets. On peut y associer des commandes à
lancer au chargement de ces derniers, des binds à associer…

### org-mode ([source](http://orgmode.org/))

Au delà de gérer ma configuration, j'essaie de plus en plus de me
mettre à org-mode pour gérer la todo list et mon agenda. De plus, j'ai
réussi à ajouter ma propre moulinette d'exportation pour convertir un
fichier .org spécifique en un compte-rendu professionnel (toutes mes
fonctions `org-latex-capensis-*`).

### mu4e ([source](http://www.djcbsoftware.nl/code/mu/mu4e.html))

Ce paquet a changé ma vie. Je gère mes mails uniquement avec ça
désormais. Il est lié à `offlineimap` et me permet de classer très
facilement (beaucoup plus rapidement qu'avec une souris) mon flot de
mails quotidien. Étant adepte d'avoir une boîte de réception vide, je
gagne un temps fou.

Je ne lui ai toujours pas trouvé de défaut, même le GPG tourne très
bien. Ravi d'avoir jeté Thunderbird à la poubelle.

### Magit ([source](https://github.com/magit/magit))

Je découvre, et je commence à l'utiliser sur mes dépôt personnels.
C'est très simple d'utilisation, et on gagne facilement en clarté dans
les opérations courantes. Je n'ai pas encore assez de recul pour les
opérations avancées.


### Bépo ([bepo.fr](http://bepo.fr/wiki/Accueil))

Étant utilisateur du Bépo, le raccourcis claviers déjà pas folichons
en Azerty deviennent encore plus horribles. J'ai adapté la philosophie
de Vim et ses touches de déplacement en `h`,`j`,`k` et `l` à Emacs
en y associant la touche Alt. Je fais tout ça de la main gauche avec
(en Bépo) `M-a`, `M-u`, `M-i`, `M-e`. J'essaie de centraliser les
actions courantes autour de cette zone. De plus, je multiplie au plus
possible les raccourcis sous la forme `M-`.
