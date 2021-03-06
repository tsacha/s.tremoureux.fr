---
title: "Déploiement de Bind9 avec Puppet"
description: "Suite logique de l’infrastructure : les DNS."
date: 2014-01-03
image:
  caption: Two Solar Flares Say Goodbye 2013 and Welcome 2014 — © NASA/SDO
  captionlink: http://www.nasa.gov/content/goddard/two-solar-flares-say-goodbye-2013-and-welcome-2014/
---
Hi,

On commence l’année par la reprise des travaux sur ma petite infrastructure
personnelle. Nous en sommes au stade où nous pouvons poser le premier conteneur
pour gérer nos entrées DNS. Nous reviendrons au DNSSEC dans quelques jours, le
temps que je mette en place de quoi stocker de façon sûre les clés (c’est à dire
hors de mon dépôt GitHub). Mais avant ça, il y a déjà de quoi occuper.

## Préparation du conteneur

Première étape : il faut créer sur la machine hôte le conteneur qui contiendra
le serveur DNS. Pour cela, j’ai rajouté une classe
[tsacha_hypervisor::dns](https://github.com/tsacha/puppet/blob/master/tsacha_hypervisor/manifests/dns.pp)
à mon module hypervisor dans Puppet. À l’intérieur, je fais appel à mon script
de génération de conteneurs avec les arguments qui vont bien. Les variables sont
toujours remplies avec Puppet Dashboard.

Avant de démarrer le conteneur, je lui greffe quelques dossiers qui nous
serviront plus tard ainsi que les deux blocs qui vont servir à chrooter Bind. Il
m’est en effet impossible de faire un `mknod` depuis le conteneur, j’en profite
donc d’être à l’extérieur pour le faire.

## Provisionning du conteneur

Lors de la génération du conteneur, j’ai bien fait attention de lancer Puppet au
démarrage du système. Il demandera donc automatiquement sa configuration au
serveur Puppet et pourra être configuré automatiquement et dès le début, sans
intervention humaine. Un léger prérequis : le hostname du conteneur doit être
dans le fichier `/etc/puppet/autosign.conf` du Puppet Master. À noter la
possibilité d’utiliser des jokers :

{{< highlight text >}}
*.oslo.s.tremoureux.fr
oslo.s.tremoureux.fr
{{< /highlight >}}

## Déroulement de l’installation de Bind

Puppet Dashboard est configuré pour appeler un nouveau module
[tsacha_dns](https://github.com/tsacha/puppet/blob/master/tsacha_hypervisor/manifests/dns.pp). Toutes
les opérations qu’il effectue sont basées sur le wiki de Debian sur Bind9
disponible [ici](https://wiki.debian.org/fr/Bind9). Dans l’ordre :


   * Installation du paquet Bind9
   * On tue le service Bind lancé automatiquement : Bind n’est pas encore
	 correctement configuré
   * Création de toute une arborescence visant à contenir le chroot de Bind
   * Copie des fichiers de configurations modifiés par mes soins
	 (`named.conf.*`, les zones)
   * Pour les autres fichiers de configuration, on reprend le contenu de ceux
	 présents sur le système
   * Modification du script d’init pour qu’il prenne en compte le nouveau
	 répertoire où est placé le pidfile
   * Modification du fichier `/etc/default/bind9` pour que Bind soit lancé en
	 mode chroot.
   * Démarrage du service

Et voilà pour cette partie !
