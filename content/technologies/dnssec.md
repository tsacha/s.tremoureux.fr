---
title: "Configuration de DNSSEC"
description: "Ajout d’une couche de sécurité supplémentaire sur ma zone DNS."
date: 2014-03-11
image:
  caption: Mandal (Norvège)  — CC BY 4.0 Sacha Trémoureux
---

Hello,

J’ai été pas mal occupé depuis quelques semaines et devant la
nécessité de changer de serveur j’ai dû prendre les devants en
accélérant la mise en place de mon nouveau bébé. Je rédige donc les
articles techniques de 2 semaines à 3 mois après la mise en place
réelle des composants de mon infrastructure.

Ce billet fait suite à celui du 3 janvier à propos de Bind9. Après la
mise en place du serveur, il m’a fallu rajouter le support du DNSSEC
sur ma zone tremoureux.fr.

## Génération des clés

La génération des clés n’est pas du ressort de Puppet. Pour l’instant,
je fais encore le travail à la main. DNSSEC demande la génération de
deux paires de clés :

- La ZSK pour signer directement les zones. Elle n’est pas connue du
  registrar.
- La KSK, pour signer la ZSK, est transmise au registrar. Elle servira
  à la validation des enregistrements DNS.

Toute la théorie du protocole est disponible à pas mal d’endroits sur
Internet. Pour la pratique, je me suis servi du wiki d’OVH
[ici](http://help.ovh.co.uk/dnssec).

En résumé :

{{< highlight shell >}}
# On génère la clé KSK. Sans /dev/urandom, patientez une bonne demi-journée.
$ dnssec-keygen -f KSK -a RSASHA512 -b 4096 -n ZONE tremoureux.fr
# On gènère la clé ZSK. Une demi-journée de plus.
$ dnssec-keygen -a RSASHA512 -b 4096 -n ZONE tremoureux.fr
{{< /highlight >}}

Cela effectué, je place les 4 clés (2 publiques, et 2 privées), dans
une classe Puppet privée tsacha_private qui contiendra à peu près
toutes les informations sensibles lors de mon déploiement.

Mes clés publiques sont ensuite incluses dans la zone déployée par
Puppet.

## Signature de la zone

Le très gros avantage de Puppet va être de faciliter la mise
à jour de la zone : la commande `dnssec-signzone` qui doit être
appelée à chaque modification, est totalement automatisée.

{{< highlight shell >}}
exec { "sign-zone":
  command => "dnssec-signzone -e $(date -d '+2 years' '+%Y%m%d130000') -p -t -g -k tremoureux.fr.ksk.key -o tremoureux.fr db.tremoureux.fr tremoureux.fr.zsk.key",
  cwd => "/var/lib/named/etc/bind",
  unless => "test $(cat db.tremoureux.fr.signed | grep -A1 'IN SOA' | tail -n 1 | awk '{print \$1}') -eq $(cat db.tremoureux.fr | grep -A1 'IN SOA' | tail -n 1 | awk '{print \$1}')",
  require => File["/var/lib/named/etc/bind/db.tremoureux.fr"],
  notify => Service["bind9"]
}
{{< /highlight >}}

La grande commande unless, vérifie simplement si l’ID de la zone
signée est identique à la zone en claire. Si ce n’est pas le cas, on
réappele la commande `dnssec-timezone`.

## Le reste

Trois étapes restantes :

- On active le DNSSEC.

Dans `named.conf.options` :

{{< highlight text >}}
dnssec-enable yes;
dnssec-validation yes;
dnssec-lookaside auto;
{{< /highlight >}}

- On inclue la zone signée au lieu de la zone en clair dans
  `named.conf.local`

- On transmet les informations de la KSK à la zone mère. Je vous
  renvoie aux instructions de votre registrar.


Pas grand chose de plus à rajouter. C’est pas si compliqué que ça à
mettre en œuvre.

Le rythme des publications va s’accélérer un peu : il reste 6
conteneurs à décrire encore !
