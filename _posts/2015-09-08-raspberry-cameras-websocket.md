---
layout: post
title: "Websocket et webcam sur un Raspberry"
description: Tout ça embarqué dans Archlinux
category: technologies
image:
  caption: Mouflon — © Céramique Trémoureux
  captionlink: http://ceramique.tremoureux.fr
---

Hoy,

J'ai été amené à bricoler une sorte de vidéo-surveillance pour mes
parents afin de surveiller à distance les brûleurs et la température
de leur four de céramiste.

Matériellement, je ne me suis pas trop embêté en prenant un Raspberry
Pi 2, j'y ai collé une caméra USB ainsi que la Raspberry Pi Camera.
Pour l'OS, j'étais moyennement chaud pour du Debian alors j'y ai collé
Archlinux.

Mon besoin étant le suivant :

- Résolution correcte en sortie (il faut pouvoir distinguer les
flammes, et le petit affichage de température)
- Gérer les deux caméras en même temps
- Peu d'images par seconde
- Sortie sur le net
- Bande-passante lamentable en upload

J'y ajoute mes contraintes à moi :

- Maintenable
- Pas de bloatware

J'ai fouillé de fond en combles le web, j'y ai trouvé *motion* qui
faisait son boulot correctement en vidéo mais je n'ai pas réussi à
avoir une latence satisfaisante en sortie. J'ai trouvé beaucoup de
bouts de code qui géraient soit la caméra usb, soit celle du
Raspberry. J'ai trouvé quelques usines à Java. D'autres usines à
Node.js. Au fil de mes recherches, j'ai réellement recentré mes
besoins vers de l'image par image. En travaillant à distance, il était
impossible de faire sortir deux flux vidéos en bonne qualité.

J'en suis sorti avec la seule solution de bricoler quelque chose de
moi-même. Je vais décrire tout ça.

## Système

### Installation

