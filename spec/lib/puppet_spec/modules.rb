module PuppetSpec::Modules
  class << self
    include PuppetSpec::Files
    def create(name, dir, options = {})
      module_dir = File.join(dir, name)
      Dir.mkdir(module_dir)

      environment = Puppet::Node::Environment.new(options[:environment])

      if metadata = options[:metadata]
        metadata[:source]  ||= 'github'
        metadata[:author]  ||= 'puppetlabs'
        metadata[:version] ||= '9.9.9'
        metadata[:license] ||= 'to kill'
        metadata[:dependencies] ||= []

        metadata[:name] = "#{metadata[:author]}/#{name}"

        File.open(File.join(module_dir, 'metadata.json'), 'w') do |f|
          f.write(metadata.to_pson)
        end
      end

      Puppet::Module.new(name, :environment => environment, :path => module_dir)
    end
  end
end
