# frozen_string_literal: true
module ElasticRubyServer
  class FilePaths
    def initialize(dir_path)
      @dir_path = dir_path
    end

    def find_each_modified_file(since:, &block)
      start_time = Time.now
      Log.debug("Watching project...")

      watch_project

      Log.debug("Watching project finished in #{Time.now - start_time} seconds")

      start_time = Time.now
      Log.debug("Querying paths...")

      since = [(since.to_i - 10), 0].max

      base_path = ENV["DOCKER"] ? "/usr/share/elasticsearch/data/watchman" : File.expand_path("./tmp")
      cmd = TTY::Command.new(printer: :null)
      run_cmd =  <<~CMD
        watchman --no-pretty --log-level=0 --no-save-state -j <<-EOT
          ["query", "#{@dir_path}", {
            "suffix": "rb",
            "expression": [
              "allof",
              ["type", "f"],
              ["since", #{since}, "ctime"]
            ],
            "fields": ["name"],
            "sync_timeout": 600000
          }]
        EOT
      CMD

      Log.debug("Running watchman command:")
      Log.debug(run_cmd)

      output, _err = cmd.run(run_cmd)

      Log.debug("Querying paths finished in #{Time.now - start_time} seconds")

      files = JSON.parse(output)["files"]
      total_count = files.count
      current_count = 0

      files.each do |file_name|
        current_count += 1
        progress = (current_count / total_count.to_f) * 100

        block.call(file_name, progress)

        if (progress >= 100) || (rand > 0.98)
          Log.debug("Progress: #{progress}%")
        end
      end

      files
    rescue TTY::Command::ExitError => e
      Log.debug("Watchman command failed:")
      Log.debug(e)
    end

    def watch_project
      base_path = ENV["DOCKER"] ? "/usr/share/elasticsearch/data/watchman" : File.expand_path("./tmp")
      cmd = TTY::Command.new(printer: :null)
      run_cmd = <<~CMD
        watchman --no-pretty --log-level=0 --no-save-state watch-project "#{@dir_path}"
      CMD

      Log.debug("Running watchman command:")
      Log.debug(run_cmd)

      output, _err = cmd.run(run_cmd)
    end
  end
end
