require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module list" do
  subject { Puppet::Face[:module, :current].list }

	describe "when using default environment" do
		it "should return an empty hash when the modulepath is empty" do
			should == {}
		end

		it "should include a module twice if it's in both directories of the modulepath" do
		end
	end
end
