#!/usr/bin/ruby

require "cgi"
require "net/http"
require "net/https"
require "pp"

cgi = CGI.new
pp cgi

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
	print "Content-type: text/plain\r\n\r\n"
	ENV.keys.sort.each{|k| puts "#{k} ==> #{ENV[k]}"}
pp ARGV
	uri = URI.parse(request_uri)

	http = Net::HTTP.new(uri.host, uri.port)
   	http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
    	http.start {
      	http.request_post(uri.path, $query_string) {|res|
		content_type = "Content-type: " + res['content-type'] + "\r\n\r\n"
		print content_type
		print res.body
     	 }
    	}

end

