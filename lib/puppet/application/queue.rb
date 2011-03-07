require 'puppet/application'
require 'puppet/util'

class Puppet::Application::Queue < Puppet::Application
  should_parse_config

  attr_accessor :daemon

  def preinit
    require 'puppet/daemon'
    @daemon = Puppet::Daemon.new
    @daemon.argv = ARGV.dup
    Puppet::Util::Log.newdestination(:console)

    # Do an initial trap, so that cancels don't get a stack trace.

    # This exits with exit code 1
    Signal.trap(:INT) do
      $stderr.puts "Caught SIGINT; shutting down"
      exit(1)
    end

    # This is a normal shutdown, so code 0
    Signal.trap(:TERM) do
      $stderr.puts "Caught SIGTERM; shutting down"
      exit(0)
    end

    {
      :verbose => false,
      :debug => false
    }.each do |opt,val|
      options[opt] = val
    end
  end

  option("--debug","-d")
  option("--verbose","-v")

  def help
    <<-HELP

puppet-queue(8) -- Queuing daemon for asynchronous storeconfigs
========

SYNOPSIS
--------
Retrieves serialized storeconfigs records from a queue and processes
them in order.


USAGE
-----
puppet queue [-d|--debug] [-v|--verbose]


DESCRIPTION
-----------
This application runs as a daemon and processes storeconfigs data,
retrieving the data from a stomp server message queue and writing it to
a database.

For more information, including instructions for properly setting up
your puppet master and message queue, see the documentation on setting
up asynchronous storeconfigs at:
http://projects.puppetlabs.com/projects/1/wiki/Using_Stored_Configuration


OPTIONS
-------
Note that any configuration parameter that's valid in the configuration
file is also a valid long argument. For example, 'server' is a valid
configuration parameter, so you can specify '--server <servername>' as
an argument.

See the configuration file documentation at
http://docs.puppetlabs.com/references/stable/configuration.html for the
full list of acceptable parameters. A commented list of all
configuration options can also be generated by running puppet queue with
'--genconfig'.

* --debug:
  Enable full debugging.

* --help:
  Print this help message

* --verbose:
  Turn on verbose reporting.

* --version:
  Print the puppet version number and exit.


EXAMPLE
-------
    $ puppet queue


AUTHOR
------
Luke Kanies


COPYRIGHT
---------
Copyright (c) 2009 Puppet Labs, LLC Licensed under the GNU Public
License

    HELP
  end

  def main
    require 'puppet/indirector/catalog/queue' # provides Puppet::Indirector::Queue.subscribe
    Puppet.notice "Starting puppetqd #{Puppet.version}"
    Puppet::Resource::Catalog::Queue.subscribe do |catalog|
      # Once you have a Puppet::Resource::Catalog instance, passing it to save should suffice
      # to put it through to the database via its active_record indirector (which is determined
      # by the terminus_class = :active_record setting above)
      Puppet::Util.benchmark(:notice, "Processing queued catalog for #{catalog.name}") do
        begin
          Puppet::Resource::Catalog.indirection.save(catalog)
        rescue => detail
          puts detail.backtrace if Puppet[:trace]
          Puppet.err "Could not save queued catalog for #{catalog.name}: #{detail}"
        end
      end
    end

    Thread.list.each { |thread| thread.join }
  end

  # Handle the logging settings.
  def setup_logs
    if options[:debug] or options[:verbose]
      Puppet::Util::Log.newdestination(:console)
      if options[:debug]
        Puppet::Util::Log.level = :debug
      else
        Puppet::Util::Log.level = :info
      end
    end
  end

  def setup
    unless Puppet.features.stomp?
      raise ArgumentError, "Could not load the 'stomp' library, which must be present for queueing to work.  You must install the required library."
    end

    setup_logs

    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    require 'puppet/resource/catalog'
    Puppet::Resource::Catalog.indirection.terminus_class = :active_record

    daemon.daemonize if Puppet[:daemonize]

    # We want to make sure that we don't have a cache
    # class set up, because if storeconfigs is enabled,
    # we'll get a loop of continually caching the catalog
    # for storage again.
    Puppet::Resource::Catalog.indirection.cache_class = nil
  end
end
