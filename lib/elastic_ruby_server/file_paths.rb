# frozen_string_literal: true
module ElasticRubyServer
  class FilePaths
    def initialize(dir_path)
      @dir_path = dir_path

      Log.debug("dir_path: #{dir_path}")

      @git = Dir.exists?("#{dir_path}/.git") ? Git.open(@dir_path) : nil
    end

    def find_each(&block)
      if @git
        find_each_modified_file(&block)
        find_each_branch_diff_file(&block)
        find_each_committed_file(&block)
      else
        find_each_file(&block)
      end
    end

    def find_each_modified_file(&block)
      # todo: track known files and subtract current moffieied for delted

      return unless @git

      status = @git.lib.send(:command, "status --short --no-renames --untracked-files")
      status.split("\n").each do |line|
        next unless line.end_with?(".rb")

        path = line[3..-1] # remove git notation from the beginning of the line
        block.call("#{@dir_path}/#{path}")
      end
    end

    def find_each_branch_diff_file(&block)
      return unless @git

      # todo: track branch so we can roll back when switching to master

      begin
        @git.diff("master", "head").each do |status_file|
          block.call("#{@dir_path}/#{status_file.path}")
        end
      rescue Git::GitExecuteError
      end

      begin
        @git.diff("main", "head").each do |status_file|
          block.call("#{@dir_path}/#{status_file.path}")
        end
      rescue Git::GitExecuteError
      end
    end

    private

    def find_each_committed_file(&block)
      @git.ls_files.keys.each do |path|
        next unless path.end_with?(".rb")
        block.call("#{@dir_path}/#{path}")
      end
    end

    def git_ignored_path?(path)
      return false if @gitignore_missing

      git_ignore.each_line do |line|
        pattern = line[0..-2]
        return true if File.fnmatch?("./#{pattern}*", path, File::FNM_DOTMATCH)
      end

      false
    rescue Errno::ENOENT
      @gitignore_missing = true
      false
    end

    def git_ignore
      @git_ignore ||= File.open("#{@dir_path}/.gitignore").read
    end

    def find_each_file(&block)
      Find.find(@dir_path) do |file_path|
        next Find.prune if git_ignored_path?(file_path)
        next unless File.fnmatch?("*.rb", file_path, File::FNM_DOTMATCH)

        block.call(file_path)
      end
    end
  end
end
