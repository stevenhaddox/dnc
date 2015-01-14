require 'logging'

# Custom exception for strings that can't be parsed as per RFC1779
class DnDelimiterUnparsableError < TypeError; end
# Custom exception for strings that can't be parsed as per RFC1779
class DnStringUnparsableError < TypeError; end

# rubocop:disable ClassLength
# Accepts various DN strings and returns a DN object
class DN
  attr_accessor :original_dn, :dn_string, :delimiter, :transformation,
                :string_order, :cn, :l, :st, :ou, :o, :c, :street, :dc, :uid

  # Initialize the instance
  #
  # @param opts [Hash] Options hash for new DN instance attribute values
  # @param opts[:dn_string] [String] The DN string you want to parse into a DN
  # @param opts[:logger] User provided logger vs Rails / Logging default logger
  # NOTE: opts[transformation] defaults to "upcase"; use "to_s" for no change.
  # @param opts[:transformation] [String] String method for changing DN.
  # @param opts[:delimiter] [String] Specify a custom delimiter for dn_string
  # NOTE: opts[:string_order] is a last resort config, defaults to RFC4514 spec.
  # @param opts[:string_order] [Array] Specify the order of RDNs for .to_s
  # @return [DN]
  def initialize(opts = {})
    @dn_string      = opts[:dn_string]
    fail 'dnc: dn_string parameter is **required**' if dn_string.nil?
    @original_dn    = dn_string
    @logger         = opts[:logger] || logger
    @transformation = opts[:transformation] || 'upcase'
    @string_order   = opts[:string_order] || %w(cn l st o ou c street dc uid)
    @delimiter      = opts[:delimiter] || identify_delimiter
    format_dn
  end

  # logger method to return Rails logger if defined, else logging logger
  def logger
    return @logger if @logger
    logger = Logging.logger[self]
    @logger ||= Kernel.const_defined?('Rails') ? Rails.logger : logger
  end

  # Convert DN object into a string (order follows RFC4514 LDAP specifications)
  def to_s
    return_string = ''
    @string_order.each do |string_name|
      unless send(string_name.to_sym).blank?
        return_string += ',' unless return_string.empty?
        return_string += send("#{string_name}_string".to_sym)
      end
    end

    return_string
  end

  # Split passed DN by identified delimiter
  def split_by_delimiter
    dn_string.split(delimiter).reject(&:empty?)
  end

  private

  # Orchestrates reformatting DN to expected element order for LDAP auth.
  def format_dn
    # Transform dn_string for consistency / uniqueness
    @dn_string = dn_string.send(transformation.to_sym)
    format_dn_element_order unless dn_begins_properly?(dn_string)
    parse_rdns_to_attrs
    self
  end

  # Parse @dn_string RDNs and assign them to DN attributes
  def parse_rdns_to_attrs
    split_by_delimiter.each do |rdn|
      if rdn.include?('+')
        parse_nested_rdn(rdn)
      else
        parse_top_level_rdn(rdn)
      end
    end

    self
  end

  def parse_top_level_rdn(rdn)
    rdn_array = rdn.split('=')
    method = rdn_array[0].downcase.to_sym
    value  = rdn_array[1]
    if send(method).blank?
      assign_rdn_as_string(method, value)
    else
      assign_rdn_as_array(method, value)
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

  def assign_rdn_as_string(method_name, value)
    send("#{method_name}=", value)
  end

  def assign_rdn_as_array(method_name, value)
    send("#{method_name}=", Array.wrap(send(method_name)))
    send("#{method_name}").push(value)
  end

  # Ensure order of DN elements is proper for CAS server
  def format_dn_element_order
    formatted_dn = split_by_delimiter.reverse.join(delimiter)
    if dn_begins_properly?(formatted_dn)
      @dn_string = formatted_dn
    else
      fail "DN invalid format for LDAP authentication, DN:\r\n#{original_dn}"
    end
  end

  # Verify DN starts with 'CN='
  def dn_begins_properly?(dn_str)
    if dn_str.nil?
      false
    else
      with_delim = "#{delimiter}/CN=".send(@transformation.to_sym)
      without_delim = 'CN='.send(@transformation.to_sym)
      dn_str.start_with?(without_delim) || dn_str.start_with?(with_delim)
    end
  end

  # Regex to match the DN delimiter by getting the 2nd key non-word predecessor
  def delimiter_regexp
    /\A.*=.*((([^\w\s\+\)\(])|([_]))\s?)\w+=.*\z/
  end

  # Identify and set the DN delimiter
  def identify_delimiter
    logger.debug("DN.identify_delimeter: #{dn_string}")
    delimiter_regexp.match(dn_string)[1]
    rescue
      raise DnDelimiterUnparsableError, "DN delimiter could not be identified
             \r\nPlease ensure your string complies with RFC1779 formatting."
  end

  def method_missing(method_name)
    # Catch methods that end with _string
    method_match = method_name.to_s.match(/(.+)_string\z/)
    unless method_match.blank?
      method = method_match[1]
      method_class = send(method.to_sym).class
      return send(:dynamic_strings, method.to_s, method_class)
    end

    super
  end

  # Dynamically format the "#{attr}_string" method by value's class type
  def dynamic_strings(getter_method, value_class)
    send("dn_#{value_class.to_s.downcase}_to_string".to_sym, getter_method)
  end

  # NOTE:
  # The following methods are a code smell, they handle formatting the values
  # in DN attrs and converting them into a string format based upon their class

  # Dynamically define a method to return DN array values as string format
  def dn_array_to_string(getter_method)
    return_string = ''
    value = send(getter_method.to_sym)
    value.each do |element|
      return_string += ',' unless return_string.empty?
      return_string += "#{getter_method.to_s.upcase}=#{element}"
    end

    return_string
  end

  # Dynamically define a method to return DN hash values as string format
  def dn_hash_to_string(getter_method)
    return_string = ''
    value = send(getter_method.to_sym)
    value.each do |key, string|
      return_string += '+' unless return_string.empty?
      return_string += "#{key}=#{string}"
    end

    return_string
  end

  # Dynamically define a method to return DN string values as string format
  def dn_string_to_string(getter_method)
    "#{getter_method.to_s.upcase}=#{send(getter_method.to_sym)}"
  end
end
