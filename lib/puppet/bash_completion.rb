require 'puppet/face'

class Puppet::BashCompletion
  def self.choices(args)
    subcommand = args.shift || ''
    choices = []
    search_pattern = nil

    faces = Puppet::Face.faces.map(&:to_s)
    legacy_applications = Puppet::Face['help', :current].legacy_applications
    settings = Puppet.settings.names.map {|name| "--" + name }

    if faces.include?(subcommand)
      face = Puppet::Face[subcommand, :current]
      actions = face.actions.map(&:to_s)
      options = face.options.map {|o| "--#{o}"}
      choices = (actions + options).sort
      search_pattern = args.last || ''
    elsif legacy_applications.include?(subcommand)
      search_pattern = args.last || ''
    elsif args.empty?
      choices = (faces + legacy_applications).sort
      search_pattern = subcommand
    else
      search_pattern = args.last
    end

    #choices << settings

    return choices, search_pattern
  end
end

