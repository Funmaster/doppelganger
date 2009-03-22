#!/usr/bin/ruby

require "net/http"
require "pp"

print "Content-type: text/plain\r\n\r\n"
#ENV.keys.sort.each{|k| puts "#{k} ==> #{ENV[k]}"}

request_method = ENV["REQUEST_METHOD"]
$path_info = ENV["PATH_INFO"]
query_string = ENV["QUERY_STRING"]
cookie = ENV["HTTP_COOKIE"]
$host = ENV["HTTP_HOST"]
request_uri = ENV["REQUEST_URI"]
port = ENV["SERVER_PORT"]

if request_method == "GET"
	url = URI.parse(request_uri)
	req = Net::HTTP::Get.new(url.path)
	res = Net::HTTP.start(url.host, url.port) {|http|
		http.request(req)
	}
	puts res.body
end

if request_method == "POST"
	print request_method
end

