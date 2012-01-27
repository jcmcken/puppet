Puppet::Face.define(:module, '1.0.0') do
  action(:list) do
    summary "List installed modules"
    description <<-HEREDOC
      List puppet modules from a specific environment, specified modulepath or
      default to listing modules in the default modulepath:
      #{Puppet.settings[:modulepath]}
    HEREDOC
    returns "hash of paths to module objects"

    option "--env ENVIRONMENT" do
      summary "Which environments' modules to list"
    end

    option "--modulepath MODULEPATH" do
      summary "Which directories to look for modules in"
    end

    option "--tree" do
      summary "Whether to show dependencies as a tree view"
    end

    examples <<-EOT
      List installed modules:

      $ puppet module list
        /etc/puppet/modules
          bacula (0.0.2)
        /usr/share/puppet/modules
          apache (0.0.3)
          bacula (0.0.1)

      List installed modules from a specified environment:

      $ puppet module list --env 'test'
        /tmp/puppet/modules
          rrd (0.0.2)

      List installed modules from a specified modulepath:

      $ puppet module list --modulepath /tmp/facts1:/tmp/facts2
        /tmp/facts1
          stdlib
        /tmp/facts2
          nginx (1.0.0)
    EOT

    when_invoked do |options|
      Puppet[:modulepath] = options[:modulepath] if options[:modulepath]
      environment = Puppet::Node::Environment.new(options[:env])

#     {
#       mod1 => [ mod2, mod3 ]
#       mod3 => { mod4 }
#     }

      modules_by_path = environment.modules_by_path
      # There should be a better way to get options to the rendering method
      modules_by_path[:options] = options
      modules_by_path
    end

    when_rendering :console do |modules_by_path|
      options = modules_by_path.delete(:options)
      output = ''

      mods_tree_deps = {}
      environment = Puppet::Node::Environment.new(options[:env])
      mod_deps = environment.module_dependencies
      modules_by_path.each do |path, modules|
        output << "#{path}\n"
        if options[:tree]
          while !modules.empty?
            mod = mod_with_fewest_requires(mod_deps, environment)
            mod_deps.delete(mod.metadata['name'])
            modules.delete(mod)

            indent_level = 0
            tree_print(mod, modules, mod_deps, output, indent_level)
          end
        end
      end

      output
    end

  end

  def tree_print(mod, modules, mod_deps, output, indent_level)
    indent = '  ' * indent_level
    output << print(mod, indent)

    mod.dependencies_as_modules.each do |dep_mod|
      modules.delete(dep_mod)
      mod_deps.delete(dep_mod.metadata['name'])
      tree_print(dep_mod, modules, mod_deps, output, indent_level + 1)

#     dep_mod.unsatisfied_dependencies.each do |unsat_dep|
#       unsat_mod, reason = unsat_dep
#       output << "    #{unsat_mod.name} unsatisfied because #{reason}\n"
#     end
    end
  end

  def print(mod, indent)
    version_string = mod.version ? "(#{mod.version})" : '???'
    "#{indent}#{mod.name} #{version_string}\n"
  end

  def mod_with_fewest_requires(mod_deps, environment)

    fewest_require_size = mod_deps.map {|mod_name,v| v[:required_by].size}.min
    mod_info = mod_deps.find {|mod_name, v| v[:required_by].size == fewest_require_size}
    mod_name = mod_info.first
    mod_name = mod_name.split('-').last
    environment.module(mod_name)
  end
end
