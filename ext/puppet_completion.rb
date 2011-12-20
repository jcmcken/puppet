#!/usr/bin/env ruby

require 'puppet/bash_completion'

args = ENV["COMP_LINE"].split /\s+/

# "puppet"
args.shift

choices, search_pattern = Puppet::BashCompletion.choices(args)
puts `compgen -W '#{choices.join(" ")}' -- '#{search_pattern}'` if search_pattern

exit 0
