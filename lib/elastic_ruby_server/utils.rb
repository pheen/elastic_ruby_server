module ElasticRubyServer
  class Utils
    def self.strip_protocol(uri)
      if uri.start_with?("file:")
        uri[7..-1]
      else
        uri
      end
    end

    def self.searchable_path(path)
      path = strip_protocol(path)
      path.sub(@project.host_workspace_path, "")
    end

    def self.readable_path(path)
      "#{@project.container_workspace_path}#{searchable_path(path)}",
    end
  end
end
