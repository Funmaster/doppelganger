#!/usr/bin/ruby

require "webrick"
require "webrick/httpproxy"
require "webrick/httputils"
require "doppelganger"

class WebDistortProxy < WEBrick::HTTPProxyServer
	alias old_proxy_connect proxy_connect
	def proxy_connect(req, res)
		req.createDoppelganger	
		old_proxy_connect(req, res)
	end
end

$server_mapping = nil


class WEBrick::HTTPRequest
	def createDoppelganger
		if $server_mapping == nil
			$server_mapping = Hash.new()
		end

		if $server_mapping[@unparsed_uri] == nil
			host, port = @unparsed_uri.split(":", 2)
			d = Doppelganger.new(:Server => host)	 
			server_info =	d.start
			$server_mapping[@unparsed_uri] = server_info
			puts "-" * 70
			puts "Starting new doppleganger"
			puts "~" * 70
			pp server_info
			puts "-" * 70
			@unparsed_uri = "10.0.1.103:" + server_info[:Port].to_s
		else
			server_info = $server_mapping[@unparsed_uri]
			@unparsed_uri = "10.0.1.103:" + server_info[:Port].to_s
		end		
	end
end


