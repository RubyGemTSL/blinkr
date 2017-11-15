# Monkeypatch OpenStruct
class OpenStruct
  EXCEPT = %I[response body resource_errors javascript_errors].freeze

  def to_json(*args)
    to_h.delete_if {|k, _v| EXCEPT.include?(k)}.to_json(*args)
  end
end
