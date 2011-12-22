require 'puppet'
require 'yaml'

module Puppet
  # The transportable objects themselves.  Basically just a hash with some
  # metadata and a few extra methods.  I used to have the object actually
  # be a subclass of Hash, but I could never correctly dump them using
  # YAML.
  class TransObject
    include Enumerable
    attr_accessor :type, :name, :file, :line, :catalog

    attr_writer :tags

    %w{has_key? include? length delete empty? << [] []=}.each { |method|
      define_method(method) do |*args|
        @params.send(method, *args)
      end
    }

    def each
      @params.each { |p,v| yield p, v }
    end

    def initialize(name,type)
      @type = type.to_s.downcase
      @name = name
      @params = {}
      @tags = []
    end

    def longname
      [@type,@name].join('--')
    end

    def ref
      @ref ||= Puppet::Resource.new(@type, @name)
      @ref.to_s
    end

    def tags
      @tags
    end

    # Convert a defined type into a component.
    def to_component
      trans = TransObject.new(ref, :component)
      @params.each { |param,value|
        next unless Puppet::Type::Component.valid_parameter?(param)
        Puppet.debug "Defining #{param} on #{ref}"
        trans[param] = value
      }
      trans.catalog = self.catalog
      Puppet::Type::Component.create(trans)
    end

    def to_hash
      @params.dup
    end

    def to_s
      "#{@type}(#{@name}) => #{super}"
    end

    def to_manifest
      "%s { '%s':\n%s\n}" % [self.type.to_s, self.name,
        @params.collect { |p, v|
          if v.is_a? Array
            "    #{p} => [\'#{v.join("','")}\']"
          else
            "    #{p} => \'#{v}\'"
          end
        }.join(",\n")
        ]
    end

    # Create a normalized resource from our TransObject.
    def to_resource
      result = Puppet::Resource.new(type, name, :parameters => @params.dup)
      result.tag(*tags)

      result
    end

    def to_yaml_properties
      instance_variables.reject { |v| %w{@ref}.include?(v) }
    end

    def to_ref
      ref
    end

    def to_ral
      to_resource.to_ral
    end
  end
end

