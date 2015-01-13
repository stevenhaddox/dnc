require 'spec_helper'

describe String do
  let!(:raw_dn) { '/DC=org/DC=ruby-lang/CN=Ruby certificate rbcert' }
  let(:dn) {
    DN.new({
      dn_string: raw_dn,
    })
  }
  let(:dn_to_s) { 'CN=RUBY CERTIFICATE RBCERT,DC=RUBY-LANG,DC=ORG' }

  after :all do
    #expect(@log_output.readline).to eq("DEBUG String: DNC raw_dn:\n")
  end

  describe ".to_dn" do
    it "should return a DN instance if the string can be parsed" do
      expect(raw_dn.to_dn.class.to_s).to eq('DN')
      expect(raw_dn.to_dn.to_yaml).to eq(dn.to_yaml)
    end

    it "should return nil otherwise" do
      expect("".to_dn).to eql(nil)
      expect("nope".to_dn).to eql(nil)
    end
  end

  describe ".to_dn!" do
    it "should return a DN instance if the string can be parsed" do
      expect(raw_dn.to_dn!.class.to_s).to eq('DN')
      expect(raw_dn.to_dn!.to_yaml).to eq(dn.to_yaml)
    end

    it "should raise a DnStringUnparsableError otherwise" do
      expect{ "".to_dn! }.to raise_error(DnStringUnparsableError)
      expect{ "nope".to_dn! }.to raise_error(DnStringUnparsableError)
    end
  end
end
