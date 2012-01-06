require 'puppet/parser/type_loader'

Puppet::Face.define(:module, '1.0.0') do
  action(:list) do
    summary "List modules"
    description <<-EOT
      List modules and hopefully the classes they provide
    EOT

    returns "list of modules and classes they provide"

    option "--[no-]verbose" do
      summary "The version of the subcommand for which to show help."
    end

    examples <<-EOT
      something
    EOT

    when_invoked do |options|
      environment = Puppet::Node::Environment.new('production')
      modules = environment.modules

      module_contents = []
      if options[:verbose]
        type_loader = Puppet::Parser::TypeLoader.new(environment)
        type_loader.import_all
        module_contents = environment.known_resource_types.grouped_by_module
      end

      module_contents.each do |module_name, resource_types|
        puts "Module #{module_name} contains:\n"
        resource_types.each do |resource_type, names|
          puts "  #{resource_type}"
          names.each do |name|
            puts "    #{name}"
          end
        end
      end
      ''
    end

  when_rendering :console do |value|
  end

  end
end
