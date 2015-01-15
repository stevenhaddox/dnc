require "spec_helper"

describe DN do
  let!(:raw_dn) { '/C=US/O=RB/OU=DEV/OU=JS/OU=People/CN=Last First M (initial)' }
  let!(:dn_to_s) { 'CN=LAST FIRST M (INITIAL),OU=PEOPLE,OU=JS,OU=DEV,O=RB,C=US' }
  let(:valid_subject) { DN.new(dn_string: raw_dn) }
  let(:dn_elements) { ["CN=LAST FIRST M (INITIAL)", "OU=PEOPLE", "OU=JS", "OU=DEV", "O=RB", "C=US"] }

  #
  # Unit specs
  #
  describe "#new" do
    it "should create a new DN object when valid" do
      expect(valid_subject.class.to_s).to eq(DN.to_s)
    end

    it "should identify the most likely delimiter" do
      expect(valid_subject.delimiter).to eq('/')
      %w(, ; - _ : \\ % ^ ! & * @ # $).each do |delim|
        custom_delim_subject = DN.new(dn_string: raw_dn.gsub('/',delim))
        expect(custom_delim_subject.delimiter).to eq(delim)
      end
    end

    it "should split on identified delimiter" do
      expect(valid_subject.split_by_delimiter).to eq(dn_elements)
    end

    it "should parse each key value pair and assign an attribute" do
      expect(valid_subject.c).to eq('US')
      expect(valid_subject.o).to eq('RB')
    end

    it "should return appropriate attrs as arrays" do
      expect(valid_subject.ou).to eq(['PEOPLE','JS','DEV'])
      expect(DN.new(dn_string: dn_to_s).ou).to eq(['PEOPLE','JS','DEV'])
      dn = DN.new(dn_string: '/C=US/O=RB/OU=DEV/OU=JS/OU=People/DC=example/DC=org/CN=Last First M (initial)')
      expect(dn.ou).to eq(['PEOPLE', 'JS', 'DEV'])
      expect(dn.dc).to eq(['ORG', 'EXAMPLE'])
    end

    it "should handle multiple RDN key value pairs in the CN and return an array of elements" do
      dn = DN.new(dn_string: '/C=US/O=RB/OU=DEV/OU=JS/OU=People/DC=example/DC=org/CN=Last First M (initial)+email=initial@example.org+office=home')
      expect(dn.cn).to eq({CN: 'LAST FIRST M (INITIAL)', EMAIL: 'INITIAL@EXAMPLE.ORG', OFFICE: 'HOME'})
    end
  end

  describe "validations" do
    it "should require a parsable DN string" do
      expect{ DN.new(dn_string: "") }.to raise_error(DnDelimiterUnparsableError)
      expect{ DN.new(dn_string: "nope") }.to raise_error(DnDelimiterUnparsableError)
    end
  end

  describe ".to_s" do
    it "should return a properly formatted string for CAS & RFC1779 use" do
      dn = DN.new(dn_string: '/C=US/O=RB/OU=DEV/OU=JS/OU=People/DC=example/DC=org/CN=Last First M (initial)+email=initial@example.org+office=home')
      dn_string = 'CN=LAST FIRST M (INITIAL)+EMAIL=INITIAL@EXAMPLE.ORG+OFFICE=HOME,O=RB,OU=PEOPLE,OU=JS,OU=DEV,C=US,DC=ORG,DC=EXAMPLE'
      expect(dn.to_s).to eq(dn_string)
    end

    it "should support customized return order for RDN elements" do
      dn_string = 'CN=Last First M (initial),O=rb,OU=people,C=us,DC=org,DC=example'
      dn = DN.new(dn_string: dn_string, string_order: %w(cn ou o dc c))
      customized_string = 'CN=LAST FIRST M (INITIAL),OU=PEOPLE,O=RB,DC=ORG,DC=EXAMPLE,C=US'
      expect(dn.to_s).to eq(customized_string)
    end

    it "should parse custom DN formats into DN objects" do
      # Sample data sets
      File.readlines('spec/fixtures/custom_sort_dns.txt').each do |line|
        dn_in = line.rstrip.split('%')[0]
        dn_out = line.rstrip.split('%')[1]
        custom_order = %w(cn l st ou o c street dc uid)
        expect(DN.new(dn_string: dn_in, string_order: custom_order).to_s).to eq(dn_out)
      end
    end

    it "should parse common DN formats into DN objects" do
      pending "Implement common DN test strings"
      File.readlines('spec/fixtures/common_dns.txt').each do |line|
        dn_in = line.rstrip.split('%')[0]
        dn_out = line.rstrip.split('%')[1]
        expect(DN.new(dn_string: dn_in).to_s).to eq(dn_out)
      end
    end
  end
end
