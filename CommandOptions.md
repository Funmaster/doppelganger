# Doppelganger Options #

## Server Options ##

**-w `[PORT]`, --webport `[PORT]`**

Configures the Doppelganger HTTP Server to listen on the specified port. If no port is provided, port 80 is used as a default.

**-p `[PORT]`, --proxyport `[PORT]`**

Configures the Doppelganger Proxy Server to listen on the specified port. If not port is provided, port 8080 is used as a default.

**--domain `[DOMAIN]`**

The domain used to create a WPAD entry.

**--nameserver `[ADDRESS]`**

The name server of the specified domain.

**--wpadhost `<ADDRESS>`**

Specify the IP of the wpad host to be entered into DNS. If no address is given Doppelganger will attempt to determine the IP address of the current host.

## Javascript Library Options ##

Each of the options below loads the respective Javascript Library & version from Google APIs into modified pages. For more information see http://code.google.com/apis/ajaxlibs/documentation/index.html#AjaxLibraries

**--jquery `[VERSION]`**

**--jqueryui `[VERSION]`**

**--prototype `[VERSION]`**

**--scriptaculous `[VERSION]`**

**--mootools `[VERSION]`**

**--dojo `[VERSION]`**

**--swfobject `[VERSION]`**

**--yui `[VERSION]`**

**--extcore `[VERSION]`**

## Javascript Options ##

**-j `[file1,file2...fileN]` , --javascript `[file1,file2...fileN]`**

Accepts a list of custom Javascript files to be loaded from the Doppelganger HTTP server. List must be a comma delimited list with no spaces. Files can be Javascript files or [Template](Template.md) files.

**-s, --pack**

Packs the custom scripts and includes them in the page inline, instead of referring to them by URL.

## Misc. Options ##
**-e `[FILE]`, --exlude `[FILE]`**

File containing list of URLs to excluded when mimicing. If this option or the include option is omitted, all URLs will be mimiced.

**-i `[FILE]`, --include `[FILE]`**

File containling list of URLs to be mimiced. If this option or the exclude option is omitted, all URLs will be mimiced.