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

      modules_by_path = {}

      environment.modules_by_path.map do |path, modules|
        # This makes it easier to merge the module contents later
        modules_map = Hash[modules.map {|m| [m.name, {:module => m}]}]

        if options[:verbose]
          # Need to have an environment with just this path as the modulepath
          # Otherwise the first path overrides subsequent paths and we get the
          # wrong data in known_resource_types
          e = Puppet::Node::Environment.new(path)
          e.modulepath = path

          type_loader = Puppet::Parser::TypeLoader.new(e)
          type_loader.import_all
          module_content = e.known_resource_types.grouped_by_module
          modules_map.each do |name, value|
            value.merge! module_content[name]
          end
        end
        modules_by_path[path] = modules_map
      end

      modules_by_path
    end

    when_rendering :console do |modules_by_path|
      output = ''
      modules_by_path.each do |path, modules|
        output << "#{path}\n"
        modules.each do |name, content|
          mod = content.delete(:module)
          output << " #{mod.name} (#{mod.version})\n"
          output << "    dependencies\n"
          mod.dependencies.each do |dependency|
            output << "      #{dependency['name']} #{dependency['version_requirement']}\n"
          end
          content.each do |content_type, content_values|
            output << "    #{content_type}\n"
            content_values.each do |value|
              output << "      #{value}\n"
            end
          end
        end
      end
      output
    end

  end
end
