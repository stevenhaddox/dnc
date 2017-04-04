#
# Extend the core String class to include `.to_snake`
#
class String
  # Attempts to convert a string into a formatted_snake_case_string
  def to_snake
    gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .downcase
  end
end
