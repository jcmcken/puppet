require 'puppet/application'
require 'puppet/faces'
require 'optparse'

class Puppet::Application::FacesBase < Puppet::Application
  should_parse_config
  run_mode :agent

  option("--debug", "-d") do |arg|
    Puppet::Util::Log.level = :debug
  end

  option("--verbose", "-v") do
    Puppet::Util::Log.level = :info
  end

  option("--format FORMAT") do |arg|
    @format = arg.to_sym
  end

  option("--mode RUNMODE", "-r") do |arg|
    raise "Invalid run mode #{arg}; supported modes are user, agent, master" unless %w{user agent master}.include?(arg)
    self.class.run_mode(arg.to_sym)
    set_run_mode self.class.run_mode
  end


  attr_accessor :face, :action, :type, :arguments, :format
  attr_writer :exit_code

  # This allows you to set the exit code if you don't want to just exit
  # immediately but you need to indicate a failure.
  def exit_code
    @exit_code || 0
  end

  # Override this if you need custom rendering.
  def render(result)
    render_method = Puppet::Network::FormatHandler.format(format).render_method
    if render_method == "to_pson"
      jj result
      exit(0)
    else
      result.send(render_method)
    end
  end

  def preinit
    super
    Signal.trap(:INT) do
      $stderr.puts "Cancelling Face"
      exit(0)
    end
  end

  def parse_options
    # We need to parse enough of the command line out early, to identify what
    # the action is, so that we can obtain the full set of options to parse.

    # REVISIT: These should be configurable versions, through a global
    # '--version' option, but we don't implement that yet... --daniel 2011-03-29
    @type   = self.class.name.to_s.sub(/.+:/, '').downcase.to_sym
    @face   = Puppet::Faces[@type, :current]
    @format = @face.default_format

    # Now, walk the command line and identify the action.  We skip over
    # arguments based on introspecting the action and all, and find the first
    # non-option word to use as the action.
    action = nil
    index  = -1
    until @action or (index += 1) >= command_line.args.length do
      item = command_line.args[index]
      if item =~ /^-/ then
        option = @face.options.find do |name|
          item =~ /^-+#{name.to_s.gsub(/[-_]/, '[-_]')}(?:[ =].*)?$/
        end
        if option then
          option = @face.get_option(option)
          # If we have an inline argument, just carry on.  We don't need to
          # care about optional vs mandatory in that case because we do a real
          # parse later, and that will totally take care of raising the error
          # when we get there. --daniel 2011-04-04
          if option.takes_argument? and !item.index('=') then
            index += 1 unless
              (option.optional_argument? and command_line.args[index + 1] =~ /^-/)
          end
        elsif option = find_global_settings_argument(item) then
          unless Puppet.settings.boolean? option.name then
            # As far as I can tell, we treat non-bool options as always having
            # a mandatory argument. --daniel 2011-04-05
            index += 1          # ...so skip the argument.
          end
        else
          raise OptionParser::InvalidOption.new(item.sub(/=.*$/, ''))
        end
      else
        action = @face.get_action(item.to_sym)
        if action.nil? then
          raise OptionParser::InvalidArgument.new("#{@face} does not have an #{item} action")
        end
        @action = action
      end
    end

    unless @action
      available_actions = face.actions.join(", ")
      raise OptionParser::MissingArgument.new(
        "No action given on the command line.  Avaliable actions are: #{available_actions}"
      )
    end

    # Now we can interact with the default option code to build behaviour
    # around the full set of options we now know we support.
    @action.options.each do |option|
      option = @action.get_option(option) # make it the object.
      self.class.option(*option.optparse) # ...and make the CLI parse it.
    end

    # ...and invoke our parent to parse all the command line options.
    super
  end

  def find_global_settings_argument(item)
    Puppet.settings.each do |name, object|
      object.optparse_args.each do |arg|
        next unless arg =~ /^-/
        # sadly, we have to emulate some of optparse here...
        pattern = /^#{arg.sub('[no-]', '').sub(/[ =].*$/, '')}(?:[ =].*)?$/
        pattern.match item and return object
      end
    end
    return nil                  # nothing found.
  end

  def setup
    Puppet::Util::Log.newdestination :console

    @arguments = command_line.args

    # Note: because of our definition of where the action is set, we end up
    # with it *always* being the first word of the remaining set of command
    # line arguments.  So, strip that off when we construct the arguments to
    # pass down to the face action. --daniel 2011-04-04
    @arguments.delete_at(0)

    # We copy all of the app options to the end of the call; This allows each
    # action to read in the options.  This replaces the older model where we
    # would invoke the action with options set as global state in the
    # interface object.  --daniel 2011-03-28
    @arguments << options
  end


  def main
    # Call the method associated with the provided action (e.g., 'find').
    if result = @face.send(@action.name, *arguments)
      puts render(result)
    end
    exit(exit_code)
  end
end
