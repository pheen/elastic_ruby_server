# frozen_string_literal: true
module ElasticRubyServer
  class PathFinder
    class << self
      def search(dir_path)
        Find.find(dir_path) do |file_path|
          next Find.prune if git_ignored_path?(file_path, dir_path)
          next unless File.fnmatch?("*.rb", file_path, File::FNM_DOTMATCH)

          yield(file_path)
        end
      end

      private

      def git_ignored_path?(path, dir_path)
        return false if @gitignore_missing

        @git_ignore ||= File.open("#{dir_path}/.gitignore").read
        @git_ignore.each_line do |line|
          pattern = line[0..-2]
          return true if File.fnmatch?("./#{pattern}*", path, File::FNM_DOTMATCH)
        end

        false
      rescue Errno::ENOENT
        @gitignore_missing = true
        false
      end
    end
  end
end