#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper.rb')
require 'puppet/ssl/host'
require 'puppet/indirector/certificate_status'
require 'tempfile'

describe "Puppet::Indirector::CertificateStatus::File" do
  before do
    Puppet::SSL::CertificateAuthority.stubs(:ca?).returns true
    @terminus = Puppet::SSL::Host.indirection.terminus(:file)

    @tmpdir = Tempfile.new("certificate_status_ca_testing")
    @tmpdir.close
    File.unlink(@tmpdir.path)
    Dir.mkdir(@tmpdir.path)
    Puppet[:confdir] = @tmpdir.path
    Puppet[:vardir] = @tmpdir.path
  end

  it "should be a terminus on SSL::Host" do
    @terminus.should be_instance_of(Puppet::Indirector::CertificateStatus::File)
  end

  it "should create a CA instance if none is present" do
    @terminus.ca.should be_instance_of(Puppet::SSL::CertificateAuthority)
  end

  describe "when creating the CA" do
    it "should fail if it is not a valid CA" do
      Puppet::SSL::CertificateAuthority.expects(:ca?).returns false
      lambda { @terminus.ca }.should raise_error(ArgumentError)
    end
  end

  it "should be indirected with the name 'certificate_status'" do
    Puppet::SSL::Host.indirection.name.should == :certificate_status
  end

  describe "when finding" do
    it "should return the Puppet::SSL::Host when a CSR exists for the host" do
      pending "Not working, and we can't figure out why."
      @host = Puppet::SSL::Host.new("foo")
      Puppet.settings.use(:main)

      @host.generate_key

      csr = Puppet::SSL::CertificateRequest.new(@host.name)
      csr.generate(@host.key.content)
      @host.certificate_request = csr
      @request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)
      @terminus.find(@request).should == nil
    end
    it "should return the Puppet::SSL::Host when a public key exist for the host"
    it "should return nil when neither a CSR nor public key exist for the host" do
      @host = Puppet::SSL::Host.new("foo")
      @request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)
      @terminus.find(@request).should == nil
    end
  end

  describe "when saving" do
    before do
      @host = Puppet::SSL::Host.new("mysigner")
      Puppet.settings.use(:main)
    end
    describe "when signing a cert" do
      before do
        @host.desired_state = "signed"
        @request = Puppet::Indirector::Request.new(:certificate_status, :save, "mysigner", @host)
      end

      it "should fail if no CSR is on disk" do
        lambda { @terminus.save(@request) }.should raise_error(Puppet::Error, /certificate request/)
      end

      it "should sign the on-disk CSR when it is present" do
        @host.generate_certificate_request
        @host.certificate_request.class.indirection.save(@host.certificate_request)

        @terminus.save(@request)

        Puppet::SSL::Certificate.indirection.find("mysigner").should be_instance_of(Puppet::SSL::Certificate)
      end
    end
    describe "when revoking a cert" do
      before do
        @host.desired_state = "revoked"
        @request = Puppet::Indirector::Request.new(:certificate_status, :save, "mysigner", @host)
      end

      it "should fail if no certificate is on disk" do
        lambda { @terminus.save(@request) }.should raise_error(Puppet::Error, /Cannot revoke/)
      end

      it "should revoke the certificate when it is present" do
        pending "Can't figure out how to verify a cert has been revoked"
        @host.generate_certificate_request
        @host.certificate_request.class.indirection.save(@host.certificate_request)
        ca = Puppet::SSL::CertificateAuthority.new
        cert = ca.sign(@request.key)
        #Puppet[:cacert] = Puppet::SSL::Certificate.indirection.find("ca")

        @terminus.save(@request)

        lambda { ca.verify(@request.instance.name) }.should raise_error(Puppet::SSL::CertificateAuthority::CertificateVerificationError, /revoked/)
      end
    end
  end
end
