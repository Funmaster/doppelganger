#!/usr/bin/ruby

require "webrick"
require "webrick/https"
require "pp"
require "openssl"

class Doppleganger
	@server = nil
	@host = nil
	@port = nil
	@pid = nil

	@server_config = nil

	def create port
		@server = WEBrick::HTTPServer.new(
			:ServerName => @host,
			:Port => port,
			:SSLEnable => true,
			:SSLVerifyClient => ::OpenSSL::SSL::VERIFY_NONE,
			:SSLCertName => [['C', 'US'], ['O', @host], ['CN', @host], ['OU', rand(65535).to_s]],
			:DocumentRoot => "/tmp")
		
		@server.mount("/", WEBrick::HTTPServlet::CGIHandler, "./fetch_ssl.rb")
	end
	
	def initialize(config)
		@host = config[:Server]
		@port = 0
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
end



