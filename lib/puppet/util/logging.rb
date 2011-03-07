# A module to make logging a bit easier.
require 'puppet/util/log'

module Puppet::Util::Logging

  @@indent_level = 0
  def send_log(level, message)
    Puppet::Util::Log.create({:level => level, :source => log_source, :message => message}.merge(log_metadata))
  end

  # Create a method for each log level.
  Puppet::Util::Log.eachlevel do |level|
    next if level.to_s == 'debug'
    define_method(level) do |args|
      args = args.join(" ") if args.is_a?(Array)
      send_log(level, args)
    end
  end

  def debug(message)
    raise "should only ever be string" if message.is_a?(Array)
    indent_text = @@indent_level > 0 ? '| ' + "  " * @@indent_level : ''
    if block_given?
      time_started = Time.now
      msg = indent_text + time_started.strftime('%Y-%m-%d %H:%M:%S %z') + " Start " + message
      send_log(:debug, msg)

      indent_text += '| '
      @@indent_level += 1
      yield
      @@indent_level -= 1
      indent_text = indent_text.slice(0..-3)

      send_log(:debug, indent_text + Time.now.to_s + " Finished (Time elapsed #{Time.now - time_started}) " + message)
    else
      send_log(:debug, indent_text + message)
    end
  end

  private

  def is_resource?
    defined?(Puppet::Type) && is_a?(Puppet::Type)
  end

  def is_resource_parameter?
    defined?(Puppet::Parameter) && is_a?(Puppet::Parameter)
  end

  def log_metadata
    [:file, :line, :tags].inject({}) do |result, attr|
      result[attr] = send(attr) if respond_to?(attr)
      result
    end
  end

  def log_source
    # We need to guard the existence of the constants, since this module is used by the base Puppet module.
    (is_resource? or is_resource_parameter?) and respond_to?(:path) and return path.to_s
    to_s
  end
end
