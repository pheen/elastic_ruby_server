module ElasticRubyServer
  class Project
    def initialize
      @host_project_roots = ENV.fetch("HOST_PROJECT_ROOTS")
      @project_root = ENV.fetch("PROJECTS_ROOT")
    end

    attr_accessor :host_workspace_path

    def name
      # match the last directory in host_project_root
      @name ||=
        host_project_root.match(/\/([^\/]*?)(\/$|$)/)[1]
    end

    def elasticsearch_index_name
      @elasticsearch_index_name ||=
        Digest::SHA1.hexdigest(host_workspace_path)
    end

    def container_workspace_path
      @container_workspace_path ||=
        host_workspace_path.sub(host_project_root, "#{@project_root}#{project_name}")
    end

    def host_project_root
      @host_project_roots
        .split(",")
        .map { |path| path.delete("\"") } # Strange, not sure why these slashes are being added
        .keep_if { |path| @host_workspace_path.match?(path) }
        .sort_by(&:length)
        .last
    end
  end
end
