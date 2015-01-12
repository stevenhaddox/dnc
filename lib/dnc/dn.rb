require 'logging'

# Custom exception for strings that can't be parsed as per RFC1779
class DnDelimiterUnparsableError < TypeError; end
# Custom exception for strings that can't be parsed as per RFC1779
class DnStringUnparsableError < TypeError; end

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

  # Split passed DN by identified delimiter
  def split_by_delimiter
    dn_string.split(delimiter).reject!(&:empty?)
  end

  # Convert DN object into a string
  def to_s
    return_string = ""
    return_string += cn_string     unless cn.nil?     || cn.empty?
    return_string += l_string      unless l.nil?      || l.empty?
    return_string += st_string     unless st.nil?     || st.empty?
    return_string += o_string      unless o.nil?      || o.empty?
    return_string += ou_string     unless ou.nil?     || ou.empty?
    return_string += c_string      unless c.nil?      || c.empty?
    return_string += street_string unless street.nil? || street.empty?
    return_string += dc_string     unless dc.nil?     || dc.empty?

    return_string
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
      fail DnDelimiterUnparsableError, "DN delimiter could not be identified
             \r\nPlease ensure your string complies with RFC1779 formatting."
    end
  end

  # Catch *_string methods and define them to return strings by value's class
  def method_missing(method, *args)
    ap "method_missing for #{method}"
    # Dynamically handle DN *_string methods by object type returned
    if method.to_s.include?('_string')
      getter_method = method.to_s.gsub('_string','')
      method_value = send(getter_method.to_sym)
      dynamic_strings(method, getter_method, method_value.class)
    end

    super
  end

  # Identify which RDN string formatteer to call by value's class
  def dynamic_strings(string_method, getter_method, value_class)
    ap ".dynamic_strings: #{string_method}, #{getter_method}, #{value_class}"
    case value_class.to_s
    when Array.to_s
      dn_array_to_string(string_method, getter_method)
    when Hash.to_s
      dn_hash_to_string(string_method, getter_method)
    when String.to_s
      dn_string_to_string(string_method, getter_method)
    else
      logger.error "Invalid string accessor method class: #{value_class}"
      fail "Invalid string accessor method class: #{value_class}"
    end
  end

  # NOTE:
  # The following methods are a code smell, they handle formatting the values
  # in DN attrs and converting them into a string format based upon their class

  # Dynamically define a method to return DN array values as string format
  def dn_array_to_string(string_method, getter_method)
    ap "Definining: #{string_method.to_sym}"
    self.class.send(:define_method, string_method.to_sym) do
      ap "Inside #{string_method.to_sym}"
      return_string = ""
      value = self.send(getter_method.to_sym)
      value.each do |element|
        return_string += "," unless return_string.empty?
        return_string += "#{getter_method.to_s.upcase}=element"
      end
      return return_string
    end
    ap "#{string_method} defined...?"
  end

  # Dynamically define a method to return DN hash values as string format
  def dn_hash_to_string(string_method, getter_method)
    ap "Definining: #{string_method.to_sym}"
    self.class.send(:define_method, string_method.to_sym) do

    end
  end

  # Dynamically define a method to return DN string values as string format
  def dn_string_to_string(string_method, getter_method)
    ap "Definining: #{string_method.to_sym}"
    self.class.send(:define_method, string_method.to_sym) do

    end
  end
end
