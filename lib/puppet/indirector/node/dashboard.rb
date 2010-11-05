require 'puppet/node'
require 'puppet/network/http_pool'
require 'puppet/indirector/rest'

class Puppet::Node::Dashboard < Puppet::Indirector::REST
  def find(request)

    # These settings are only used when connecting to dashboard over https (SSL)
    #CERT_PATH = "/etc/puppet/ssl/certs/puppet.pem"
    #PKEY_PATH = "/etc/puppet/ssl/private_keys/puppet.pem"
    #CA_PATH   = "/etc/puppet/ssl/certs/ca.pem"

    uri = URI.parse("#{Puppet[:dashboard_url]}/nodes/#{request.key}")

    require 'ruby-debug'
    debugger
    pool = Puppet::Network::HttpPool.http_instance(uri.host, uri.port)
    deserialize(pool.get(uri.to_s, {'Accept' => 'text/yaml'}))

#   http = Net::HTTP.new(uri.host, uri.port)
#   if uri.scheme == 'https'
#     cert = File.read(Puppet[:host_cert])
#     pkey = File.read(PKEY_PATH)
#     http.use_ssl = true
#     http.cert = OpenSSL::X509::Certificate.new(cert)
#     http.key = OpenSSL::PKey::RSA.new(pkey)
#     http.ca_file = CA_PATH
#     http.verify_mode = OpenSSL::SSL::VERIFY_PEER
#   end
#   result = http.start { http.request_get(uri.path, 'Accept' => 'text/yaml') }

#   case result
#   when Net::HTTPSuccess; puts result.body; exit 0
#   else; STDERR.puts "Error: #{result.code} #{result.message.strip}\n#{result.body}"; exit 1
#   end
  end
end
