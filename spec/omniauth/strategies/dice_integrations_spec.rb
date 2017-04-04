require 'spec_helper'
require'dnc'

class MockDice; end
describe OmniAuth::Strategies::Dice, type: :strategy do
  attr_accessor :app
  let(:auth_hash)        { full_auth_hash }
  let!(:user_cert)       { File.read('spec/certs/ruby_user.crt') }
  let!(:raw_dn)          { '/DC=org/DC=ruby-lang/CN=Ruby certificate rbcert' }
  let!(:user_dn)         { DN.new(dn_string: '/DC=org/DC=ruby-lang/CN=Ruby certificate rbcert') }
  let(:raw_issuer_dn)    { '/DC=org/DC=ruby-lang/CN=Ruby CA' }
  let(:issuer_dn)        { 'CN=RUBY CA,DC=RUBY-LANG,DC=ORG' }
  let!(:valid_user_json) { File.read('spec/fixtures/valid_auth.json') }
  let(:valid_user_xml)   { File.read('spec/fixtures/valid_auth.xml') }

  def full_auth_hash
    {
      "provider"=>"dice",
      "uid"=>"cn=ruby certificate rbcert,dc=ruby-lang,dc=org",
      "extra" => {
        "raw_info" => valid_user_json
      },
      "info" => {
        "dn" => "cn=pr. twilight sparkle,ou=c001,ou=mlp,ou=pny,o=princesses of celestia,c=us",
        "email" => "twilight@example.org",
        "first_name"  => "twilight",
        "last_name"   => "sparkle",
        "full_name"   => "twilight sparkle",
        "common_name" => "pr. twilight sparkle",
        "name"        => "pr. twilight sparkle",
        "citizenship_status" => "US",
        "country" => "USA",
        "grant_by" => [
          "princess celestia"
        ],
        "organizations" => [
          "princesses",
          "librarians",
          "unicorns"
        ],
        "uid" => "twilight.sparkle",
        "dutyorg" => "ponyville library",
        "visas" => [
          "EQUESTRIA",
          "CLOUDSDALE"
        ],
        "affiliations" => [
          "WONDERBOLTS"
        ],
        "telephone_number" => "555-555-5555",
        "primary_visa?" => true,
        "likely_npe?"  => false
      }
    }
  end

  # customize rack app for testing, if block is given, reverts to default
  # rack app after testing is done
  def set_app!(dice_options = {})
    dice_options = {:model => MockDice}.merge(dice_options)
    old_app = self.app
    self.app = Rack::Builder.app do
      use Rack::Session::Cookie, :secret => '1337geeks'
      use RackSessionAccess::Middleware
      use OmniAuth::Strategies::Dice, dice_options
      run lambda{|env| [404, {'env' => env}, ["HELLO!"]]}
    end
    if block_given?
      yield
      self.app = old_app
    end
    self.app
  end

  before(:all) do
    @defaults = {
      cas_server: 'http://example.org',
      authentication_path: '/dn'
    }
  end

  describe "use_callback_url" do
    it "should use the callback_url method instead of callback_path when specified" do
      callback_url_opts = {
        cas_server: 'http://example.org',
        authentication_path: '/dn',
        use_callback_url: true
      }
      set_app!(callback_url_opts)
      header 'Ssl-Client-Cert', user_cert
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_CERT']).to eq(user_cert)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_request.env['rack.session']['omniauth.params']['user_dn']).to eq(user_dn.to_s)
      expect(last_request.env['rack.session']['omniauth.params']['issuer_dn']).to eq(issuer_dn)
      expect(last_response.location).to eq('http://example.org/auth/dice/callback')
    end
  end

  describe "custom_callback_url" do
    it "should use the custom_callback_url provided instead of default callback_path|url when specified" do
      callback_url_opts = {
        cas_server: 'http://example.org',
        authentication_path: '/dn',
        custom_callback_url: 'http://example.org/sub-uri/auth/dice/callback'
      }
      set_app!(callback_url_opts)
      header 'Ssl-Client-Cert', user_cert
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_CERT']).to eq(user_cert)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_request.env['rack.session']['omniauth.params']['user_dn']).to eq(user_dn.to_s)
      expect(last_request.env['rack.session']['omniauth.params']['issuer_dn']).to eq(issuer_dn)
      expect(last_response.location).to eq('http://example.org/sub-uri/auth/dice/callback')
    end
  end

  describe '#request_phase' do
    it 'should fail without a client DN' do
      set_app!(@defaults)
      get '/auth/dice'
      expect(last_request.env['omniauth.error.type']).to eq(:"You need a valid DN to authenticate.")
      expect(last_response.location).to eq('/auth/failure?message=You need a valid DN to authenticate.&strategy=dice')
    end

    it "should set the client & issuer's DN (from certificate)" do
      set_app!(@defaults)
      header 'Ssl-Client-Cert', user_cert
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_CERT']).to eq(user_cert)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_request.env['rack.session']['omniauth.params']['user_dn']).to eq(user_dn.to_s)
      expect(last_request.env['rack.session']['omniauth.params']['issuer_dn']).to eq(issuer_dn)
      expect(last_response.location).to eq('/auth/dice/callback')
    end

    it "should set the client's DN (from header)" do
      set_app!(@defaults)
      header 'Ssl-Client-S-Dn', raw_dn
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_S_DN']).to eq(raw_dn)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_request.env['rack.session']['omniauth.params']['user_dn']).to eq(user_dn.to_s)
      expect(last_request.env['rack.session']['omniauth.params']['issuer_dn']).to be_nil
      expect(last_response.location).to eq('/auth/dice/callback')
    end

    it "should set the issuer's DN (from header)" do
      set_app!(@defaults)
      header 'Ssl-Client-S-Dn', raw_dn
      header 'Ssl-Client-I-Dn', raw_issuer_dn
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_I_DN']).to eq(raw_issuer_dn)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_request.env['rack.session']['omniauth.params']['issuer_dn']).to eq(issuer_dn)
      expect(last_response.location).to eq('/auth/dice/callback')
    end
  end

  describe '#callback_phase' do
    before(:each) do
      callback_phase_opts = {
        cas_server:          'https://example.org:3000',
        authentication_path: '/dn',
        dnc_options: { transformation: 'downcase' },
        ssl_config:  {
          ca_file:     'spec/certs/CA.pem',
          client_cert: 'spec/certs/client.pem',
          client_key:  'spec/certs/key.np.pem'
        },
        primary_visa: 'CLOUDSDALE'
      }
      set_app!(callback_phase_opts)
      stub_request(:get, "https://example.org:3000/dn/cn=ruby%20certificate%20rbcert,dc=ruby-lang,dc=org/info.json?issuerDn=cn=ruby%20ca,dc=ruby-lang,dc=org").
        with(:headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json', 'Host'=>'example.org:3000', 'User-Agent'=>/^Faraday via Ruby.*$/, 'X-Xsrf-Useprotection'=>'false'}).
      to_return(status: 200, body: valid_user_json, headers: {})
    end

    context 'success' do
      it 'should return a 200 with a JSON object of user information on success' do
        header 'Ssl-Client-Cert', user_cert
        get '/auth/dice'
        follow_redirect!
        raw_info = last_request.env['rack.session']['omniauth.auth']['extra']['raw_info']
        expect(raw_info).to eq(valid_user_json)
      end

      it 'should return an omniauth auth_hash' do
        header 'Ssl-Client-Cert', user_cert
        get '/auth/dice'
        follow_redirect!
        raw_info = last_request.env['rack.session']['omniauth.auth']['extra']['raw_info']
        expect(last_request.env['rack.session']['omniauth.auth']).to be_kind_of(Hash)
        expect(last_request.env['rack.session']['omniauth.auth'].sort).to eq(auth_hash.sort)
      end

      it 'should return a 200 with an XML object of user information on success' do
        xml_request_opts = {
          cas_server:          'https://example.org:3000',
          authentication_path: '/dn',
          format_header:       'application/xml',
          format:              'xml',
          dnc_options: { transformation: 'downcase' },
          ssl_config:  {
            ca_file:     'spec/certs/CA.pem',
            client_cert: 'spec/certs/client.pem',
            client_key:  'spec/certs/key.np.pem'
          }
        }
        set_app!(xml_request_opts)
        stub_request(:get, "https://example.org:3000/dn/cn=ruby%20certificate%20rbcert,dc=ruby-lang,dc=org/info.xml?issuerDn=cn=ruby%20ca,dc=ruby-lang,dc=org").
        with(:headers => {'Accept'=>'application/xml', 'Content-Type'=>'application/xml', 'Host'=>'example.org:3000', 'User-Agent'=>/^Faraday via Ruby.*$/, 'X-Xsrf-Useprotection'=>'false'}).
        to_return(status: 200, body: valid_user_xml, headers: {})

        header 'Ssl-Client-Cert', user_cert
        get '/auth/dice'
        follow_redirect!
        raw_info = last_request.env['rack.session']['omniauth.auth']['extra']['raw_info']
        expect(raw_info).to eq(valid_user_xml)
      end

      it 'should allow accessing auth_hash values via methods' do
        header 'Ssl-Client-Cert', user_cert
        get '/auth/dice'
        follow_redirect!
        expect(last_request.env['rack.session']['omniauth.auth']).to be_kind_of(Hash)
        expect(last_request.env['rack.session']['omniauth.auth'].provider).to eq('dice')
      end
    end

    context 'fail' do
      it 'should raise a 404 with text for a non-existent user DN' do
        stub_request(:get, "https://example.org:3000/dn/cn=ruby%20certificate%20rbcert,dc=ruby-lang,dc=org/info.json?issuerDn=cn=ruby%20ca,dc=ruby-lang,dc=org").
        with(:headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json', 'Host'=>'example.org:3000', 'User-Agent'=>/^Faraday via Ruby.*$/, 'X-Xsrf-Useprotection'=>'false'}).
        to_return(status: 404, body: "User of dn:cn=ruby certificate rbcert,dc=ruby-lang,dc=org not found", headers: {})

        header 'Ssl-Client-Cert', user_cert
        get '/auth/dice'
        follow_redirect! # Needed to hit /auth/dice/callback & trigger errors!
        expect(last_request.env['omniauth.error.type']).to eq(:invalid_credentials)
        expect(last_response.location).to eq('/auth/failure?message=invalid_credentials&strategy=dice')
      end
    end
  end
end
