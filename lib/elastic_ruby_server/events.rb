# frozen_string_literal: true
module ElasticRubyServer
  class Events
    VSCodeDiagnosticSeverity = {
      error: 0,
      warning: 1,
      information: 2,
      hint: 3
    }.freeze

    def initialize(server, global_synchronization)
      @server = server
      @project = Project.new

      @global_synchronization = global_synchronization
      @local_synchronization = Concurrent::FixedThreadPool.new(3)
      @buffer_synchronization = Concurrent::FixedThreadPool.new(1)

      @open_files_buffer = {}
      @last_valid_buffer = {}
    end

    def on_initialize(params) # params: {"processId"=>54359, "clientInfo"=>{"name"=>"Visual Studio Code", "version"=>"1.56.2"}, "locale"=>"en-us", "rootPath"=>"/Users/joelkorpela/clio/themis/test", "rootUri"=>"file:///Users/joelkorpela/clio/themis/test", "capabilities"=>{"workspace"=>{"applyEdit"=>true, "workspaceEdit"=>{"documentChanges"=>true, "resourceOperations"=>["create", "rename", "delete"], "failureHandling"=>"textOnlyTransactional", "normalizesLineEndings"=>true, "changeAnnotationSupport"=>{"groupsOnLabel"=>true}}, "didChangeConfiguration"=>{"dynamicRegistration"=>true}, "didChangeWatchedFiles"=>{"dynamicRegistration"=>true}, "symbol"=>{"dynamicRegistration"=>true, "symbolKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]}, "tagSupport"=>{"valueSet"=>[1]}}, "codeLens"=>{"refreshSupport"=>true}, "executeCommand"=>{"dynamicRegistration"=>true}, "configuration"=>true, "workspaceFolders"=>true, "semanticTokens"=>{"refreshSupport"=>true}, "fileOperations"=>{"dynamicRegistration"=>true, "didCreate"=>true, "didRename"=>true, "didDelete"=>true, "willCreate"=>true, "willRename"=>true, "willDelete"=>true}}, "textDocument"=>{"publishDiagnostics"=>{"relatedInformation"=>true, "versionSupport"=>false, "tagSupport"=>{"valueSet"=>[1, 2]}, "codeDescriptionSupport"=>true, "dataSupport"=>true}, "synchronization"=>{"dynamicRegistration"=>true, "willSave"=>true, "willSaveWaitUntil"=>true, "didSave"=>true}, "completion"=>{"dynamicRegistration"=>true, "contextSupport"=>true, "completionItem"=>{"snippetSupport"=>true, "commitCharactersSupport"=>true, "documentationFormat"=>["markdown", "plaintext"], "deprecatedSupport"=>true, "preselectSupport"=>true, "tagSupport"=>{"valueSet"=>[1]}, "insertReplaceSupport"=>true, "resolveSupport"=>{"properties"=>["documentation", "detail", "additionalTextEdits"]}, "insertTextModeSupport"=>{"valueSet"=>[1, 2]}}, "completionItemKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]}}, "hover"=>{"dynamicRegistration"=>true, "contentFormat"=>["markdown", "plaintext"]}, "signatureHelp"=>{"dynamicRegistration"=>true, "signatureInformation"=>{"documentationFormat"=>["markdown", "plaintext"], "parameterInformation"=>{"labelOffsetSupport"=>true}, "activeParameterSupport"=>true}, "contextSupport"=>true}, "definition"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "references"=>{"dynamicRegistration"=>true}, "documentHighlight"=>{"dynamicRegistration"=>true}, "documentSymbol"=>{"dynamicRegistration"=>true, "symbolKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]}, "hierarchicalDocumentSymbolSupport"=>true, "tagSupport"=>{"valueSet"=>[1]}, "labelSupport"=>true}, "codeAction"=>{"dynamicRegistration"=>true, "isPreferredSupport"=>true, "disabledSupport"=>true, "dataSupport"=>true, "resolveSupport"=>{"properties"=>["edit"]}, "codeActionLiteralSupport"=>{"codeActionKind"=>{"valueSet"=>["", "quickfix", "refactor", "refactor.extract", "refactor.inline", "refactor.rewrite", "source", "source.organizeImports"]}}, "honorsChangeAnnotations"=>false}, "codeLens"=>{"dynamicRegistration"=>true}, "formatting"=>{"dynamicRegistration"=>true}, "rangeFormatting"=>{"dynamicRegistration"=>true}, "onTypeFormatting"=>{"dynamicRegistration"=>true}, "rename"=>{"dynamicRegistration"=>true, "prepareSupport"=>true, "prepareSupportDefaultBehavior"=>1, "honorsChangeAnnotations"=>true}, "documentLink"=>{"dynamicRegistration"=>true, "tooltipSupport"=>true}, "typeDefinition"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "implementation"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "colorProvider"=>{"dynamicRegistration"=>true}, "foldingRange"=>{"dynamicRegistration"=>true, "rangeLimit"=>5000, "lineFoldingOnly"=>true}, "declaration"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "selectionRange"=>{"dynamicRegistration"=>true}, "callHierarchy"=>{"dynamicRegistration"=>true}, "semanticTokens"=>{"dynamicRegistration"=>true, "tokenTypes"=>["namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator"], "tokenModifiers"=>["declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary"], "formats"=>["relative"], "requests"=>{"range"=>true, "full"=>{"delta"=>true}}, "multilineTokenSupport"=>false, "overlappingTokenSupport"=>false}, "linkedEditingRange"=>{"dynamicRegistration"=>true}}, "window"=>{"showMessage"=>{"messageActionItem"=>{"additionalPropertiesSupport"=>true}}, "showDocument"=>{"support"=>true}, "workDoneProgress"=>true}, "general"=>{"regularExpressions"=>{"engine"=>"ECMAScript", "version"=>"ES2020"}, "markdown"=>{"parser"=>"marked", "version"=>"1.1.0"}}}, "trace"=>"off", "workspaceFolders"=>[{"uri"=>"file:///Users/joelkorpela/clio/themis/test", "name"=>"test"}]}
      @project.host_workspace_path = params["rootPath"]

      raise("host_project_root not found") unless @project.host_project_root

      @search = Search.new(@project)
      @persistence = Persistence.new(@project)

      Server::Capabilities
    end

    def on_initialized(_hash)
      @server.publish_busy_status(action: "Starting Elasticsearch", percent: 0)

      Log.debug(`/app/exe/es_check.sh`)

      @server.publish_busy_status(action: "Starting Elasticsearch", percent: 100)

      queue_task(worker: @local_synchronization) do
        @persistence.create_index
        @persistence.reindex_modified_files(force: true) do |progress|
          @server.publish_busy_status(action: "Indexing", percent: progress)
        end
      end

      tick(seconds: 5)
    end

    def tick(seconds:)
      Thread.new do
        loop do
          @persistence.reindex_modified_files do |progress|
            @server.publish_busy_status(action: "Indexing", percent: progress)
          end
          sleep(seconds)
        end
      end
    end

    def on_workspace_reindex(_params)
      queue_task(worker: @local_synchronization) do
        @persistence.reindex_all_files
      end
    end

    def on_textDocument_didSave(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/test/testing.rb"}}
      queue_task(worker: @local_synchronization) do
        file_uri = params.dig("textDocument", "uri")

        publish_diagnostics(file_uri)

        @persistence.reindex(file_uri)
        @persistence.reindex_modified_files do |progress|
          @server.publish_busy_status(action: "Indexing", percent: progress)
        end
      end
    end

    def on_textDocument_didOpen(params) # "textDocument":{"uri":"file:///Users/joelkorpela/clio/themis/components/payments/spec/services/payments/stripe/provider_spec.rb","languageId":"ruby","version":1,"text":"module Payments\n  module Stripe\n    describe Provider do\n      let(:connected_account_id) { provider_account.external_id }\n      let(:provider_account) { create(:payments_stripe_account) }\n      let(:account) { provider_account.account }\n      let!(:signup) { create(:payments_stripe_signup, application_status: :success, account: account) }\n\n      subject { provider_account.provider }\n\n      describe \".#get_api_version\" do\n        subject { Payments::Stripe::Provider.get_api_version }\n\n        let(:api_version) { \"2020-08-27\" }\n\n        it \"fetches the stripe api version\" do\n          result = subject\n          expect(result).to eq(api_version)\n        end\n      end\n\n      describe \"#default_required_payment_fields\" do\n        let(:expected_default_payment_fields) { \"cvv,name,email,address1,city,state,postal_code,country\" }\n\n        it \"has the expected default required payment fields\" do\n          expect(subject.default_required_payment_fields).to eq(expected_default_payment_fields)\n        end\n      end\n\n      de...
      queue_task(worker: @buffer_synchronization) do
        file_uri = params.dig("textDocument", "uri")
        file_content = params.dig("textDocument", "text")
        file_buffer = FileBuffer.new(file_content)

        @project.last_open_file = file_uri
        @open_files_buffer[file_uri] = file_buffer

        publish_diagnostics(file_uri)
        @persistence.reindex(file_uri, content: { file_uri => file_content })
        @persistence.reindex_modified_files do |progress|
          @server.publish_busy_status(action: "Indexing", percent: progress)
        end
      end
    end

    def on_textDocument_didClose(params) # "textDocument":{"uri":"file:///Users/joelkorpela/clio/themis/components/payments/spec/services/payments/stripe/provider_spec.rb","languageId":"ruby","version":1,"text":"module Payments\n  module Stripe\n    describe Provider do\n      let(:connected_account_id) { provider_account.external_id }\n      let(:provider_account) { create(:payments_stripe_account) }\n      let(:account) { provider_account.account }\n      let!(:signup) { create(:payments_stripe_signup, application_status: :success, account: account) }\n\n      subject { provider_account.provider }\n\n      describe \".#get_api_version\" do\n        subject { Payments::Stripe::Provider.get_api_version }\n\n        let(:api_version) { \"2020-08-27\" }\n\n        it \"fetches the stripe api version\" do\n          result = subject\n          expect(result).to eq(api_version)\n        end\n      end\n\n      describe \"#default_required_payment_fields\" do\n        let(:expected_default_payment_fields) { \"cvv,name,email,address1,city,state,postal_code,country\" }\n\n        it \"has the expected default required payment fields\" do\n          expect(subject.default_required_payment_fields).to eq(expected_default_payment_fields)\n        end\n      end\n\n      de...
      queue_task(worker: @buffer_synchronization) do
        file_uri = params.dig("textDocument", "uri")
        @project.last_open_file = ""
        @open_files_buffer.delete(file_uri)
        @server.publish_diagnostics(file_uri, [])
        @persistence.reindex_modified_files do |progress|
          @server.publish_busy_status(action: "Indexing", percent: progress)
        end
      end
    end

    def on_textDocument_didChange(params) # {"textDocument":{"uri":"file:///Users/joelkorpela/clio/themis/components/payments/spec/services/payments/stripe/provider_spec.rb","version":3},"contentChanges":[{"range":{"start":{"line":8,"character":6},"end":{"line":8,"character":6}},"rangeLength":0,"text":"\n      "},{"range":{"start":{"line":8,"character":0},"end":{"line":8,"character":6}},"rangeLength":6,"text":""}]}
      queue_task(worker: @buffer_synchronization) do
        file_uri = params["textDocument"]["uri"]
        file_buffer = @open_files_buffer[file_uri]
        file_changes = params["contentChanges"]

        maybe_invalid_content = file_buffer.change!(file_changes)
        serializer = Serializer.new(@project, file_path: file_uri, content: maybe_invalid_content)

        if serializer.valid_ast?
          @last_valid_buffer[file_uri] = file_buffer.dup
        end

        if @buffer_synchronization.queue_length == 0
          sleep(0.1)

          if @buffer_synchronization.queue_length == 0
            if @last_valid_buffer[file_uri]
              publish_diagnostics(file_uri)
              @persistence.reindex(file_uri, content: { file_uri => @last_valid_buffer[file_uri].text })
            end
          end
        end
      end
    end

    def on_textDocument_completion(params) # {"textDocument":{"uri":"file:///Users/joelkorpela/dev/elastic_ruby_server/lib/elastic_ruby_server/events.rb"},"position":{"line":105,"character":7},"context":{"triggerKind":2,"triggerCharacter":"."}}
      return [] if params["context"]["triggerKind"] != 2

      @buffer_synchronization.shutdown
      @buffer_synchronization.wait_for_termination(10)
      @buffer_synchronization = Concurrent::FixedThreadPool.new(1)

      file_uri = params.dig("textDocument", "uri")
      position = params["position"]
      position["character"] -= 1

      definitions = @search.find_definitions(file_uri, params["position"])
      definition = definitions.first

      if definition && definition["_source"]["type"] == "class"
        klass = definition["_source"]["name"]
      else
        return nil
      end

      @search.find_method_definitions(klass)
    end

    def on_textDocument_definition(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/test/testing.rb"}, "position"=>{"line"=>19, "character"=>16}}
      file_uri = params.dig("textDocument", "uri")
      cursor = params["position"]

      @project.last_open_file = file_uri

      @search.find_definitions(file_uri, cursor).map do |doc|
        SymbolLocation.build(
          source: doc["_source"],
          workspace_path: @project.host_workspace_path
        )
      end
    end

    def on_textDocument_documentHighlight(params)
      file_uri = params.dig("textDocument", "uri")
      cursor = params["position"]

      @search.find_references(file_uri, cursor).map do |doc|
        SymbolLocation.build(
          source: doc["_source"],
          workspace_path: @project.host_workspace_path
        )
      end
    end

    def on_textDocument_references(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/test/testing.rb"}, "position"=>{"line"=>36, "character"=>8}, "context"=>{"includeDeclaration"=>true}}
      file_uri = params.dig("textDocument", "uri")
      cursor = params["position"]

      @project.last_open_file = file_uri

      @search.find_references(file_uri, cursor).map do |doc|
        SymbolLocation.build(
          source: doc["_source"],
          workspace_path: @project.host_workspace_path
        )
      end
    end

    def on_textDocument_documentSymbol(params)
      @search.find_symbols_for_file(params.dig("textDocument", "uri"))
    end

    def on_textDocument_rangeFormatting(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/components/manage/app/models/manage/user.rb"}, "range"=>{"start"=>{"line"=>581, "character"=>0}, "end"=>{"line"=>582, "character"=>38}}, "options"=>{"tabSize"=>2, "insertSpaces"=>true, "trimTrailingWhitespace"=>true}}
      @server.publish_busy_status(action: "Formatting", percent: 0)

      @buffer_synchronization.shutdown
      @buffer_synchronization.wait_for_termination(10)
      @buffer_synchronization = Concurrent::FixedThreadPool.new(1)

      file_uri = params.dig("textDocument", "uri")
      file_buffer = @open_files_buffer[file_uri]
      formatted_range = file_buffer.format_range(params["range"])

      @server.publish_busy_status(action: "Formatting", percent: 100)

      formatted_range ? formatted_range : []
    end

    def on_textDocument_rename(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/components/manage/app/models/manage/user_goal.rb"}, "position"=>{"line"=>55, "character"=>9}, "newName"=>"goal_mask2"}
      file_uri = params.dig("textDocument", "uri")
      cursor = params["position"]

      references =
        @search.find_references(file_uri, cursor).map do |doc|
          SymbolLocation.build(
            source: doc["_source"],
            workspace_path: @project.host_workspace_path
          ).merge(
            type: doc["_source"]["type"]
          )
        end

      references_by_uri = references.group_by { |reference| reference[:uri] }
      references_by_uri = references_by_uri.map do |uri, edits|
        edits.map! do |edit|
          edit.delete(:uri)

          type = edit.delete(:type)
          edit[:newText] = params["newName"]

          case type
          when "cvar"
            edit[:newText] = "@@#{edit[:newText]}"
          when "ivar"
            edit[:newText] = "@#{edit[:newText]}"
          when "sym"
            lines = @open_files_buffer[file_uri].text.lines
            line = lines[edit[:range][:start][:line]]

            if line[edit[:range][:start][:character]] == ":"
              edit[:newText] = ":#{edit[:newText]}"
            end
          end

          edit
        end

        [uri, edits]
      end.to_h

      { changes: references_by_uri }
    end

    def on_workspace_symbol(params) # {"query"=>"abc"}
      @search.find_symbols(params["query"])
    end

    private

    def publish_diagnostics(uri)
      diagnostics = []
      path = Utils.readable_path(@project, uri)
      # rubocop_config = Utils.readable_path(@project, ".rubocop.yml")
      rubocop_config = "/app/.rubocop-diagnostics.yml"
      file_buffer = @open_files_buffer[uri]

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      begin
        cmd = TTY::Command.new(printer: :null)
        results, _err =
          cmd.run(
            "/usr/local/bin/rubocop-daemon-wrapper/rubocop -s #{path} --config #{rubocop_config} --format json --fail-level fatal",
            input: file_buffer.text
          )
      rescue TTY::Command::ExitError => e
        Log.debug("Rubocop Diagnostics Error:")
        Log.debug(e)
      end

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed = end_time - start_time

      Log.debug("Rubocop Diagnostics Elapsed time: #{elapsed} seconds")

      results = JSON.parse(results)
      offenses = results["files"].first["offenses"]

      offenses.each do |offense|
        loc = offense["location"]

        diagnostics << {
          severity: diagnostic_severity(offense["severity"]),
          message: "#{offense["message"]} (#{offense["severity"]}:#{offense["cop_name"]})",
          range: {
            start: {
              line: loc["start_line"] - 1,
              character: loc["start_column"] - 1
            },
            end: {
              line: loc["last_line"] - 1,
              character: loc["last_column"]
            }
          }
        }
      end

      @server.publish_diagnostics(uri, diagnostics)
    rescue JSON::ParserError
      # todo: send error about bad rubocop config to client
    end

    def diagnostic_severity(rubocop_severity)
      case rubocop_severity
      when "convention" then VSCodeDiagnosticSeverity[:hint]
      when "refactor"   then VSCodeDiagnosticSeverity[:hint]
      when "info"       then VSCodeDiagnosticSeverity[:information]
      when "warning"    then VSCodeDiagnosticSeverity[:warning]
      when "error"      then VSCodeDiagnosticSeverity[:error]
      when "fatal"      then VSCodeDiagnosticSeverity[:error]
      else                   VSCodeDiagnosticSeverity[:error]
      end
    end

    def queue_task(worker:)
      worker.post do
        yield
      rescue => e
        Log.debug("Error in thread:")
        Log.debug(e)
      end
    end
  end
end
