---
layout: post
title: "Déploiement de Libvirt, LXC et Openvswitch"
description: "Description des classes Puppet s’occupant de la base de l’architecture."
category: technologies
updated: 2014-01-03
image:
  feature: norvege-balestrand.jpg
  caption: Balestrand, Norvège — CC BY 3.0 Sacha Trémoureux
  h: 350px
  x: 100%
  y: 65%
  captionlink: /images/norvege-balestrand.jpg
---

Maintenant que notre serveur dispose des prérequis pour faire tourner LXC, il
nous reste à déployer l’ensemble de la configuration pour obtenir une base de
virtualisation légère utilisable. Je vais me lancer dans les explications des
classes Puppet que j’utilise pour cette tâche. L’article est donc à lire avec
les [sources](https://github.com/tsacha/puppet) à côté.


# Généricités 

La première des choses que je déploie sur le serveur est une réorganisation des
dépôts pour Debian afin de permettre le pinning depuis Testing ou encore la
gestion des dépôts de Puppetlabs. J’installe également quelques logiciels de
base tels que Emacs et DBus. Ces deux tâches sont stockées dans une classe
system qui est plutôt générique et qui est appellée dans à peu près tous mes
serveurs et conteneurs.

# Installation du réseau

## Variables Puppet

Dans Puppet Dashboard, `oslo.s.tremoureux.fr` dispose des variables suivantes :

* ip_private_address : 10.1.0.1
* gateway6 : fe80::1
* cidr6 : 64
* dns : [213.133.99.99, 213.133.100.100, 213.133.98.98, 2a01:4f8:0:a0a1::add:1010, 2a01:4f8:0:a111::add:9898, 2a01:4f8:0:a102::add:9999]
* cidr_private : 16
* gateway : 176.9.119.1
* ip_address : 176.9.119.5
* ip6_address : 2a01:4f8:151:7307::2
* ip_range_private : 10.1.0.0
* cidr : 27

## Openvswitch

J’ai besoin ensuite de configurer le réseau du serveur pour être en mesure de
faire communiquer mes futurs conteneurs. Pour cela, j’utilise Openvswitch qui
sera au cœur de mon réseau virtuel. Par défaut dans Debian, Openvswitch ne
démarre qu’après la mise en route du réseau ; un comportement que je souhaite
modifier puisque mon interface physique sera directement raccordée au bridge
virtuel. 

Ainsi, l’ordre des opérations est le suivant :

* Installation d’OVS et ses dépendances (ethtool)
* Remplacement du script d’init avec
  [celui modifié par mes soins](https://raw.github.com/tsacha/puppet/master/tsacha_containers/templates/ovs-init.erb)
* Modification des runlevels d’OVS
* Lancement d’OVS


## Parefeu & NAT

Mes conteneurs communiqueront avec l’extérieur en IPv4. Quelques opérations
sommaires sont à déployer :

* Activation du forwarding IPv4 (avec sysctl, et sysctl.conf)
* Règles de masquerade dans iptables, avec la configuration au démarrage du
  parefeu. J’utilise
  [un petit script](https://raw.github.com/tsacha/puppet/master/tsacha_containers/templates/network_iptables.erb)
  qui est activé avant le démarrage des interfaces réseaux pour cela (`/etc/network/if-pre-up.d/iptables`).
  
## Création des interfaces virtuelles

S’en suit logiquement la création des interfaces virtuelles.

### `br-ex`

* Création de `br-ex`, mon bridge qui est directement relié à mon interface
  physique `eth0`. Mes conteneurs utiliseront directement ce bridge pour discuter
  en IPv6.
* Activation, et création de l’adressage IP de `br-ex`.
* Liaison d’`eth0` à `br-ex` : opération à risque, il y a une perte de
  connectivité temporaire pendant la bascule.
* Modification des règles de routage pour faire transiter le trafic vers `br-ex`.
* Nettoyage des adresses IP d’`eth0`.

### `br-int`

On répète à peu près les mêmes étapes :

* Création de `br-int`, un bridge qui servira à avoir un réseau privé IPv4 pour
  les conteneurs.
* Activation et création de l’adressage IP de `br-int`.

## Conservation au démarrage 

Le fichier `/etc/network/interfaces` est modifié en conséquences pour tenir
compte de ces modifications.

# Déploiement de LXC

Une fois le réseau prêt, on peut s’attaquer à LXC. Dans l’ordre, ma classe
Puppet effectue les tâches suivantes :

* Installation d’un LXC « relativement » récent via Jessie
* Installation des dépendances de Libvirt
* Déploiement d’un rc.local pour monter automatiquement les cgroups au démarrage
* Exécution du rc.local
* Téléchargement de libvirt et installation
* Remplacement de quelques fichiers de configuration pour libvirt
* Téléchargement d’un script de génération de conteneur

Les
[sources Puppet](https://github.com/tsacha/puppet/blob/master/tsacha_containers/manifests/lxc.pp)
sont plutôt claires concernant cette partie. Quelques petits points d’ombres
sont tout de même à éclaircir.

## Montage des cgroups

Pour permettre l’isolation des processus, LXC nécessite que les cgroups soient
montés. La façon dont ils sont montés dans Debian Wheezy semble quelque peut
incompatible avec les dernières versions de libvirt. Nous sommes légèrement
obligés de tricher pour parvenir à nos fins. La
[documentation de libvirt](http://libvirt.org/cgroups.html#createNonSystemd)
décrit plus ou moins la procédure.

## Modifications diverses de libvirt

Mon
[dossier templates](https://github.com/tsacha/puppet/tree/master/tsacha_containers/templates)
dispose de quelques fichiers de configuration. À retenir :

* J’utilse LXC par défaut pour les commandes de Virsh.
* Le fichier init de libvirt doit tenir compte de l’installation dans
  `/opt/libvirt/`. 
* Je désactive le TLS pour libvirtd.


# Utilisation de LXC & LibVirt

J’utilise
[un script](https://raw.github.com/tsacha/puppet/master/tsacha_containers/templates/generate_container.rb.erb)
en Ruby pour la génération des conteneurs.

Ce qu’il faut retenir, c’est que pour avoir un conteneur fonctionnel, il faut en
base un système opérationnel. Dans le cas d’un conteneur sous Debian,
`debootstrap` fait très bien ce travail. Je place également les interfaces
réseaux en configuration statique. Je prépare dès la génération du conteneur
l’installation d’un Puppet Agent avec le serveur maître communiqué par un
argument. La dernière étape est de générer un template XML pour LibVirt.

Tout ça en action maintenant :

    # génération du conteneur
    /srv/generate_container.sh test oslo.s.tremoureux.fr 10.1.0.2 255.255.0.0 \
    10.1.0.1 2a01:4f8:151:7307:1::1 64 fe80::1 8.8.8.8 tromso.s.tremoureux.fr
    # lancement
    /opt/libvirt/bin/virsh start test
    
    
Petit test de connectivité :

    root@oslo /srv # ssh 10.1.0.2
    root@10.1.0.2's password: 
    Linux test.oslo.s.tremoureux.fr 3.10.22 #2 SMP Fri Dec 6 16:19:02 CET 2013
    x86_64
    
    The programs included with the Debian GNU/Linux system are free software;
    the exact distribution terms for each program are described in the
    individual files in /usr/share/doc/*/copyright.
    
    Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
    permitted by applicable law.
    root@test:~# ping6 google.fr
    PING google.fr(fra02s20-in-x1f.1e100.net) 56 data bytes
    64 bytes from fra02s20-in-x1f.1e100.net: icmp_seq=2 ttl=56 time=5.57 ms
    64 bytes from fra02s20-in-x1f.1e100.net: icmp_seq=3 ttl=56 time=5.50 ms
    64 bytes from fra02s20-in-x1f.1e100.net: icmp_seq=4 ttl=56 time=5.46 ms
    ^C
    --- google.fr ping statistics ---
    4 packets transmitted, 3 received, 25% packet loss, time 3011ms
    rtt min/avg/max/mdev = 5.462/5.514/5.574/0.046 ms
    root@test:~# ping google.fr
    PING google.fr (173.194.113.63) 56(84) bytes of data.
    64 bytes from fra02s20-in-f31.1e100.net (173.194.113.63): icmp_req=1 ttl=55
    time=5.60 ms
    64 bytes from fra02s20-in-f31.1e100.net (173.194.113.63): icmp_req=2 ttl=55
    time=5.44 ms
    ^C
    --- google.fr ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1001ms
    rtt min/avg/max/mdev = 5.445/5.524/5.603/0.079 ms
    
Et voilà. Nous allons pouvoir attaquer les applications la prochaine fois.
