require('events').EventEmitter.prototype._maxListeners = 100;

var WebSocketServer = require('ws').Server
, wss = new WebSocketServer({ port: 8083 });

var watch = require('watch');
var fs = require('fs');

wss.on('connection', function connection(ws) {
    var url = ws.upgradeReq.url;
    watch.createMonitor('/usr/share/nginx/html/', function (monitor) {
	monitor.files['*.jpg','*.svg','*.csv']
	monitor.on("changed", function (f, curr, prev) {
	    fs.readFile(f, function read(err, data) {
		if (f.split("/").pop() == url.split("/").pop()) {
		    if(data.length > 0) {
			ws.send(data, function(error) {});
		    }
		}
	    });
	});
    });
});
