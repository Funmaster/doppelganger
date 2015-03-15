# Template Files #

Template files can be any type of file. They simply have some predetermined variables replaced at run time.

For example the inject.js.tpl is transformed at runtime to inject.js. All instances of **proxyIPAddr**, **proxyPort**, **httpdIpAddr**, and **httpPort** are replaced with their specified runtime values. It is important to note that the variable names are case sensitive.