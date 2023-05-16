proxy_address = input('proxy_address')
proxy_port = input('proxy_port')
httpbin = input('httpbin_host')

ENV['http_proxy'] = "http://#{proxy_address}:#{proxy_port}"

control 'Proxy' do
  impact 1
  title 'httpbin should be accessible through the Proxy'

  describe http("http://#{httpbin}/get") do
    its('status') { should cmp 200 }
  end
end
