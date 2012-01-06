require 'puppet/parser/type_loader'

Puppet::Face.define(:module, '1.0.0') do
  action(:list) do
    summary "List modules"
    description <<-EOT
      List of modules and optionally classes, defined types and nodes they provide
    EOT

    returns "list of modules and optionally classes, defined types and nodes they provide"

    option "--[no-]verbose" do
      summary "Whether or not to list module contents"
    end

    option "--environment ENVIRONMENT" do
      default_to {'production'}
      summary "Which environments modules to list.  Defaults to production"
    end

    examples <<-EOT
      something
    EOT

    when_invoked do |options|
      environment = Puppet::Node::Environment.new(options[:environment])

      # This structure makes it easy to merge in content from known resource types
      modules_map = environment.modules.map {|m| [m.name, {:module => m}]}
      modules = Hash[modules_map]

      if options[:verbose]
        type_loader = Puppet::Parser::TypeLoader.new(environment)
        type_loader.import_all
        module_content = environment.known_resource_types.grouped_by_module
        modules.each do |name, value|
          value.merge! module_content[name]
        end
      end

      modules
    end

    when_rendering :console do |modules|
      output = ''
      modules.each do |name, content|
        mod = content.delete(:module)
        output << "#{name} (#{mod.version})\n"
      end
      output
    end

  end
end
