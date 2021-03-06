---
title: "Compilation et mise en paquet de Libvirt pour Debian"
description: "Une autre dépendance pour gérer les conteneurs LXC."
date: 2013-12-05
image:
  caption: Château-Gontier — CC BY 4.0 Sacha Trémoureux
---

Dans le précédent billet, nous avions mis à jour le noyau de notre serveur,
cette fois-ci, il va falloir faire de même avec libvirt. La gestion de LXC avec
les commandes fournises de base de LXC est un peu fastidieuse. Ayant l’habitude
de gérer mes machines virtuelles KVM avec libvirt, j’ai cherché à en faire de
même pour les conteneurs.

La version de Wheezy est définitivement trop ancienne pour gérer correctement
les conteneurs LXC. On va donc faire un bond vers la dernière version stable.

Parce que Puppet n’est pas un gestionnaire de paquet très performant, il faut
surmonter la paresse de faire un paquet Debian. Sans entrer dans les détails de
la création de paquets .deb dont je maîtrise absolument rien pour l’instant,
voici la procédure en accéleré.

On télécharge et on extrait dans un premier temps les sources :

{{< highlight shell >}}
mkdir /tmp/work
cd /tmp/work
curl http://libvirt.org/sources/libvirt-1.2.1.tar.gz > libvirt_1.2.1.orig.tar.gz
tar xvf libvirt_1.2.1.orig.tar.gz
cd libvirt-1.2.1
{{< /highlight >}}

Puis on créé à l’intérieur un dossier debian :

{{< highlight shell >}}
mkdir debian
{{< /highlight >}}

On peut désormais se lancer dans la création du paquet.

{{< highlight shell >}}
apt-get -y install devscripts # lourd…
dch --create -v 1.2.1 --package libvirt
{{< /highlight >}}

Remplir le fichier d’une façon intelligente…

Dans `debian/control` :

{{< highlight text >}}
Source: libvirt
Maintainer: Sacha Trémoureux <sacha@tremoureux.fr>
Section: admin
Priority: optional
Standards-Version: 1.2.1
Build-Depends: debhelper (>= 9)

Package: libvirt
Architecture: amd64
Depends: ${shlibs:Depends}, ${misc:Depends}
Description: Libvirt static installation
{{< /highlight >}}

Dans `debian/rules` :

{{< highlight text >}}
#!/usr/bin/make -f
%:
		dh $@

override_dh_auto_configure:
		dh_auto_configure -- --prefix=/opt/libvirt
{{< /highlight >}}

Dans `debian/source/format` :

{{< highlight text >}}
3.0 (native)
{{< /highlight >}}

Il faut un fichier `debian/copyright`. À des fins personnelles le contenu n’est
pas très important.

On installe toutes les dépendances pour compiler libvirt :

{{< highlight shell >}}
 apt-get install -y uuid-dev libxml2-dev libdevmapper-dev python-dev libnl-dev pkg-config
{{< /highlight >}}

On lance la compilation :

{{< highlight shell >}}
./configure --prefix=/opt/libvirt
debuild -us -uc -j9
{{< /highlight >}}

Et voilà, on peut intégrer directement à Puppet le paquets généré
(`/tmp/work/libvirt_1.2.1_amd64.deb`). Dans mon dépôt git, on le retrouve
[ici](https://github.com/tsacha/puppet/tree/master/tsacha_hypervisor/files).

Merci à [Florent Peterschmitt](http://florent.peterschmitt.fr) qui m’a donné un
bon coup de main sur toute la procédure.
