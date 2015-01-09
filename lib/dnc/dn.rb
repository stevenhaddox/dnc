require 'logging'

# Custom exception for strings that can't be parsed as X509 Certificates
class DnDelimiterUnparseableError < TypeError; end
# Custom exception for strings that can't be parsed as X509 Certificates
class DnStringUnparseableError < TypeError; end
# Custom exception for strings that can't be parsed as X509 Certificates
class DoingItWrongError < TypeError; end

# Accepts various DN strings and returns a DN object
class DN
  attr_accessor :original_dn, :dn_string, :delimiter,
    :cn, :l, :st, :o, :ou, :c, :street, :dc

  # Initialize the instance
  #
  # @param opts [Hash] Options hash for new DN instance attribute values
  # @param opts[:dn_string] [String] The DN string you want to parse into a DN
  # @param opts[:logger] User provided logger vs Rails / Logging default logger
  def initialize(opts={})
    @dn_string = opts[:dn_string]
    @original_dn = dn_string
    fail "dnc: dn_string parameter is **required**" if dn_string.nil?
    @logger = opts[:logger].nil? ? logger : opts[:logger]
    @delimiter = opts[:delimiter].nil? ? identify_delimiter : opts[:delimiter]
    format_dn
  end

  # logger method to return Rails logger if defined, else logging logger
  def logger
    return @logger if @logger
    logger = Logging.logger[self]
    @logger ||= Kernel.const_defined?('Rails') ? Rails.logger : logger
  end

  # Returns the DN's Common Name value
  def cn
    Array.wrap(@cn)
  end

  # Returns the DN's Organizational Unit value
  def ou
    Array.wrap(@ou)
  end

  # Returns the DN's DC (Domain C?) value
  def dc
    Array.wrap(@dc)
  end

  # Split passed DN by identified delimiter
  def split_by_delimiter
    dn_string.split(delimiter).reject!(&:empty?)
  end

  private

  # Orchestrates reformatting DN to expected element order for LDAP auth.
  def format_dn
    dn_string.upcase! # Upcase all DNs for consistency
    format_dn_element_order unless dn_begins_properly?(dn_string)
    parse_rdns_to_attrs

    self
  end

  # Parse @dn_string RDNs and assign them to DN attributes
  def parse_rdns_to_attrs
    split_by_delimiter.each do |rdn|
      unless rdn.include?('+')
        parse_top_level_rdn(rdn)
      else
        parse_nested_rdn(rdn)
      end
    end

    self
  end

  def parse_top_level_rdn(rdn)
    rdn_array = rdn.split('=')
    method = rdn_array[0].downcase.to_sym
    value  = rdn_array[1]
    unless send(method).nil? || send(method).empty?
      send("#{method}=", Array.wrap(send(method)))
      send("#{method}").insert(0, value)
    else
      send("#{method}=", value)
    end
  end

  def parse_nested_rdn(rdn)
    rdn_keypairs = {}
    rdn_array = rdn.split('+')
    rdn_array.each do |string|
      keypair = string.split('=')
      rdn_keypairs[keypair[0].to_sym] = keypair[1]
    end

    send("#{rdn_keypairs.keys.first.downcase}=", rdn_keypairs)
  end

  # Ensure order of DN elements is proper for CAS server with ',' delimiter
  def format_dn_element_order
    formatted_dn = split_by_delimiter.reverse.join(delimiter)
    if dn_begins_properly?(formatted_dn)
      dn_string = formatted_dn
    else
      fail("DN invalid format for LDAP authentication, DN:\r\n#{original_dn}")
    end
  end

  # Verify DN starts with 'CN='
  def dn_begins_properly?(dn_str)
    dn_str.nil? ? false : dn_str.start_with?('CN=')
  end

  # Regex to match the DN delimiter by getting the 2nd key non-word predecessor
  def delimiter_regexp
    /\A.*=.*((([^\w\s\+\)\(])|([_]))\s?)\w+=.*\z/
  end

  # Identify and set the DN delimiter
  def identify_delimiter
    begin
      logger.debug("DN.identify_delimeter: #{dn_string}")
      delimiter_regexp.match(dn_string)[1]
    rescue
      fail DnDelimiterUnparseableError, "DN delimiter could not be identified."
    end
  end

  def validate_delimiter
    begin
      raise "Regex goes here!"
    rescue
      fail DoingItWrongError, "dnc: Please update RDNs to follow RFC1779
        specifications.\nDN being parsed was: #{original_dn}"
    end
  end
end
