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

    # localcacert is where each client stores the CA certificate
    # cacert is where the master stores the CA certificate
    # Since we need to play the role of both for testing we need them to be the same and exist
    Puppet[:cacert] = Puppet[:localcacert]
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
    before do
      @host = Puppet::SSL::Host.new("foo")
      Puppet.settings.use(:main)
    end

    it "should return the Puppet::SSL::Host when a CSR exists for the host" do
      Puppet.settings.use(:main)
      @host.generate_key

      csr = Puppet::SSL::CertificateRequest.new(@host.name)
      csr.generate(@host.key.content)
      Puppet::SSL::CertificateRequest.indirection.save(csr)
      request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)

      retrieved_host = @terminus.find(request)

      retrieved_host.name.should == @host.name
      retrieved_host.certificate_request.content.to_s.chomp.should == csr.content.to_s.chomp
    end

    it "should return the Puppet::SSL::Host when a public key exist for the host" do
      Puppet.settings.use(:main)

      @host.generate_key

      csr = Puppet::SSL::CertificateRequest.new(@host.name)
      csr.generate(@host.key.content)

      Puppet::SSL::CertificateRequest.indirection.save(csr)
      request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)
      Puppet::SSL::CertificateAuthority.new.sign(request.key)

      retrieved_host = @terminus.find(request)

      retrieved_host.name.should == @host.name
      retrieved_host.certificate.content.to_s.chomp.should == @host.certificate.content.to_s.chomp
    end

    it "should return nil when neither a CSR nor public key exist for the host" do
      request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)
      @terminus.find(request).should == nil
    end
  end

  describe "when saving" do
    before do
      @host = Puppet::SSL::Host.new("foobar")
      Puppet.settings.use(:main)
    end

    describe "when signing a cert" do
      before do
        @host.desired_state = "signed"
        @request = Puppet::Indirector::Request.new(:certificate_status, :save, "foobar", @host)
      end

      it "should fail if no CSR is on disk" do
        lambda { @terminus.save(@request) }.should raise_error(Puppet::Error, /certificate request/)
      end

      it "should sign the on-disk CSR when it is present" do
        signed_host = generate_signed_cert(@host)

        signed_host.state.should == ["signed", nil]
        Puppet::SSL::Certificate.indirection.find("foobar").should be_instance_of(Puppet::SSL::Certificate)
      end
    end

    describe "when revoking a cert" do
      before do
        Puppet.settings.use(:main)
        @request = Puppet::Indirector::Request.new(:certificate_status, :save, "foobar", @host)
      end

      it "should fail if no certificate is on disk" do
        @host.desired_state = "revoked"
        lambda { @terminus.save(@request) }.should raise_error(Puppet::Error, /Cannot revoke/)
      end

      it "should revoke the certificate when it is present" do
        signed_host = generate_signed_cert(@host)

        @host.desired_state = "revoked"
        @terminus.save(@request)

        @host.state.should == ['revoked', 'certificate revoked']
      end
    end
  end

  def generate_signed_cert(host)
    host.generate_key

    # Generate CSR
    csr = Puppet::SSL::CertificateRequest.new(host.name)
    csr.generate(host.key.content)
    Puppet::SSL::CertificateRequest.indirection.save(csr)

    # Sign CSR
    host.desired_state = "signed"
    @terminus.save(Puppet::Indirector::Request.new(:certificate_status, :save, "foobar", host))

    @terminus.find(Puppet::Indirector::Request.new(:certificate_status, :find, "foobar", host))
  end

  describe "when deleting" do
    before do
      @host = Puppet::SSL::Host.new("clean_me")
      @request = Puppet::Indirector::Request.new(:certificate_status, :delete, "clean_me", @host)
    end

    it "should fail if no certificate, request, or key is on disk" do
      lambda { @terminus.destroy(@request) }.should raise_error(Puppet::Error, /Cannot revoke/)
    end

    it "should clean certs, cert requests, keys"

  end

  describe "when searching" do
    before do
      @host = Puppet::SSL::Host.new("foo")
      Puppet.settings.use(:main)
    end

    it "should return the Puppet::SSL::Host when a CSR exists for the host" do
      Puppet.settings.use(:main)
      @host.generate_key

      csr = Puppet::SSL::CertificateRequest.new(@host.name)
      csr.generate(@host.key.content)
      Puppet::SSL::CertificateRequest.indirection.save(csr)
      request = Puppet::Indirector::Request.new(:certificate_status, :search, 'whatever')

      retrieved_hosts = @terminus.search(request)

      retrieved_hosts.map {|h| [h.name, h.state]}
      #retrieved_host.certificate_request.content.to_s.chomp.should == csr.content.to_s.chomp
    end

    it "should return nil when neither a CSR nor public key exist for the host" do
      request = Puppet::Indirector::Request.new(:certificate_status, :find, "foo", @host)
      @terminus.find(request).should == nil
    end
  end

end
