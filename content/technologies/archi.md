---
title: "Nouvelle architecture"
description: Importante réorganisation de mes serveurs dédiés
date: 2013-11-19
image:
  caption: Taking Flight at Cape Canaveral — NASA/Bill Ingalls
  captionlink: http://www.nasa.gov/sites/default/files/10933173944_ea869be1c0_o.jpg
---

Salut tout le monde !

Je vais tenter de réanimer mon blog qui n’a pas bien supporté les nombreux
boulversements dans ma vie depuis une année.

Pour partir sur une nouvelle lancée, je comptais faire un petit article pour
décrire tout mon travail que je suis en train d’effectuer sur mes nouveaux
serveurs. Je souhaite en effet mettre en application mes nouvelles compétences
acquises en 6 mois de travail.

Je dispose à l’heure actuelle de trois serveurs :

* Oslo : mon futur serveur de production, doté d’un i7, 8 cœurs cadencés à
  3.40GHz et de 16GB de RAM. Loué chez Hetzner.
* Bergen : mon serveur de « production » actuel doté d’un i3, 4 cœurs cadencés à
  3.40GHz et de 8GB de RAM. Loué chez OVH.
* Tromsø : un serveur de contrôle, doté d’un VIA® Nano® U2250, 1 seul cœur
  cadencé à 1.60GHz et de 2GB de RAM. Loué chez Online.

Le but est de basculer la production de Bergen vers Oslo, et très rapidement de
faire de la haute disponibilité pour les services critiques (mails et web) entre
les deux. Tromsø servira pour le monitoring et hébergera Puppet Master.

Le déploiement automatisé de configuration est difficilement évitable de nos
jours, et même pour une petite architecture personnelle, on y gagne facilement
du temps à moyen/long terme malgré l’implication demandée. J’ai eu l’occasion de
travailler avec Puppet régulièrement pendant quatre mois, je m’oriente donc
vers cette solution. Ansible est peut-être plus justifié pour des petites
structures comme la mienne, mais comme souvent dans ce genre d’exercices, le
choix des technologies est plus lié à des fins didactiques que de scalabilité.

Dans l’ordre, voici les étapes par lesquelles je vais procéder :

* Installation de Tromsø — Première partie : Puppet Master et Puppet Dashboard
* Déploiement automatisé du serveur DNS sur Oslo, puis bascule Bergen -> Oslo
* Même chose pour le serveur web…
* …ainsi que le serveur mail
* Remise à zéro de Bergen
* Déploiement automatisé du serveur secondaire DNS sur Bergen
* Déploiement automatisé d’une solution de haute-disponibilité HTTP entre Oslo
  et Bergen
* Déploiement automatisé d’une solution de haute-disponibilité IMAP entre Oslo
  et Bergen et d’un serveur secondaire SMTP sur Bergen
* Déploiement automatisé d’une solution de supervision sur Tromsø

Je vais détailler petit à petit toutes ses étapes à travers différents petits
billets. La première étape est déjà réalisée, sera bientôt détaillée dans ce
blog renaissant.

À bientôt !

(Je sors de nouveau assez régulièrement au cinéma, je vais essayer de rédiger un
gros billet qui regroupe trois-quatres films vus récemment.)
