#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/facts/facter'

describe Puppet::Node::Facts::Facter do
  it "should be a subclass of the Code terminus" do
    Puppet::Node::Facts::Facter.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should have documentation" do
    Puppet::Node::Facts::Facter.doc.should_not be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:facts)
    Puppet::Node::Facts::Facter.indirection.should equal(indirection)
  end

  it "should have its name set to :facter" do
    Puppet::Node::Facts::Facter.name.should == :facter
  end

  it "should load facts on initialization" do
    Puppet::Node::Facts::Facter.expects(:load_fact_plugins)
    Puppet::Node::Facts::Facter.new
  end
end

describe Puppet::Node::Facts::Facter do
  let(:facter) { Puppet::Node::Facts::Facter.new }
  before :each do
    Facter.stubs(:to_hash).returns({})
    @name = "me"
    @request = stub 'request', :key => @name
  end

  describe Puppet::Node::Facts::Facter, " when finding facts" do
    it "should return a Facts instance" do
      facter.find(@request).should be_instance_of(Puppet::Node::Facts)
    end

    it "should return a Facts instance with the provided key as the name" do
      facter.find(@request).name.should == @name
    end

    it "should return the Facter facts as the values in the Facts instance" do
      Facter.expects(:to_hash).returns("one" => "two")
      facts = facter.find(@request)
      facts.values["one"].should == "two"
    end

    it "should add local facts" do
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:add_local_facts)

      facter.find(@request)
    end

    it "should convert all facts into strings" do
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:stringify)

      facter.find(@request)
    end

    it "should call the downcase hook" do
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:downcase_if_necessary)

      facter.find(@request)
    end
  end

  describe Puppet::Node::Facts::Facter, " when saving facts" do

    it "should fail" do
      proc { facter.save(@facts) }.should raise_error(Puppet::DevError)
    end
  end

  describe Puppet::Node::Facts::Facter, " when destroying facts" do

    it "should fail" do
      proc { facter.destroy(@facts) }.should raise_error(Puppet::DevError)
    end
  end

  it "should skip files when asked to load a directory" do
    FileTest.expects(:directory?).with("myfile").returns false

    Puppet::Node::Facts::Facter.load_facts_in_dir("myfile")
  end

  it "should load each ruby file when asked to load a directory" do
    FileTest.expects(:directory?).with("mydir").returns true
    Dir.expects(:chdir).with("mydir").yields

    Dir.expects(:glob).with("*.rb").returns %w{a.rb b.rb}

    Puppet::Node::Facts::Facter.expects(:load).with("a.rb")
    Puppet::Node::Facts::Facter.expects(:load).with("b.rb")

    Puppet::Node::Facts::Facter.load_facts_in_dir("mydir")
  end

  describe Puppet::Node::Facts::Facter, "when loading fact plugins from disk" do
    it "should load all facts from the uniq factpath and modules directories" do
      Puppet.settings[:factpath] = "fact1#{File::PATH_SEPARATOR}fact2#{File::PATH_SEPARATOR}fact1"

      Puppet.settings[:modulepath] = "one#{File::PATH_SEPARATOR}two"
      Dir.expects(:glob).with("one/*/lib/facter").returns %w{lib1 lib2}
      Dir.expects(:glob).with("two/*/lib/facter").returns %w{lib2 lib3 lib4}
      Dir.expects(:glob).with("one/*/plugins/facter").returns []
      Dir.expects(:glob).with("two/*/plugins/facter").returns %w{plug1 plug2}

      %w{fact1 fact2 lib1 lib2 lib3 lib4 plug1 plug2}.each do |path|
        Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with(path)
      end

      Puppet::Node::Facts::Facter.load_fact_plugins
    end
  end
end
