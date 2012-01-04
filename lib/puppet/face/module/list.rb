require 'puppet/parser/type_loader'

Puppet::Face.define(:module, '1.0.0') do
  action(:list) do
    summary "List modules"
    description <<-EOT
      List modules and hopefully the classes they provide
    EOT

    returns "list of modules and classes they provide"

    examples <<-EOT
      something
    EOT

    when_invoked do |*args|
      environment = Puppet::Node::Environment.new('production')
      type_loader = Puppet::Parser::TypeLoader.new(environment)
      type_loader.import_all
      modules = Puppet::Module.find_modules(environment)

      module_contents = environment.known_resource_types.grouped_by_module

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

  end
end
