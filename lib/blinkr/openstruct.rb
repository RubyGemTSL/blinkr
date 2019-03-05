class OpenStruct
  EXCEPT = %I[response body javascript_errors].freeze

  def to_json(*args)
    to_h.delete_if {|k, _v| EXCEPT.include?(k)}.to_json(*args)
  end
end