J'ai suivi
[cette documentation](http://archlinuxarm.org/platforms/armv7/broadcom/raspberry-pi-2)
pour l'installation de l'OS. Rien de sorcier.

### Configuration IP

Systemd fait le job pour une configuration statique (merci Lennart) :

```
# /etc/systemd/network/eth0.network
[Match]
Name=eth0

[Network]
Address=192.168.1.100/24
Gateway=192.168.1.1
```

### Configuration SSH

J'ai dû générer les certificats SSH serveurs depuis mon laptop pour
pouvoir démarrer du premier coup le serveur SSH.

```
ssh-keygen -f /etc/ssh/ssh_host_rsa_key -t rsa
ssh-keygen -f /etc/ssh/ssh_host_dsa_key -t dsa
ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -t ecdsa
```

### Nom de domaine

IP dynamique oblige, j'ai besoin d'un domaine pour accéder facilement
au serveur depuis l'extérieur. Le serveur que je gère avec
[Florent](http://florent.peterschmitt.fr) se charge de lire un fichier
régulièrement et modifie la conf avec Ansible si besoin. C'est donc au
Raspberry d'envoyer de lui-même son IP.

```
# /opt/sendip.sh

#!/usr/bin/env bash
ssh oleg -C "echo $(dig +short myip.opendns.com @resolver1.opendns.com) > /tmp/ipfegreac.txt"
```

Arch ne contient plus de cron, à systemd de gérer ça (merci
Lennart^2).

```
# /etc/systemd/system/iptooleg.service 
[Unit]
Description=ext ip to oleg

[Service]
ExecStart=/opt/sendip.sh
```
```
# /etc/systemd/system/iptooleg.timer 
[Unit]
Description=ext ip to oleg

[Timer]
OnBootSec=30
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
```

On oublie pas de lancer au démarrage le timer avec `systemctl --enable
iptooleg.timer`.


### Caméras

La Raspberry Pi Camera ne fonctionne pas d'emblée sous Archlinux. Je
ne vais pas réinventer la roue, les explications sont disponibles
[ici](https://wiki.archlinux.org/index.php/Raspberry_Pi#Raspberry_Pi_camera_module).
Le plus dur est de trouver le bon sens dans lequel on branche la nappe
!

### Serveur web (première partie)

J'ai choisi d'installer Nginx. Ça tourne bien, et c'est plus pratique
que Lighttpd pour faire du reverse-proxy.

Génération des certificats :

```
mkdir /etc/nginx/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout \
/etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt
```

Et la première partie de la configuration :

```
# /etc/nginx/nginx.conf

worker_processes  4;

events {
  worker_connections  1024;
}

http {
  include       mime.types;
  default_type  application/octet-stream;
  sendfile        on;
  keepalive_timeout  65;
  gzip  on;

  server {
    listen 443 ssl;
    
    root /usr/share/nginx/html;
    index index.html index.htm;
    
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    
    location / {
      try_files $uri $uri/ =404;
    }
  }


  server {
    listen 80;
    return 301 https://$host$request_uri;
  }

}
```

On lance et on active l'unité systemd pour nginx.

### Des jolies images

Je vais faire de l'image par image. Première partie de la chaîne,
c'est donc de les générer. Après maintes réflexions, c'est *ffmpeg*
qui va gérer tout ça.

Je rajoute une unité systemd pour la première caméra :

```
# /etc/systemd/system/cam0.service

[Service]
ExecStart=/usr/bin/ffmpeg -r 5 -s 1024x576 -y -f v4l2 -i /dev/video0 -q:v 2 -r 0.2 -vf "vflip" -update 1 /usr/share/nginx/html/output0.jpg
User=sacha
Restart=always

[Install]
WantedBy=multi-user.target
```

Et pour la seconde caméra :

```
# /etc/systemd/system/cam1.service

[Service]
ExecStart=/usr/bin/ffmpeg -r 5 -s 1024x576 -y -f v4l2 -i /dev/video1 -q:v 2 -r 0.2 -update 1 /usr/share/nginx/html/output1.jpg
User=sacha
Restart=always

[Install]
WantedBy=multi-user.target
```

J'active au démarrage les deux unités.

Pour décrire les options que je passe à ffmpeg :

- `-r 5` pour lire que les caméras m'envoient le moins de frames par
seconde possible. J'ai pas réussi à descendre plus bas.

- `-s 1024x576`, toujours en entrée, je baisse la résolution à quelque
chose de ni trop petit ni trop grand.
- `-y` pour forcer la réécriture sur le même fichier
- `-f v4l2` -i /dev/videox pour lire les devices
- `-q:v 2` qualité du jpeg en sortie
- `-r 0.2` je ne conserve qu'une frames toutes les 5 secondes
- `-update 1` pour laisser ffmpeg lancé

### Fuyez ! Des technologies web !

Et c'est là que je place sur ma tête ma casquette de développeur web
du dimanche.

Depuis le répertoire `/usr/share/nginx/html`, j'installe quelques
prérequis :

```
npm install fs    # pour lire mes images
npm install watch # pour savoir quand il y a des nouvelles images
npm install ws    # pour envoyer mes images
```

### Un serveur !

```
require('events').EventEmitter.prototype._maxListeners = 100;

var WebSocketServer = require('ws').Server
, wss = new WebSocketServer({ port: 8083 });

var watch = require('watch');
var fs = require('fs');

wss.on('connection', function connection(ws) {
  var url = ws.upgradeReq.url;
  watch.createMonitor('/usr/share/nginx/html/', function (monitor) {
    monitor.files['*.jpg']
    monitor.on("changed", function (f, curr, prev) {
      fs.readFile(f, function read(err, data) {
        if (f.split("/").pop() == url.split("/").pop()) {
          ws.send(data, function(error) {});
        }
      });
    });
  });
});
```

Les explications en vrac : j'écoute en clair sur le 8083. J'ai watch
qui va vérifier la modification de chaques images dans mon répertoire
web. Ensuite en fonction de l'url de websocket fournie par le client,
j'envoie un blob correspondant à l'image modifiée.

### Un client !

Mon index.html simplifié ressemble à ça :

```
<!DOCTYPE html>
<html>
  <head>
    <meta charset=utf-8 />
    <title></title>
    <script type="text/javascript" src="client.js"></script>
    
  </head>
  <body>
    <img height="576" width="1024" id="image0" />
    <img height="576" width="1024" id="image1" />
  </body>
</html>
```

Mon client.js ressemble à ça :

```
function printImage(image,img_id) {
  var ws = new WebSocket('wss://' + window.location.hostname + ':8084/' + image);
  ws.onmessage = function(event) {
      var blob = event.data;
      var img = document.getElementById(img_id)
      var url = URL.createObjectURL(blob);
      img.src = url;
  }
}

printImage('output0.jpg','image0');
printImage('output1.jpg','image1');
```

De cette façon, le client va se connecter sur mon websocket en ssl
(j'y reviens) sur le port 8084 et va gentillement écouter ce que le
serveur va lui dire. L'image est affichée avec la fonction
**createObjectURL** dont j'ai souffert pour apprendre son existance.

## Encore un peu de système

### Serveur websocket

Il faut gérer au démarrage l'exécution du serveur WS. Une énième unité
:

```
# /etc/systemd/system/ws.service

[Service]
ExecStart=/usr/bin/node server.js
WorkingDirectory=/usr/share/nginx/html/
Restart=always
User=sacha

[Install]
WantedBy=multi-user.target
```

On lance et on active.

### Du SSL

C'est Nginx qui va se charger d'encapsuler ça en SSL. Je le configure
pour écouter sur le port 8084 et rediriger le tout vers le 8083.

```
# /etc/nginx/nginx.conf
…
  server {
    listen 8084 ssl;
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    location / {
      proxy_pass http://localhost:8083/;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      # WebSocket support (nginx 1.4)
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    }
  }
…
```

## Conclusion

Et voilà ! Pour un petit projet artisanal je suis très satisfait du
résultat. J'ai réussi à me pencher un peu sur la notion de websocket
qui m'aura évité de faire des méchants reload toutes les 5 secondes ou
bien de faire de l'AJAX.

Nginx a prouvé une nouvelle fois son utilité sur ce genre de projets.

Et on dira ce qu'on voudra, mais systemd fait gagner également un
temps fou. Le raspberry redémarre tranquillement l'ensemble des
services nécessaires au démarrage et en cas de petits problèmes avec
ffmpeg. Pour une petite bécanne qui vise à être oubliée, c'est
agréable.
