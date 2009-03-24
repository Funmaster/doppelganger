#!/usr/bin/ruby

require "cgi"
require "net/http"
require "net/https"
require "pp"

cgi = CGI.new

#print "Content-type: text/plain\r\n\r\n"
#ENV.keys.sort.each{|k| puts "#{k} ==> #{ENV[k]}"}

request_method = ENV["REQUEST_METHOD"]
$path_info = ENV["PATH_INFO"]
$query_string = ENV["QUERY_STRING"]
cookie = ENV["HTTP_COOKIE"]
$host = ENV["HTTP_HOST"]
request_uri = ENV["REQUEST_URI"]
port = ENV["SERVER_PORT"]

if request_method == "GET"
	uri = URI.parse(request_uri)

	http = Net::HTTP.new(uri.host, uri.port)
   	http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
    	http.start {
      	http.request_get(uri.path) {|res|
					content_type = "Content-type: " + res['content-type'] + "\r\n\r\n"
					print content_type
					print res.body
     	 }
    	}

end

if request_method == "POST"	
	#print "Content-type: text/plain\r\n\r\n"
	 
	#pp cgi
	#ENV.keys.sort.each{|k| puts "#{k} ==> #{ENV[k]}"}

	query_string = ""

	cgi.params.keys.each {|key|	query_string += "#{key}=#{cgi.params[key]}&"	}

	query_string.chop!



	uri = URI.parse(request_uri)

	http = Net::HTTP.new(uri.host, uri.port)
   	http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
    	http.start {

				post_path = uri.path
				if $query_string != ""
					post_path += "?#{$query_string}"
				end

      	http.request_post(post_path, query_string) {|res|		
					content_type = "Content-type: " + res['content-type'] + "\r\n\r\n"
					print content_type
					print res.body
     	 }
    	}

end

