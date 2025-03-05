class ShortRandom
  ##
  # Returns a short, alphanumeric value that is guaranteed to be unique for a
  # given object

  def self.value(obj)
    Base64.strict_encode64(obj.object_id.to_s).delete("=").to_sym
  end
end
