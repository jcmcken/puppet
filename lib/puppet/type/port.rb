module Puppet
  newtype(:port) do
    @doc = "Installs and manages port entries. For most systems, these
      entries will just be in /etc/services, but some systems (notably OS X)
      will have different solutions."

    def self.title_patterns
      [
        # we have two titlepatterns "name" and "name:protocol". We won't use
        # one pattern (that will eventually set :protocol to nil) because we
        # want to use a default value for :protocol. And that does only work
        # if :protocol is not put in the parameter hash while initialising
        [
          /^(.*?):(tcp|udp)$/, # Set name and protocol
          [
            # We don't need a lot of postparsing
            [ :name, lambda{|x| x} ],
            [ :protocol, lambda{ |x| x.intern unless x.nil? } ]
          ]
        ],
        [
          /^(.*)$/,
          [
            [ :name, lambda{|x| x} ]
          ]
        ]
      ]
    end

    ensurable

    newparam(:name) do
      desc "The port name."

      validate do |value|
        raise Puppet::Error "Portname cannot have whitespaces in them" if value =~ /\s/
      end

      isnamevar
    end

    newparam(:protocol) do
      desc "The protocols the port uses. Valid values are *udp* and *tcp*.
        Most services have both protocols, but not all. If you want both
        protocols you have to define two resources. Remeber that you cannot
        specify two resources with the same title but you can use a title
        to set both, name and protocol if you use ':' as a seperator. So
        port { 'telnet:tcp': ... } sets both name and protocol and you dont
        have to specify them explicitly then"

      newvalues :tcp, :udp

      defaultto :tcp

      isnamevar
    end


    newproperty(:number) do
      desc "The port number."

      validate do |value|
        raise Puppet::Error, "number has to be numeric, not #{value}" unless value =~ /^[0-9]+$/
        raise Puppet::Error, "number #{value} out of range" unless (0...2**16).include?(Integer(value))
      end
    end

    newproperty(:description) do
      desc "The port description."
    end

    newproperty(:port_aliases, :parent => Puppet::Property::OrderedList) do
      desc "Any aliases the port might have. Multiple values must be
        specified as an array."

      def inclusive?
        true
      end

      def delimiter
        " "
      end

      validate do |value|
        raise Puppet::Error, "Aliases cannot have whitespaces in them" if value =~ /\s/
      end
    end


    newproperty(:target) do
      desc "The file in which to store service information. Only used by
        those providers that write to disk."

      defaultto do
        if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
          @resource.class.defaultprovider.default_target
        else
          nil
        end
      end
    end

  end
end
