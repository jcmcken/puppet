require 'puppet/provider/parsedfile'

services = nil
case Facter.value(:operatingsystem)
when "Solaris"
  services = "/etc/inet/services"
else
  services = "/etc/services"
end

Puppet::Type.type(:port).provide(:parsed, :parent => Puppet::Provider::ParsedFile,
  :default_target => services, :filetype => :flat) do

  text_line :comment, :match => /^\s*#/
  text_line :blank, :match => /^\s*$/

  record_line :parsed, :fields => %w{name number protocol port_aliases description},
    :optional   => %w{port_aliases description},
    :match      => /^(\S*)\s+(\d*)\/(\S*)\s*(.*?)?\s*(?:#\s*(.*))?$/,
    :post_parse => proc { |hash|
      hash[:protocol] = hash[:protocol].intern if hash[:protocol]
      hash[:description] = '' if hash[:description].nil? or hash[:description] == :absent
      unless hash[:port_aliases].nil? or hash[:port_aliases] == :absent
        hash[:port_aliases].gsub!(/\s+/,' ') # Change delimiter
      end
    },
    :to_line => proc { |hash|
      [:name, :number, :protocol].each do |n|
        raise Puppet::Error, "#{n} is a required attribute for port but not included in #{hash.inspect}" unless hash[n] and hash[n] != :absent
      end

      str = "#{hash[:name]}\t#{hash[:number]}/#{hash[:protocol]}"
      if hash.include? :port_aliases and !hash[:port_aliases].nil? and hash[:port_aliases] != :absent
        str += "\t#{hash[:port_aliases]}"
      end
      if hash.include? :description and !hash[:description].empty?
        str += "\t# #{hash[:description]}"
      end
      str
    }

  # This method is important for prefetching and is called from the parsedfile provider.
  # We get one record (one line of /etc/services) and a hash of resources (what the user
  # specified in manifests). This hash is build in transaction.rb and uses uniqueness_key
  # as a hashkey.
  # Normally the parsedfileprovider loops over every record and uses record[:name] to
  # find a corresponding resources[name]. That works if we only have one namevar
  # because uniqueness_key of this resource will equal record[:name]. Because we use
  # a composite key the parsedfile provider would never find a resource that matches
  # a given record.
  # Even worse: The parsedfileprovider cannot calculate the uniqueness_key of a
  # specific record.
  def self.match(record,resources)
    # This should never happen but who knows
    return false unless name = record[:name] and protocol = record[:protocol]

    # We now calculate the uniqueness_key of the resource we want to find
    uniq_key = [name, protocol]
    resources[uniq_key] # will be nil if the user doesnt manage record
  end
end
