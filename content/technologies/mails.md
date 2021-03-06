---
title: "Serveur mail sous Debian"
description: "Configuration d’un serveur mail : Dovecot, Postfix, LDAP et autres commodités"
date: 2014-03-12
image:
  caption: "© Candy Hansen — NASA/JPL-Caltech/Univ. of Arizona"
  captionlink: http://www.uahirise.org/ESP_035033_2635
---

Coucou,


Un très très très long billet dont la longueur ne sera pas habituelle.

J’enchaîne la description de l’installation des différents services de
mon serveur dedié. Aujourd’hui on passe par le classique serveur
mail. Vu que — pour une fois — je n’étais pas trop pressé, j’ai eu le
temps de faire ce que que je voulais à la base. Au programme donc, un
cocktail assez traditionnel :

- Dovecot en MTA : ça fonctionne bien, la configuration est
  relativement simple (le split de Debian fait des merveilles), et on
  peut aller relativement loin sans se prendre la tête.
- Postfix en MUA : ça juste marche. L’interfaçage avec Dovecot n’est
  pas sorcier (et peut se faire de façons assez variées).
- OpenLDAP pour l’authentification qui sera installé sur un autre
  conteneur. C’est pas très utile pour le peu de comptes dont je
  dispose (3), mais c’était plus à des fins d’apprentissage. LDAP fait
  un peu moins peur une fois maîtrisé. Je m’en servirai également pour
  mon serveur XMPP.
- SpamAssassin : depuis le passage à la frontière, mon serveur
  allemand se fait bombarder de spam, il faut être en mesure de gérer
  ça.
- Sieve et ManageSieve pour le tri automatique des mails. C’est déjà
  intégré à Dovecot, il faut en profiter. Ça fait des merveilles.
- Le webmail sera traîté dans la partie web à venir.

