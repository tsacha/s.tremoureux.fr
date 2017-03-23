function process(input,img_id,type) {
    var ws = new WebSocket('wss://' + window.location.hostname + ':8084/' + input);
    ws.onmessage = function(event) {
	var blob = event.data;
	var url = URL.createObjectURL(blob);
	if(type=="svg") {
	    var oldobject = document.getElementById(img_id);
	    var object = document.createElement('object');
	    object.setAttribute("type","image/svg+xml");
	    object.setAttribute("height",576);
	    object.setAttribute("width",1024);
	    object.setAttribute("id",img_id);	    
	    object.data = url;
	    document.body.replaceChild(object,oldobject);
	}
	if(type=="csv") {
	    var reader = new FileReader();
	    reader.readAsText(blob);
	    reader.onload = function(event) {
		var contents = event.target.result.split("\n");
		var curData = contents[contents.length - 2].split(";");
		var object = document.getElementById("up");
		object.innerHTML = curData[1];
		var object = document.getElementById("down");
		object.innerHTML = curData[2];		
	    };
	}
	else {
	    var img = document.getElementById(img_id);	    
	    img.src = url;
	}
    }
}
process('output0.jpg','image0');
process('data.svg','image2','svg');
process('data.csv','','csv');
