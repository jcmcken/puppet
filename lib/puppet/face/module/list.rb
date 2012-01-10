require 'puppet/parser/type_loader'

Puppet::Face.define(:module, '1.0.0') do
  action(:list) do
    summary "List modules"
    returns "list of modules and optionally classes, defined types and nodes they provide"

    option "--environment ENVIRONMENT" do
      default_to {'production'}
      summary "Which environments modules to list.  Defaults to production"
    end

    examples <<-EOT
      List installed modules

      $ puppet module list
      
    EOT

    when_invoked do |options|
      environment = Puppet::Node::Environment.new(options[:environment])

      modules_by_path = {}

      environment.modules_by_path.map do |path, modules|
        # This makes it easier to merge more info about a module later
        # such as what a module contains
        modules_by_path[path] = Hash[modules.map {|m| [m.name, {:module => m}]}]
      end

      modules_by_path
    end

    when_rendering :console do |modules_by_path|
      output = ''
      modules_by_path.each do |path, modules|
        output << "#{path}\n"
        modules.each do |name, content|
          mod = content.delete(:module)
          output << "  #{mod.name} (#{mod.version})\n"
        end
      end
      output
    end

  end
end
