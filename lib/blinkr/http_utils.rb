require 'uri'

module Blinkr
  module HttpUtils
    def sanitize(dest, src)
      return nil if dest.nil? || src.nil? || dest.include?('javascript:void(0)') || /tel:/ === dest

      # src is the page that tried to load the URL
      # URI fails to handle #! style fragments, so we chomp them
      src = src[0, src.rindex('#!')] unless src.rindex('#!').nil?
      src_uri = URI(src)

      # Remove the query and fragment from the SRC URI, as we are going to use it to resolve the relative dest URIs
      src_uri.query = nil
      src_uri.fragment = nil

      # base is the web root of the site
      base_uri = URI(@config.base_url)

      begin
        # dest is the URL we are trying to load
        dest_uri = URI(dest)
        dest_uri.fragment = nil if @config.ignore_fragments

        # If we have a relative URI, or just a fragment, join what we have to our base URL
        dest_uri = URI.join(src_uri, dest) if (empty?(dest_uri.path) && !empty?(dest_uri.fragment)) || dest_uri.relative?

        # If we have an absolute path URI, join it to the base URL
        dest_uri = URI.join(base_uri.scheme, base_uri.hostname, base_uri.port, dest_uri) if empty?(dest_uri.scheme) && empty?(dest_uri.hostname)

        # switch multiple '/' to just one. Those types of URIs don't affect the browser,
        # but they do affect our checking
        dest_uri.path = dest_uri.path.gsub(%r{/\/+/}, '/') if dest_uri.path
        dest_uri.query = dest_uri.query.gsub(%r{/\/+/}, '/') if dest_uri.query
        dest_uri.fragment = dest_uri.query.gsub(%r{/\/+/}, '/') if dest_uri.fragment

        dest = dest_uri.to_s
      rescue URI::InvalidURIError, URI::InvalidComponentError, URI::BadURIError
        return nil
      rescue StandardError
        return nil
      end
      dest.chomp('#')
    end

    private

    def empty?(str)
      str.nil? || str.empty?
    end
  end
end
