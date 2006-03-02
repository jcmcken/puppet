module Puppet
    Puppet.type(:file).ensurable do
        require 'etc'
        desc "Whether to create files that don't currently exist.
            Possible values are *absent*, *present* (equivalent to *file*),
            **file**/*directory*.  Specifying 'absent' will delete the file,
            although currently this will not recursively delete directories.
            
            This is the only element with an *ensure* state that does not have
            a default value."

        # Most 'ensure' states have a default, but with files we, um, don't.
        nodefault

        newvalue(:absent) do
            File.unlink(@parent[:path])
        end

        aliasvalue(:false, :absent)

        newvalue(:file) do
            # Make sure we're not managing the content some other way
            if state = @parent.state(:content) or state = @parent.state(:source)
                state.sync
            else
                mode = @parent.should(:mode)
                Puppet::Util.asuser(asuser(), @parent.should(:group)) {
                    f = nil
                    if mode
                        Puppet::Util.withumask(000) do
                            f = File.open(@parent[:path],"w", mode)
                        end
                    else
                        f = File.open(@parent[:path],"w")
                    end

                    f.flush
                    f.close
                    @parent.setchecksum
                }
            end
            return :file_created
        end

        aliasvalue(:present, :file)

        newvalue(:directory) do
            mode = @parent.should(:mode)
            parent = File.dirname(@parent[:path])
            unless FileTest.exists? parent
                raise Puppet::Error,
                    "Cannot create %s; parent directory %s does not exist" %
                        [@parent[:path], parent]
            end
            Puppet::Util.asuser(asuser()) {
                if mode
                    Puppet::Util.withumask(000) do
                        Dir.mkdir(@parent[:path],mode)
                    end
                else
                    Dir.mkdir(@parent[:path])
                end
            }
            @parent.setchecksum
            return :directory_created
        end

        def asuser
            if @parent.should(:owner) and ! @parent.should(:owner).is_a?(Symbol)
                writeable = Puppet::Util.asuser(@parent.should(:owner)) {
                    FileTest.writable?(File.dirname(@parent[:path]))
                }

                # If the parent directory is writeable, then we execute
                # as the user in question.  Otherwise we'll rely on
                # the 'owner' state to do things.
                if writeable
                    asuser = @parent.should(:owner)
                end
            end

            return asuser
        end

        def check
            basedir = File.dirname(@parent[:path])

            if ! FileTest.exists?(basedir)
                raise Puppet::Error,
                    "Can not create %s; parent directory does not exist" %
                    @parent.name
            elsif ! FileTest.directory?(basedir)
                raise Puppet::Error,
                    "Can not create %s; %s is not a directory" %
                    [@parent.name, dirname]
            end
        end

        def retrieve
            if stat = @parent.stat(false)
                @is = stat.ftype.intern
            else
                if self.should == :false
                    @is = :false
                else
                    @is = :absent
                end
            end

            #self.debug "'exists' state is %s" % self.is
        end


        # We can mostly rely on the superclass method, but we want other states
        # to take precedence over 'ensure' if they are present.
#        def sync
#            # XXX This is a bad idea, because it almost guarantees bugs if we
#            # introduce more states to manage content, but anything else is just
#            # about as bad.
#            event = nil
#            #if state = @parent.state(:source) or state = @parent.state(:content)
#            #    event = state.sync
#            #else
#                event = super
#                @parent.setchecksum
#            #end
#            return event
#        end

        def disabled_sync
            event = nil
            basedir = File.dirname(@parent[:path])

            if ! FileTest.exists?(basedir)
                raise Puppet::Error,
                    "Can not create %s; parent directory does not exist" %
                    @parent.name
            elsif ! FileTest.directory?(basedir)
                raise Puppet::Error,
                    "Can not create %s; %s is not a directory" %
                    [@parent.name, dirname]
            end

            self.retrieve
            if self.insync?
                self.info "already in sync"
                return nil
            end

            mode = @parent.should(:mode)

            # First, determine if a user has been specified and if so if
            # that user has write access to the parent dir
            asuser = nil
            if @parent.should(:owner) and ! @parent.should(:owner).is_a?(Symbol)
                writeable = Puppet::Util.asuser(@parent.should(:owner)) {
                    FileTest.writable?(File.dirname(@parent[:path]))
                }

                # If the parent directory is writeable, then we execute
                # as the user in question.  Otherwise we'll rely on
                # the 'owner' state to do things.
                if writeable
                    asuser = @parent.should(:owner)
                end
            end
            begin
                case self.should
                when "file":
                    # just create an empty file
                    Puppet::Util.asuser(asuser, @parent.should(:group)) {
                        if mode
                            File.open(@parent[:path],"w", mode) {
                            }
                        else
                            File.open(@parent[:path],"w") {
                            }
                        end
                    }
                    event = :file_created
                when "directory":
                    Puppet::Util.asuser(asuser) {
                        if mode
                            Dir.mkdir(@parent[:path],mode)
                        else
                            Dir.mkdir(@parent[:path])
                        end
                    }
                    event = :directory_created
                when :absent:
                    # this is where the file should be deleted...

                    # This value is only valid when we're rolling back a creation,
                    # so we verify that the file has not been modified since then.
                    unless FileTest.size(@parent[:path]) == 0
                        raise Puppet::Error.new(
                            "Created file %s has since been modified; cannot roll back."
                        )
                    end

                    File.unlink(@parent[:path])
                else
                    error = Puppet::Error.new(
                        "Somehow got told to create a %s file" % self.should)
                    raise error
                end
            rescue => detail
                raise Puppet::Error.new("Could not create %s: %s" %
                    [self.should, detail]
                )
            end
            return event
        end
    end
end

# $Id$
