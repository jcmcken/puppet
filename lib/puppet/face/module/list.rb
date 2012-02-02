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

      environment.modules_by_path
    end

    when_rendering :console do |modules_by_path, options|
      output = ''

      Puppet[:modulepath] = options[:modulepath] if options[:modulepath]
      environment = Puppet::Node::Environment.new(options[:env])

      dependency_errors = false

      environment.modules.each do |mod|
        mod.unsatisfied_dependencies.each do |dep_issue|
          dependency_errors = true
          $stderr.puts dep_issue.to_s
        end
      end

      output << "\n" if dependency_errors

      modules_by_path.each do |path, modules|
        output << "#{path}\n"
        if options[:tree]
          # The modules with fewest things depending on them # will be the
          # parent of the tree.  Can't assume to start with 0 dependencies since
          # dependencies may be cyclical
          modules_by_num_requires = modules.sort_by {|m| m.required_by.size}

          while !modules_by_num_requires.empty?
            mod = modules_by_num_requires.shift

            indent_level = 0
            tree_print(mod, modules_by_num_requires, [], output, indent_level)
          end
        else
          modules.each do |mod|
            output << print(mod)
          end
        end
      end

      output
    end

  end

  def tree_print(mod, modules_left_to_print, ancestors, output, indent_level)
    output << print(mod, indent_level)

    mod.dependencies_as_modules.each do |dep_mod|
      # if module has already been deleted from list
      # it means we have a cycle and need to short circuit
      #
      # However, this means sometimes modules won't print
      # when they're depended upon by more than one
      # module
      modules_left_to_print.delete(dep_mod)
      next if ancestors.include? dep_mod

      tree_print(dep_mod, modules_left_to_print, ancestors.dup << mod, output, indent_level + 1)
    end
  end

  def print(mod, indent_level = 0)
    indent = '  ' * indent_level
    version_string = mod.version ? "(#{mod.version})" : '(???)'
    unmet_dependency = mod.unsatisfied_dependencies.empty? ? '' : 'UNMET DEPENDENCY '
    "#{indent}#{unmet_dependency}#{mod.forge_name || mod.name} #{version_string}\n"
  end
end
