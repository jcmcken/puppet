require 'open-uri'
require 'pathname'
require 'tmpdir'

module Puppet::Module::Tool
  module Applications
    class Installer < Application

      def initialize(name, options = {})
        environment = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @installed_modules = environment.modules

        if File.exist?(name)
          if File.directory?(name)
            # TODO Unify this handling with that of Unpacker#check_clobber!
            raise ArgumentError, "Module already installed: #{name}"
          end
          @source = :filesystem
          @filename = File.expand_path(name)
          parse_filename!
        else
          @source = :repository
          begin
            @username, @module_name = Puppet::Module::Tool::username_and_modname_from(name)
          rescue ArgumentError
            raise "Could not install module with invalid name: #{name}"
          end
          @version_requirement = options[:version]
        end
        super(options)
      end

      def force?
        options[:force]
      end

      def install(remote_file)
        begin
          cache_path = repository.retrieve(remote_file)
        rescue OpenURI::HTTPError => e
          raise RuntimeError, "Could not install module: #{e.message}"
        end
        module_dir = Unpacker.run(cache_path, options)
      end

      def run
        case @source
        when :repository
          if match['file']
            #local = local_deps(@installed_modules)
            #remote = remote_deps(@username, @module_name)
            dep_info = dependency_info(@username, @module_name, @match["version"])
            ([match] + dep_info).each do |mod|
              install(mod['file'])
            end
          else
            raise RuntimeError, "Malformed response from module repository."
          end
        when :filesystem
          repository = Repository.new('file:///')
          uri = URI.parse("file://#{URI.escape(File.expand_path(@filename))}")
          cache_path = repository.retrieve(uri)
          module_dir = Unpacker.run(cache_path, options)
        else
          raise ArgumentError, "Could not determine installation source"
        end

        # Return the Pathname object representing the path to the installed
        # module. This return value is used by the module_tool face install
        # action, and displayed to on the console.
        #
        # Example return value:
        #
        #   "/etc/puppet/modules/apache"
        #
        module_dir
      end

      private

      # build a data structure that will allows to resolve constraints
      def local_deps(mods)
        deps = {}
        mods.each do |mod|
          deps[mod.metadata['name']] ||= {}
          deps[mod.metadata['name']][:versions] ||= []
          deps[mod.metadata['name']][:versions] << mod.version
          deps[mod.metadata['name']][:required_by] ||= []

          mod.dependencies.each do |mod_dep|
            dep_name = mod_dep['name'].gsub('/', '-')
            deps[dep_name] ||= {}
            deps[dep_name][:required_by] ||= []
            deps[dep_name][:required_by] << ["#{mod.metadata['name']}@#{mod.version}", mod_dep['version_requirement']]
          end
        end
        deps
      end

      def remote_deps(author, mod_name)
        url = ::URI.parse('http://localhost:3000/' + "api/v1/releases.json?module=#{author}/#{mod_name}")
        PSON.parse(read_match(url))
      end

      def dependency_info(author, mod_name, version)
        url = repository.uri + "/#{author}/#{mod_name}/#{version}/json"
        raw_result = read_match(url)
        mod_version_info = PSON.parse(raw_result)
        dependencies = mod_version_info['metadata']['dependencies']
        dep_info = []
        while !dependencies.empty?
          dep = dependencies.pop
          dep_author, dep_name = dep['name'].split('/')
          version_req = dep['version_requirement']
          dep_installed = @installed_modules.find {|mod| mod.name == dep_name}

          if dep_installed
            # if dep_installed.satisfy(version_req)
            #   next
            # else
            #   warn "already installed mod #{dep_name} doesn't satisfy
            # end
          else
            remote_info = get_remote_module_install_info(dep_author, dep_name, version_req)

            # now we need to find any of its deps
            url = repository.uri + "/#{dep_author}/#{dep_name}/#{remote_info['version']}/json"
            dep_dep_info = PSON.parse(read_match(url))
            dependencies += dep_dep_info['metadata']['dependencies']
            dep_info << remote_info
          end

        end

        dep_info
      end

      def get_remote_module_install_info(author, name, version_req)
        url = repository.uri + "/users/#{author}/modules/#{name}/releases/find.json"
        if version_req
          url.query = "version=#{URI.escape(version_req)}"
        end
        begin
          raw_result = read_match(url)
        rescue => e
          raise ArgumentError, "Could not find a release for this module (#{e.message})"
        end
        PSON.parse(raw_result)
      end

      def match
        return @match ||= begin
          @match = get_remote_module_install_info(@username, @module_name, @version_requirement)
        end
      end

      def read_match(url)
        return url.read
      end
    end
  end
end
