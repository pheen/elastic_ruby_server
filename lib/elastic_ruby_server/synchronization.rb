module ElasticRubyServer
  class Synchronization
    FileSliceSize = 100

    def initialize
      @thread_pool = Concurrent::FixedThreadPool.new(5)
    end

    def request_reindex(file_paths, &block)
      @thread_pool.post do
        block.call
      end
    end

    def reindex_files(persistence, workspace_path, files_paths)
      @persistence = persistence
      @git = git_instance(workspace_path)

      if @git
        # Thread.new do
          reindex_git_enabled_workspace(workspace_path)
        # end
      else
        @persistence.reindex(*file_paths)
      end
    end

    def record_workspace_git_sha(workspace_path)
      @git = git_instance(workspace_path)

      return unless @git

      git_sha_map[workspace_path] = @git.log[0].sha
    end

    private

    def reindex_git_enabled_workspace(workspace_path)
      iterations = 0

      while true
        Log.debug("loop #{iterations}")
        latest_sha = @git.log[0].sha

        Log.debug("loop latest sha: #{latest_sha}: latest? #{git_sha_map[workspace_path]}")

        break if git_sha_map[workspace_path] != latest_sha
        sleep(1)

        iterations += 1
        break if iterations > 5
      end

      latest_sha = @git.log[0].sha

      Log.debug("Latest SHA: #{latest_sha}")
      Log.debug("SHA map: #{git_sha_map}")

      if git_sha_map[workspace_path] == latest_sha
        # latest_sha is used as a mutex to prevent multiple
        # threads reindexing the same workspace
        Log.debug("latest sha found, exiting")
        return
      else
        last_recorded_sha = git_sha_map[workspace_path]
        git_sha_map[workspace_path] = latest_sha
      end

      Log.debug("Reindexing latest SHA")

      reindex_diff(workspace_path, last_recorded_sha)
    end

    def reindex_diff(workspace_path, sha)
      Log.debug("Starting reindex_diff")

      diffs = @git.diff(sha)

      Log.debug("Reindexing diffs count: #{diffs.count}")

      diffs.each_slice(FileSliceSize) do |diffs_slice|
        file_paths = diffs_slice.to_a.map(&:path)
        file_paths.uniq!
        file_paths.filter! { |path| path.end_with?(".rb") }
        file_paths.map! { |path| "#{workspace_path}/#{path}" }

        Log.debug("Syncing files slice:")
        Log.debug(file_paths)

        @persistence.reindex(*file_paths)
      end
    end

    def git_instance(workspace_path)
      Git.open(workspace_path)
    rescue ArgumentError
      # workspace_path isn't a git repository
    end

    def git_sha_map
      @git_sha_map ||= {}
    end
  end
end
