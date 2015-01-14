#
# Extend the core Array class to include `.wrap`
#
class Array
  # Duplication of Ruby on Rails Array#wrap method
  def self.wrap(object)
    if object.nil?
      []
    elsif object.respond_to?(:to_ary)
      object.to_ary || [object]
    else
      [object]
    end
  end
end