Il y a un peu plus de matière que pour les DNS, je vais essayer de
rentrer un peu dans les détails. Gardez à l’esprit que mes classes
Puppet
([tsacha_mail](https://github.com/tsacha/puppet/tree/master/tsacha_mail)
et
[tsacha_ldap](https://github.com/tsacha/puppet/tree/master/tsacha_ldap))
servent de bonne documentation. Malgré le manque de commentaires, on y
entrevoit assez facilement la chronologie de l’installation.

## Pré-requis d’une authentification mail avec OpenLDAP

Pour centraliser un peu l’authentification, je vais passer par un
LDAP situé sur un conteneur séparé.

### Configuration d’OpenLDAP

Sous Debian, l’installation n’est pas très compliquée : on va avoir
besoin d’installer slapd pour le serveur, et ldap-utils pour manipuler
l’annuaire.

Au niveau de la configuration, on doit activer les protocoles voulus
dans
[/etc/default/slapd](https://raw.github.com/tsacha/puppet/master/tsacha_ldap/templates/slapd.default.erb). Disposant
de certificats valides, déployés par Puppet, et n’étant pas
spécialement concerné par des problématiques de performances, je
conserve seulement le LDAPS (distant) et le LDAPI (local).

Pour les clients LDAP, on peut être un peu plus rigoureux sur la
vérification du certificat en modifiant
[/etc/ldap/ldap.conf](https://raw.github.com/tsacha/puppet/master/tsacha_ldap/templates/ldap.conf.erb).

Voilà, c’est à peu près tout pour les fichiers à plat. La
configuration de LDAP étant stockée elle-même dans un arbre LDAP,
l’essentiel des réglages s’effectura à coups de LDIF.

### Configuration de l’annuaire LDAP

Pour ces opérations, je suis pas spécialement fier de
[ma classe
Puppet](https://raw.github.com/tsacha/puppet/master/tsacha_ldap/manifests/install.pp)
. C’est adapté pour un premier déploiement mais pour le test & repair
ce n’est pas encore ça.

Premièrement, il ne faut perdre d’esprit que c’est une installation
silencieuse, nous devons donc oublier le joli assistant d’installation
du paquet slapd. Par défaut, les réponses en matière de suffixe LDAP
sont assez éloignées de mon but : dc=localhost n’est pas
satisfaisant.

La configuration du certificat est à inscrire dans `cn=config` ainsi
que la modification les ACL pour que mes futurs services puissent
accéder aux comptes utilisateurs, sans oublier quelques index bien
placés.

Toutes ces opérations sont centralisées dans un seul fichier
[config.ldif](https://raw.github.com/tsacha/puppet/master/tsacha_ldap/templates/config.ldif.erb)
qui sont appliquées par le biais d’une connexion en LDAPI.

{{< highlight bash >}}
/etc/init.d/slapd restart
ldapmodify -Y EXTERNAL -H ldapi:/// -f config.ldif
{{< /highlight >}}

Toujours dans `cn=config`, j’en profite pour changer le mot de passe
admin grâce à un second LDIF
[pass-db.ldif](https://raw.github.com/tsacha/puppet/master/tsacha_ldap/templates/pass-db.ldif.erb). Je
stocke dans puppet le hash du mot de passe fourni par `slappasswd`.

{{< highlight bash >}}
# ldapmodify -Y EXTERNAL -H ldapi:/// -f pass-db.ldif
{{< /highlight >}}

Au niveau des vérifications faites par Puppet, je contrôle si le
domaine est bien changé avec une interrogation en LDAPI et j’effectue
en connexion en LDAPS sur le compte admin LDAP pour tester le mot de
passe.

{{< highlight bash >}}
ldapsearch -LLL -Y EXTERNAL -H ldapi:/// -b olcDatabase={1}hdb,cn=config | grep 'olcSuffix: dc=ldap,dc=s,dc=tremoureux,dc=fr'
ldapsearch -H ldaps://ldap.s.tremoureux.fr/ -x -D 'cn=admin,dc=ldap,dc=s,dc=tremoureux,dc=fr' -w '$tsacha_private::ldap::ldap_password' -b 'dc=ldap,dc=s,dc=tremoureux,dc=fr'
{{< /highlight >}}

### Modification du schéma inetOrgPerson

Je vais stocker mes adresses mails dans un schéma inetOrgPerson mais
pour avoir des redirections fonctionnelles j’ai besoin de rajouter un
champ mailAlias qui contiendra toutes les adresses mails secondaires
d’une personne.

Mon schéma est disponible
[ici](https://raw.github.com/tsacha/puppet/master/tsacha_ldap/templates/extend.ldif.erb). Je
l’applique ensuite naturellement dans `cn=schema`. Puppet vérifiera la
bonne importation en regardant la présence ou non de mailAlias.

### Création de l’arbre LDAP

Une fois tous les prérequis terminés, il faut recréer les bases de
l’arbre LDAP. Je passe par un
[script](https://raw.github.com/tsacha/puppet/master/tsacha_ldap/templates/create-db.sh.erb)
pour faciliter l’écritures des règles Puppet.

Ce script va détruire l’arbre installé par Debian (avec la mauvaise
racine localhost), et en recréer [un tout
beau](https://raw.github.com/tsacha/puppet/master/tsacha_ldap/templates/db.ldif.erb). Je
change ensuite le mot de passe du compte admin de l’arbre (à ne pas
confondre avec le compte admin LDAP modifié plus haut).

La vérification de l’application de ce script passe par une
authentification en LDAPS sur l’arbre avec l’utilisateur
`cn=admin,dc=ldap,dc=s,dc=tremoureux,dc=fr`.

{{< highlight bash >}}
ldapsearch -H ldaps://ldap.s.tremoureux.fr/ -x -w '$tsacha_private::ldap::admin_password' -D cn=admin,dc=ldap,dc=s,dc=tremoureux,dc=fr -b dc=ldap,dc=s,dc=tremoureux,dc=fr | grep 'dn: cn=admin,dc=ldap,dc=s,dc=tremoureux,dc=fr'
{{< /highlight >}}

Voilà, c’est à peu près tout pour LDAP.

## Configuration complète de Dovecot en liaison avec LDAP

### Installation de Dovecot

La mise en place de Dovecot va nécessiter les paquets suivants :

- ldap-utils
- dovecot-imapd
- dovecot-ldap
- dovecot-lmtpd (j’y reviendrai)
- dovecot-sieve
- dovecot-managesieved

L’installation de ces paquets est décrite
[ici](https://raw.github.com/tsacha/puppet/master/tsacha_mail/manifests/packages.pp).

### Configuration de Dovecot

J’utilise une [recette
Puppet](https://raw.github.com/tsacha/puppet/master/tsacha_mail/manifests/dovecot.pp)
pour déployer tous les fichiers de configurations de Dovecot. Rien à
signaler au niveau de sa rédaction. En revanche, ces fichiers de
configurations sont intéressants à décrire.

Je passe en revue les paramètres généraux :

#### [dovecot.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/dovecot.conf.erb)

- On oublie pas l’IPv6 : `listen = *, ::`
- Toute la magie est dans la ligne `!include conf.d/*.conf` inclue
  dans Debian par défaut.


Tous les fichiers suivants sont situés dans /etc/dovecot/conf.d/ :


#### [10-mail.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/10-mail.conf.erb)


- On place les mails là où on veut : `mail_home = /srv/mail/%u` et
  `mail_location = maildir:/srv/mail/%u`.
- J’utilise un utilisateur UNIX qui est le propriétaire de l’ensemble
  des boîtes mails. J’autorise uniquement son UID et son
  GID. `first_valid_uid = 5000`, `last_valid_uid = 5000`,
  `first_valid_gid= 5000`, `last_valid_gid = 5000`.


#### [10-master.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/10-master.conf.erb)

On désactive l’IMAP et on active l’IMAPS

{{< highlight text >}}
inet_listener imap {
  port = 0
}

inet_listener imaps {
  port = 993
  ssl = yes
}
{{< /highlight >}}

La liaison entre Postfix et Dovecot va passer par LMTP (plus
  performant que LDA).

{{< highlight text >}}
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
	group = postfix
	mode = 0666
	user = postfix
  }
}
{{< /highlight >}}

#### [10-ssl.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/10-ssl.conf.erb)

On active et on spécifie l’emplacement des certificats.

#### [15-ldap.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/15-lda.conf.erb)

Ce fichier sert égalemement pour le LMTP.

- Quelques paramètres cosmétiques tels que `postmaster_address`,
  `hostname`.
- Je décommente `recipient_delimiter = +` pour gérer les adresses
  telles que user+folder@domain.tld (très pratique).
- On active la création automatique des boîtes mails
  `lda_mailbox_autocreate = yes`, et leur abonnemement
  `lda_mailbox_autosubscribe = yes`.

Je rajoute également Sieve aux plugins :

{{< highlight text >}}
protocol lda {
  mail_plugins = $mail_plugins sieve
}
{{< /highlight >}}

#### [15-mailboxes.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/15-mailboxes.conf.erb)

- Selon les besoins, on décommente les dossiers nécessaires.

#### [20-imap.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/20-imap.conf.erb)

- En 2014, avec la multitude de terminaux, la limite
  `mail_max_userip_connections` peut être un peu juste. J’ai l’ai un
  peu élevé.

#### [20-lmtp.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/20-lmtp.conf.erb)

- On rajoute Sieve dans les plugins.
- On gère le `+` en activant `lmtp_save_to_detail_mailbox`

#### [20-managesieve.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/20-managesieve.conf.erb)

ManageSieve est un [protocole](http://tools.ietf.org/html/rfc5804)
pour permettre de gérer ses filtres Sieve à distance.

- On vérifie simplement qu’il écoute bien sur le port 4190.

#### [90-sieve.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/90-sieve.conf.erb)

Ici, quelques paramètres liés à l’arborescence du serveur :

- `sieve_default = /srv/mail/default.sieve`
- `sieve_dir = ~/sieve`

### Liaison à LDAP

Premièrement, on active d’authentification avec LDAP.

#### [/etc/dovecot/conf.d/10-auth.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/10-auth.conf.erb)

- On décommente `!include auth-ldap.conf.ext`

#### [/etc/dovecot/conf.d/auth-ldap.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/conf.d/auth-ldap.conf.ext.erb)

Dans ce fichier on spécifie comment utiliser LDAP. La recherche des
utilisateurs est dans le bloc `userdb`.

{{< highlight text >}}
userdb {
  driver = ldap
  args = /etc/dovecot/dovecot-ldap.conf.ext
  default_fields = uid=vmail gid=vmail
}
{{< /highlight >}}

Je surcharge l’UID et le GID pour être en accord avec mon utilisateur
vmail qui est indépendant de la boîte.

Pour l’authentification, c’est dans le bloc `passdb`. J’y spécifie le
même fichier de configuration.

{{< highlight text >}}
passdb {
  driver = ldap
  args = /etc/dovecot/dovecot-ldap.conf.ext
}
{{< /highlight >}}

#### [/etc/dovecot/dovecot-ldap.conf.ext](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dovecot/dovecot-ldap.conf.ext.erb)

C’est ici que tout se passe. En enlevant tous les commentaires
(verbeux) ça nous donne ça :

{{< highlight text >}}
uris = ldaps://ldap.s.tremoureux.fr/
dn = cn=dovecot,dc=ldap,dc=s,dc=tremoureux,dc=fr
dnpass = <%= scope.lookupvar('tsacha_private::ldap::dovecot_password') %>
auth_bind = no
base = ou=users,dc=ldap,dc=s,dc=tremoureux,dc=fr
scope = subtree
user_attrs =
user_filter = (&(objectClass=person)(mail=%u))
pass_attrs = mail=user,userPassword=password
pass_filter = (&(objectClass=person)(|(mail=%u)(mailAlias=%u)))
{{< /highlight >}}

J’utilise la configuration décrite dans la documentation officielle [à
cette
adresse](http://wiki2.dovecot.org/AuthDatabase/LDAP/PasswordLookups)
en adaptant à ma sauce les recherches pour prendre en compte mes
alias. Je peux ainsi me log en IMAP avec des adresses un peu plus
courte que mon adresse courante.

### Peuplement de l’annuaire LDAP

Après la configuration de Dovecot, il lui faut des données à
exploiter. Nous devons rajouter [à coups de
LDIF](https://raw.github.com/tsacha/puppet/master/tsacha_mail/files/dovecot/dovecot.ldif)
un utilisateur dans LDAP pour Dovecot.

À noter l’ajout d’une OrganizationalUnit qui contient tous mes
utilisateurs.

Du côté de Puppet, ces ajouts sont fait depuis le compte admin de
l’arbre. Le mot de passe du compte de Dovecot est réactualisé si
l’authentification avec ce dernier ne se passe pas.

Les boîtes mails — qui ne sont pas publiées sur Git — ont cette forme :

{{< highlight text >}}
dn: uid=sacha,ou=users,dc=ldap,dc=s,dc=tremoureux,dc=fr
cn: Sacha Trémoureux
givenName: Sacha
sn: Trémoureux
uid: sacha
mail: mail@domain.tld
mailAlias: m@domain.tld
mailAlias: postmaster@domain.tld
userPassword: {SSHA}graou
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
{{< /highlight >}}

C’est à peu près tout pour Dovecot.

## Configuration de Postfix en liaison avec Dovecot

Next : Postfix.

Encore une fois l’installation n'est pas le problème et se résume à
[l'installation des
paquets](https://raw.github.com/tsacha/puppet/master/tsacha_mail/manifests/packages.pp)
et au [placement des fichiers de
configuration](https://raw.github.com/tsacha/puppet/master/tsacha_mail/manifests/postfix.pp)
au bon endroit. Les alias et les adresses virtuelles de Postfix sont
regénérés par Puppet en cas de modification.

Voici le détail des fichiers de configuration :

#### [/etc/postfix/main.cf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/postfix/main.cf.erb)

La majorité des réglages se fait ici. Je ne vais pas revenir sur
l'ensemble des directives, un bon nombre de tutoriaux le fera mieux
que moi. Les quelques points spécifiques à mes choix d'infrastructure
sont les suivants :

- On oublie pas les certificats : `smtpd_tls_key_file`,
  `smtpd_tls_key_file` et `smtpd_tls_key_file`.
- La gestion des alias doit utiliser les mailAlias de mon annuaire
  LDAP. La configuration est faite grâce à la directive suivante :
  `virtual_alias_maps`.

La gestion des DKIM se fait avec un service situé sur le même
conteneur. Je passe donc par un socket pour la communication entre
Postfix et OpenDKIM.

{{< highlight text >}}
# DKIM
milter_default_action = accept
milter_protocol = 6
smtpd_milters = unix:/var/run/opendkim/opendkim.sock
non_smtpd_milters = unix:/var/run/opendkim/opendkim.sock
{{< /highlight >}}

C'est Dovecot qui va authentifier pour le compte de Postfix.

{{< highlight text >}}
#enable SMTP auth for relaying
smtpd_sasl_auth_enable       = yes
broken_sasl_auth_clients     = yes
smtpd_sasl_type              = dovecot
smtpd_sasl_path              = private/auth
{{< /highlight >}}

Et c'est toujours Dovecot qui va placer les mails au bon endroit grâce
à LMTP.

{{< highlight text >}}
mailbox_transport = lmtp:unix:private/dovecot-lmtp
local_recipient_maps =
{{< /highlight >}}

#### [/etc/postfix/master.cf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/postfix/master.cf.erb)

Le fichier `master.cf` centralise la gestion des processus intervenant
dans Postfix.

On active Submission (port 587) :

{{< highlight text >}}
submission inet n       -       -       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
{{< /highlight >}}

On active Spamassassin. En haut :

{{< highlight text >}}
smtp      inet  n       -       -       -       -       smtpd
  -o content_filter=spamassassin
{{< /highlight >}}

Et en bas !

{{< highlight text >}}
spamassassin unix -     n       n       -       -       pipe
		user=debian-spamd argv=/usr/bin/spamc -f -e
		/usr/sbin/sendmail -oi -f ${sender} ${recipient}
{{< /highlight >}}

#### [/etc/postfix/ldap-virtual.cf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/postfix/ldap-virtual.cf.erb)

Ce fichier décrit comment trouver des alias dans LDAP. En entrée,
Postfix effectue la requêté spécifiée par la directive `query_filter`
et sélectionnera en sortie le champ mail décrit par `result_attribute`
pour connaître le propriétaire de l'alias.

Et voilà pour Postfix.

## Montrer patte blanche en sortie avec OpenDKIM et SPF

Deux solutions complémentaires sont à utiliser pour certifier que
notre serveur mail est bien légitime lors de l'envoi de mail depuis un
domaine spécifique.

### SPF

La première est SPF : dans la zone du domaine en question, nous
ajoutons un champ particulier qui contient la liste des IP des
serveurs autorisés à émettre du mail avec ce domaine.

Sur mon domaine voilà le résultat :

{{< highlight bash >}}
dig tremoureux.fr TXT +short
"v=spf1 ip4:87.98.218.210 ip4:91.121.61.39 ip6:2001:41d0:1:49d2::/64 ip4:176.9.119.5 ip6:2a01:4f8:151:7307:1::4 -all"
{{< /highlight >}}

Le `-all` prévient que tous les serveurs mails émettant des mails sous
tremoureux.fr ne sont pas autorisés à le faire. Libre ensuite aux
autres serveurs les recevant d'accepter ou non le mail.

### Configuration d'OpenDKIM

La seconde solution est un peu plus longue à mettre en place est
DKIM. Cela consiste à signer une partie des corps des messages la
placer dans les en-tête. La clé publique est diffusée par DNS ensuite
sur les domaines concernés. Le serveur recevant le mail vérifie
compare ensuite ce nouvel en-tête avec le corps du message. Si il y a
corrélation, il va avoir tendance à considérer le mail comme légitime.

Sous Debian le paquet `opendkim` sert à effectuer ce travail. Sa
configuration est disponible
[ici](https://raw.github.com/tsacha/puppet/master/tsacha_mail/manifests/dkim.pp).

Sur le même schéma que précédemment, voici la description des fichiers
de configuration :

#### [/etc/default/opendkim](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dkim/default_opendkim.conf.erb)

Vu que Postfix est OpenDKIM tournent sur le même conteneur, j'ai jugé
bon de ne pas ouvrir un énième port. On va juste placer le socket dans
un endroit accessible à Postfix (qui tourne dans un chroot par
défaut).

{{< highlight text >}}
SOCKET="local:/var/spool/postfix/var/run/opendkim/opendkim.sock"
{{< /highlight >}}

Attention aux droits dans ces dossiers : Postfix doit pouvoir y
accéder.

#### [/etc/opendkim/opendkim.conf](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dkim/opendkim.conf.erb)

Pas grand chose à signaler dans ce fichier de configuration
principal. On spécifie juste où est le reste :

{{< highlight text >}}
KeyTable           /etc/opendkim/KeyTable
SigningTable       /etc/opendkim/SigningTable
ExternalIgnoreList /etc/opendkim/TrustedHosts
InternalHosts      /etc/opendkim/TrustedHosts
{{< /highlight >}}

#### [/etc/opendkim/TrustedHosts](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dkim/TrustedHosts.erb)

Ici on place simplement la liste des domaines acceptés, séparés par
des retour à la ligne.

#### [/etc/opendkim/KeyTable](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dkim/KeyTable.erb)

On y place la liste des emplacements des clés privées de chacun des
domaines :

{{< highlight text >}}
default._domainkey.domain.tld domain.tld:default:/etc/opendkim/keys/domain.tld/default.private
{{< /highlight >}}

Dans le cas où on dispose de plusieurs serveurs SMTP, on peut avoir
une clé par serveur. Ici, ce n'est pas mon cas, ma clé s'appelle donc
default.


#### [/etc/opendkim/SigningTable](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/dkim/SigningTable.erb)

Ici, on référence quel domaine utilise quelle clé :

{{< highlight text >}}
domain.tld default._domainkey.domain.tld
{{< /highlight >}}

Voilà pour la configuration.


### Génération des clés DKIM

Après la configuration d'OpenDKIM, il nous faut générer une paire de
clés pour chaque domaine géré.

{{< highlight bash >}}
mkdir -p /etc/opendkim/keys/domain.tld
cd /etc/opendkim/keys/domain.tld
opendkim-genkey -r -d domain.tld
chown -R opendkim:opendkim /etc/opendkim
{{< /highlight >}}

La commande `opendkim-genkey` génère la clé publique sous un format
assez original : la ligne à placer directement dans le fichier de
zone du domaine en question.

En action :

{{< highlight bash >}}
dig default._domainkey.tremoureux.fr TXT +short
"v=DKIM1\; k=rsa\; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDJBOzCOLJHGTIJhxZMlqUMg+YlMmgMozSOGcPixoqV9zAw6kSSPJ3GDNoxAjYi8NooRrlKalF0ZFDyTVdkJJz6ETpPUjgQfEoEGrIHIlvRPaiZXk0/umkqeW2WIxDN56Mrt8N269IaL/GoVyeMjx4zO9PRF4uUkZyz0ICmBCH2kQIDAQAB"
{{< /highlight >}}

Et voilà !

## L'antispam avec Spamassasin (et une dose de Sieve)

Comme d'habitude je passe l'installation simplissime de
Spamassassin. L'intégration à Postfix a été déjà effectuée
précédemment. Le reste du travail est disponible
[ici](https://raw.github.com/tsacha/puppet/master/tsacha_mail/manifests/spamassassin.pp).

- On place à 1 le flag `START` et le flag `CRON` dans
  `/etc/default/spamassassin`
- Dans `/etc/spamassassin/v320.pre` j'active `Shortcircuit` pour
  arrêter l'analyse du mail si il a déjà un score assez élevé.

#### [/etc/spamassassin/local.cf.erb](https://raw.github.com/tsacha/puppet/master/tsacha_mail/templates/spamassassin/local.cf.erb)

Ici, quelques configurations assez générales à rajouter.

- Activation du filtrage bayésien avec `uses_bayes` et
  `bayes_auto_learn`
- Configuration de Shortcircuit

### Déplacement automatique des Spams

Avec Sieve la règle est la suivante :

{{< highlight text >}}
require ["fileinto"];
# Move spam to spam folder
if header :contains "X-Spam-Flag" ["YES"] {
  fileinto "Junk";
  stop;
}
{{< /highlight >}}

J'ai placé cette règle dans le fichier de script par défaut. Elle
s'applique donc à tous mes comptes.

### Apprentissage automatique

Pour renforcer au fil du temps la lutte contre les spams, il est
préférable de donner régulièrement à manger à Spamassassin. J'ai donc
un cron qui passe quotidiennement dans les boîtes mails et apprendre
de l'ensemble des dossiers Spam des utilisateurs. J'ai prévenu les
quelques personnes que j'héberge de faire attention au contenu de
celle-ci.

Je dispose également d'une adresse mail qui sert pour les
faux-positifs. Les utilisateurs forward les mails à cette adresse et
Spamassassin essaiera de corriger le tir les prochaines fois.

Le cron en question :

{{< highlight bash >}}
#!/bin/sh
sa-learn --spam /srv/mail/*\@*/.Junk/cur
sa-learn --ham /srv/mail/ham@domain.tld/{cur,new}
{{< /highlight >}}

## Conclusion

Je crois qu'on a fait le tour.

Une architecture mail est en général assez compliquée : un grand
nombre de briques logicielles sont imbriquées entre-elles.

Une fois encore, mon infrastructure est conçue ainsi avant tout à des
fins d'entraînement mais elle fonctionne parfaitement pour mes maigres
besoins. Du tunning est sûrement nécessaire si on augmente de nombre
de comptes.

Plus on raconte de choses, plus grandes sont les chances de raconter
des bêtises. Si des points vous sautent aux yeux, n'hésitez-pas à me
contacter par mail ou Jabber.

La suite sera moins épaisse !
