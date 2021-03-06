---
title: "Puppet Master et Puppet Dashboard"
description: Première partie de la réinstallation de mes serveurs  — Puppet
date: 2013-11-21
lastmod: 2013-12-27
image:
  caption: Celebrating Fifteen Years of the International Space Station — NASA
  captionlink: http://www.nasa.gov/sites/default/files/sts088-343-025.jpg
---

Hello,

Un court billet pour décrire un peu l’installation de Tromsø, mon serveur de
contrôle. La supervision ne se fera qu’à la fin, donc au programme aujourd’hui,
seulement Puppet et Puppet Dashboard. Le serveur est installé sous Debian 7 Wheezy.

## Connectivité IPv6

Un petit prérequis cependant : le serveur étant chez Online.net il faut
installer Dibbler pour la configuration IPv6 du serveur.

Dans `/etc/dibbler/client.conf` :

{{< highlight text >}}
log-level 8

duid-type duid-ll
iface eth0 {
  pd
  option dns-server
  option domain
}
{{< /highlight >}}

Et on place le DUID fourni par Online.net dans `/var/lib/dibbler/client-duid`.
On lance Dibbler et on ne s’en occupe plus. Je conserve tout de même un
adressage statique dans `/etc/network/interfaces` :

{{< highlight text >}}
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet static
  address 195.154.64.154
  netmask 24
  gateway 195.154.64.1

iface eth0 inet6 static
  address 2001:bc8:3350:100::1
  netmask 56
{{< /highlight >}}

## Installation de Puppet


On utilise les dépôts officiels pour installer Puppet.

{{< highlight shell >}}
wget http://apt.puppetlabs.com/puppetlabs-release-wheezy.deb
dpkg -i puppetlabs-release-wheezy.deb
apt-get update
apt-get install puppet
{{< / highlight >}}

Pour que Puppet se lance au démarrage, il faut éditer `/etc/default/puppet` :

{{< highlight text >}}
START=yes
{{< / highlight >}}

Ça suffira pour l’installation de base de Puppet.

## Puppet Dashboard

Puppet Dashboard va servir principalement en tant qu’ENC pour Puppet : chacun de
mes hôtes nécessite des varibles dont les valeurs lui sont propres : adresse IP,
hostname… pour avoir un déploiement réellement personnalisé des services. Plus
important : on doit renvoyer également les classes à exécuter sur le nœud.
Puppet peut prendre en entrée un script d’ENC qu’il va appeller avec le hostname
du nœud à provisionner en argument. Ce script devra renvoyer un fichier YAML
avec les valeurs correspondantes et les classes appellées. La documentation est
située [ici](http://docs.puppetlabs.com/guides/external_nodes.html).

Coder un tel script demande un peu de temps et je n’ai pas besoin de disposer
d’une telle flexibilité. Puppet Dashboard se chargera de ce rôle à merveille au
sein d’une petite interface web sympathique.


Pour l’installer :

{{< highlight shell >}}
apt-get install puppet-dashboard mysql-server
{{< / highlight >}}

On le greffe au démarrage en éditant `/etc/default/puppet-dashboard` ainsi que
`/etc/default/puppet-dashboard-workers`.

{{< highlight text >}}
START=yes
{{< / highlight >}}

Quelques modifications sommaires dans l’installation de base de MySQL :

{{< highlight shell >}}
$ mysql_secure_install
{{< / highlight >}}

On édite `/etc/mysql/my.cnf` :

{{< highlight text >}}
max_allowed_packet = 32M
{{< / highlight >}}

On va avoir besoin d’une base de données pour le dashboard :

{{< highlight sql >}}
CREATE DATABASE puppet_dashboard CHARACTER SET utf8;
CREATE USER 'puppetdash_user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON puppet_dashboard.* TO 'puppetdash_user'@'localhost';
flush privileges;
{{< / highlight >}}

Il faut mettre en concordance le dashboard et MySQL, éditons
`/etc/puppet-dashboard/database.yml` :

{{< highlight text >}}
production:
  database: puppet_dashboard
  username: puppetdash_user
  password: pass
  encoding: utf8
  adapter: mysql
{{< / highlight >}}

Malheureusement Puppet Dashboard souffre un peu avec Ruby 1.9, il faut donc
downgrade à la 1.8.1…

{{< highlight shell >}}
aptitude install -y build-essential irb libmysql-ruby \
libmysqlclient-dev libopenssl-ruby libreadline-ruby mysql-server \
rake rdoc ri ruby ruby-dev

update-alternatives --install /usr/bin/gem gem /usr/bin/gem1.8 1
rm /etc/alternatives/ruby
ln -s /usr/bin/ruby1.8 /etc/alternatives/ruby
rake gems:refresh_specs
{{< / highlight >}}

On peut enfin remplir la base :

{{< highlight shell >}}
cd /usr/share/puppet-dashboard
rake RAILS_ENV=production db:migrate
{{< / highlight >}}

Après lancement des services, on peut accéder à l’interface en HTTP sur le
port 3000. Il faudra sécuriser ça avec Apache un peu plus tard !

## Lier Puppet et Puppet Dashboard

En dernière étape on a besoin d'indiquer à Puppet d'utiliser Puppet Dashboard
pour à la fois envoyer les rapports et également l'utiliser en tant qu'ENC.

Dans le fichier `/etc/puppet/puppet.conf` du Master :

{{< highlight text >}}
[master]
	reports = store, http
	reporturl = http://localhost:3000/reports/upload
	node_terminus = exec
	external_nodes = /usr/bin/env PUPPET_DASHBOARD_URL=http://tromso.s.tremoureux.fr:3000 /usr/share/puppet-dashboard/bin/external_node
{{< / highlight >}}
