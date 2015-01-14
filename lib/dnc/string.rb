require 'dnc'

#
# Extend the core String class to include `.to_dn` && `.to_dn!`
#
class String
  # Parses the string to return a DN object
  # Returns nil if a DN instance cannot be created
  def to_dn
    begin
      new_dn = DN.new(dn_string: to_s)
    rescue StandardError
      new_dn = nil
    end

    new_dn
  end

  # Similar to {#to_dn}, but raises an error unless the string can be
  # explicitly parsed to a DN instance
  def to_dn!
    begin
      new_dn = DN.new(dn_string: to_s)
    rescue StandardError
      raise DnStringUnparsableError,
            "Could not force conversion to DN:\n#{inspect}"
    end

    new_dn
  end
end
