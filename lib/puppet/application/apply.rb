require 'puppet/application'

class Puppet::Application::Apply < Puppet::Application

  should_parse_config

  option("--debug","-d")
  option("--execute EXECUTE","-e") do |arg|
    options[:code] = arg
  end
  option("--loadclasses","-L")
  option("--verbose","-v")
  option("--use-nodes")
  option("--detailed-exitcodes")

  option("--apply catalog",  "-a catalog") do |arg|
    options[:catalog] = arg
  end

  option("--logdest LOGDEST", "-l") do |arg|
    begin
      Puppet::Util::Log.newdestination(arg)
      options[:logset] = true
    rescue => detail
      $stderr.puts detail.to_s
    end
  end

  def run_command
    if options[:catalog]
      apply
    elsif Puppet[:parseonly]
      parseonly
    else
      report = Puppet.debug("main") { main }
      exit( options[:detailed_exitcodes] ? report.exit_status : 0 )
    end
  end

  def apply
    if options[:catalog] == "-"
      text = $stdin.read
    else
      text = File.read(options[:catalog])
    end

    begin
      catalog = Puppet::Resource::Catalog.convert_from(Puppet::Resource::Catalog.default_format,text)
      catalog = Puppet::Resource::Catalog.pson_create(catalog) unless catalog.is_a?(Puppet::Resource::Catalog)
    rescue => detail
      raise Puppet::Error, "Could not deserialize catalog from pson: #{detail}"
    end

    catalog = catalog.to_ral

    require 'puppet/configurer'
    configurer = Puppet::Configurer.new
    configurer.run :catalog => catalog
  end

  def parseonly
    # Set our code or file to use.
    if options[:code] or command_line.args.length == 0
      Puppet[:code] = options[:code] || STDIN.read
    else
      Puppet[:manifest] = command_line.args.shift
    end
    begin
      Puppet::Node::Environment.new(Puppet[:environment]).known_resource_types
    rescue => detail
      Puppet.err detail
      exit 1
    end
    exit 0
  end

  def main
    # Set our code or file to use.
    if options[:code] or command_line.args.length == 0
      Puppet[:code] = options[:code] || STDIN.read
    else
      manifest = command_line.args.shift
      raise "Could not find file #{manifest}" unless File.exist?(manifest)
      Puppet.warning("Only one file can be applied per run.  Skipping #{command_line.args.join(', ')}") if command_line.args.size > 0
      Puppet[:manifest] = manifest
    end

    unless facts = Puppet.debug("Collect our facts") { Puppet::Node::Facts.find(Puppet[:certname]) }
      raise "Could not find facts for #{Puppet[:certname]}"
    end

    unless node = Puppet.debug("Find our Node") { Puppet::Node.find(Puppet[:certname]) }
      raise "Could not find node #{Puppet[:certname]}"
    end

    Puppet.debug("Merge in the facts") { node.merge(facts.values) }

    Puppet.debug("Allow users to load the classes that puppet agent creates") do
      if options[:loadclasses]
        file = Puppet[:classfile]
        if FileTest.exists?(file)
          unless FileTest.readable?(file)
            $stderr.puts "#{file} is not readable"
            exit(63)
          end
          node.classes = File.read(file).split(/[\s\n]+/)
        end
      end
    end

    begin
      starttime = Time.now
      catalog = Puppet.debug("compiling catalog") do
        Puppet::Resource::Catalog.find(node.name, :use_node => node)
      end

      Puppet.debug("translate it to a RAL catalog") { catalog = catalog.to_ral }
      Puppet.debug("finalizing") { catalog.finalize }

      catalog.retrieval_duration = Time.now - starttime

      require 'puppet/configurer'
      configurer = Puppet::Configurer.new
      return Puppet.debug("running configurer") do
        configurer.run(:skip_plugin_download => true, :catalog => catalog)
      end
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      $stderr.puts detail.message
      exit(1)
    end
  end

  def setup
    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    # If noop is set, then also enable diffs
    Puppet[:show_diff] = true if Puppet[:noop]

    Puppet::Util::Log.newdestination(:console) unless options[:logset]
    client = nil
    server = nil

    Signal.trap(:INT) do
      $stderr.puts "Exiting"
      exit(1)
    end

    if options[:debug]
      Puppet::Util::Log.level = :debug
    elsif options[:verbose]
      Puppet::Util::Log.level = :info
    end
  end
end
