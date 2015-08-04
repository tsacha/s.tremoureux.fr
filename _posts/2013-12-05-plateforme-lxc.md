---
layout: post
title: "Installation d’une plateforme destinée à héberger des conteneurs LXC"
description: "Installation du serveur « Oslo », d’un noyau récent, et de Puppet Agent."
category: technologies
order: 0
image:
  feature: nantes-erdre.jpg
  caption: Bords de l'Erdre à Nantes de nuit — CC BY-SA 3.0 <a href='http://commons.wikimedia.org/wiki/User:Pymouss44'>Pymouss44</a>
  captionlink: http://commons.wikimedia.org/wiki/File:Nantes_Erdre-01.jpg?uselang=fr
---

# Installation d’Oslo

Avant de pouvoir déployer nos conteneurs, nous allons essayer d’avoir un serveur
opérationnel et en mesure d’héberger tous nos conteneurs.

Le monstre étant chez Hetzner, cette première partie est un peu spécifique à
l’hébergeur en question. On se retrouve plus bas pour la partie plus
intéressante.

On lance la procédure d’installation :

    installimage

On sélectionne Debian, la 64 bits, en minimal. Pour le partionnement je place
une partition de boot en ext2 d’une vingtaine de GB en début de disque dur,
j’apprécie d’avoir de la marge sur cette partition puisqu’elle peut me servir de
zone de test. Le reste est occupé par un VG. Au sein du VG, je place un swap de
20G, et une grande partition / en ext4 qui prend le reste.

Au final dans l’install.conf ça nous donne ceci pour les lignes à modifier :

    HOSTNAME oslo.s.tremoureux.fr
    
    PART /boot ext2 20G
    PART lvm oslo all

    LV oslo swap swap swap 20G
    LV oslo root / ext4 all
    
Ensuite F2 pour sauvegarder, F10 pour continuer, yes, yes, I will destroy the
world, confirm. À la fin de l’installation on peut redémarrer la bécanne.

# Préparation d’un noyau

Nous allons utiliser OpenVSwitch pour le réseau virtuel, nous avons également
besoin de quelques ajouts dans les cgroups par rapport au noyau de base de
Debian Wheezy pour LXC. Il nous faut donc un noyau fait-maison.

Je prends pour base le dernier noyau stable en date (3.12.2) sur
[kernel.org](http://kernel.org).

    curl https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.12.2.tar.xz > kernel.txz
    tar xvf kernel.txz

Restant sur une base Debian et n’ayant pas spécialement envie d’en dévier, je
vais utiliser les fichiers de configuration du paquet
[linux-image-3.11-2-amd64](http://packages.debian.org/fr/jessie/linux-image-3.11-2-amd64)
de Debian pour avoir une base correcte. Pour avoir un fichier de configuration à
jour, je prends le paquet de Jessie.

    mkdir deb
    curl http://ftp.de.debian.org/debian/pool/main/l/linux/linux-image-3.11-2-amd64_3.11.8-1_amd64.deb > deb/linux.deb
    apt-get update && apt-get install -y binutils
    cd deb
    ar x linux.deb
    tar xvf data.tar.xz
    cp boot/config-3.11-2-amd64 ../linux-3.12.2/.config
    cd ../linux-3.12.2

On peut désormais modifier la recette de cuisine.

    apt-get install -y build-essential libncurses5-dev kernel-package zlibc bc
    make menuconfig

* Dans `General Setup/Control Group Support`, j’ai tendance à activer tout ce qui n’est pas marqué comme étant du debugging. 
* Dans `General Setup/Namespaces support`, j’active `User namespaces`. Si nous
  souhaitons installer la version 3.10 du noyau, il faut pour cela désactiver
  totalement XFS dans les filesystems.

On sauvegarde désormais `.config` et on lance dans la compilation.

    make-kpkg clean
    make-kpkg --initrd --revision=3.12.2 -j9 kernel-image kernel-headers
    


Une fois la compilation terminée, une sauvegarde des deux .deb est appréciée
pour l’avenir.

    cd ..
    scp linux-*deb tromso.s.tremoureux.fr:~/

Et on installe :

    dpkg -i linux-*deb
    
Et on redémarre.

    reboot

Une fois la machine relancée, une petite vérification pour vérifier que l’on est
sur le bon noyau.

    uname -a
    
    Linux oslo.s.tremoureux.fr 3.12.2 #3 SMP Thu Dec 5 09:23:11 CET 2013 x86_64
    GNU/Linux
    
# Installation de Puppet Agent

Le dernier prérequis pour que le serveur soit prêt à être configuré est
l’installation de Puppet Agent. Pour cela, nous avons juste à rajouter le dépôt
de PuppetLabs.

    curl http://apt.puppetlabs.com/puppetlabs-release-wheezy.deb > puppetlabs-release-wheezy.deb
    dpkg -i puppetlabs-release-wheezy.deb
    apt-get update

On peut désormais installer Puppet.

    apt-get -y install puppet

Dans la section `[main]` de `/etc/puppet/puppet.conf` :

    server = tromso.s.tremoureux.fr

Dans `/etc/default/puppet`, on peut passer `START=no` à `START=yes` pour activer
Puppet au démarrage du serveur. Ensuite, on lance le provisionning à la main :

    puppet agent --test
    
Parallèlement sur le serveur Puppet, il faut signer le certificat.

    root@tromso:/# puppet ca sign oslo.s.tremoureux.fr
    
On relance le provisionning puisque le précédent à échoué faute de certificat
valide.

    puppet agent --test
    
Et voilà.
