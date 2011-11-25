#!/usr/bin/python

import gzip

import cStringIO

from twisted.web import server, resource, http
from twisted.web.proxy import Proxy, ProxyRequest, ProxyClient, ProxyClientFactory
from twisted.internet import reactor
		
class DoppelProxyClient(ProxyClient):
	def __init__(self, *args, **kwargs):
		ProxyClient.__init__(self, *args, **kwargs)
		self.buffer = ""
		self.test = "<html><head><title>Doppelganger</title></head><body></body></html>"

	def handleHeader(self, key, value):
		'''print "[ '", key, "': ", value, "]"''' 
		ProxyClient.handleHeader(self, key, value)
		
	def handleResponsePart(self, buffer):
		self.buffer += buffer
		ProxyClient.handleResponsePart(self, buffer)
		
	def handleResponseEnd(self):
		if not self._finished:
		
		'''self.father.responseHeaders.setRawHeaders("content-length", [len(self.test)])
	
		
		data = gzip.GzipFile(fileobj = cStringIO.StringIO(self.buffer)).read()
		print data
	'''
	
	print self.father.data
		
		ProxyClient.handleResponseEnd(self)
		
class DoppelProxyClientFactory(ProxyClientFactory):
	protocol = DoppelProxyClient
		
class DoppelProxyRequest(ProxyRequest):
	protocols = { 'http': DoppelProxyClientFactory }
	ports = { 'http': 80 }
	
	def process(self):
		'''self.requestHeaders.removeHeader('accept-encoding')'''
		ProxyRequest.process(self)
		
class DoppelProxy(Proxy):
	requestFactory = DoppelProxyRequest

doppelProxy = http.HTTPFactory()
doppelProxy.protocol = DoppelProxy

		
reactor.listenTCP(8000, doppelProxy)
reactor.run()