# frozen_string_literal: true
module ElasticRubyServer
  class Events
    def initialize(global_synchronization)
      @host_project_roots = ENV.fetch("HOST_PROJECT_ROOTS")
      @project_root = ENV.fetch("PROJECTS_ROOT")
      @global_synchronization = global_synchronization
      @local_synchronization = Concurrent::FixedThreadPool.new(3)
      @buffer_synchronization = Concurrent::FixedThreadPool.new(1)
      @open_files_buffer = {}
      @last_valid_buffer = {}
    end

    def on_initialize(params) # params: {"processId"=>54359, "clientInfo"=>{"name"=>"Visual Studio Code", "version"=>"1.56.2"}, "locale"=>"en-us", "rootPath"=>"/Users/joelkorpela/clio/themis/test", "rootUri"=>"file:///Users/joelkorpela/clio/themis/test", "capabilities"=>{"workspace"=>{"applyEdit"=>true, "workspaceEdit"=>{"documentChanges"=>true, "resourceOperations"=>["create", "rename", "delete"], "failureHandling"=>"textOnlyTransactional", "normalizesLineEndings"=>true, "changeAnnotationSupport"=>{"groupsOnLabel"=>true}}, "didChangeConfiguration"=>{"dynamicRegistration"=>true}, "didChangeWatchedFiles"=>{"dynamicRegistration"=>true}, "symbol"=>{"dynamicRegistration"=>true, "symbolKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]}, "tagSupport"=>{"valueSet"=>[1]}}, "codeLens"=>{"refreshSupport"=>true}, "executeCommand"=>{"dynamicRegistration"=>true}, "configuration"=>true, "workspaceFolders"=>true, "semanticTokens"=>{"refreshSupport"=>true}, "fileOperations"=>{"dynamicRegistration"=>true, "didCreate"=>true, "didRename"=>true, "didDelete"=>true, "willCreate"=>true, "willRename"=>true, "willDelete"=>true}}, "textDocument"=>{"publishDiagnostics"=>{"relatedInformation"=>true, "versionSupport"=>false, "tagSupport"=>{"valueSet"=>[1, 2]}, "codeDescriptionSupport"=>true, "dataSupport"=>true}, "synchronization"=>{"dynamicRegistration"=>true, "willSave"=>true, "willSaveWaitUntil"=>true, "didSave"=>true}, "completion"=>{"dynamicRegistration"=>true, "contextSupport"=>true, "completionItem"=>{"snippetSupport"=>true, "commitCharactersSupport"=>true, "documentationFormat"=>["markdown", "plaintext"], "deprecatedSupport"=>true, "preselectSupport"=>true, "tagSupport"=>{"valueSet"=>[1]}, "insertReplaceSupport"=>true, "resolveSupport"=>{"properties"=>["documentation", "detail", "additionalTextEdits"]}, "insertTextModeSupport"=>{"valueSet"=>[1, 2]}}, "completionItemKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]}}, "hover"=>{"dynamicRegistration"=>true, "contentFormat"=>["markdown", "plaintext"]}, "signatureHelp"=>{"dynamicRegistration"=>true, "signatureInformation"=>{"documentationFormat"=>["markdown", "plaintext"], "parameterInformation"=>{"labelOffsetSupport"=>true}, "activeParameterSupport"=>true}, "contextSupport"=>true}, "definition"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "references"=>{"dynamicRegistration"=>true}, "documentHighlight"=>{"dynamicRegistration"=>true}, "documentSymbol"=>{"dynamicRegistration"=>true, "symbolKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]}, "hierarchicalDocumentSymbolSupport"=>true, "tagSupport"=>{"valueSet"=>[1]}, "labelSupport"=>true}, "codeAction"=>{"dynamicRegistration"=>true, "isPreferredSupport"=>true, "disabledSupport"=>true, "dataSupport"=>true, "resolveSupport"=>{"properties"=>["edit"]}, "codeActionLiteralSupport"=>{"codeActionKind"=>{"valueSet"=>["", "quickfix", "refactor", "refactor.extract", "refactor.inline", "refactor.rewrite", "source", "source.organizeImports"]}}, "honorsChangeAnnotations"=>false}, "codeLens"=>{"dynamicRegistration"=>true}, "formatting"=>{"dynamicRegistration"=>true}, "rangeFormatting"=>{"dynamicRegistration"=>true}, "onTypeFormatting"=>{"dynamicRegistration"=>true}, "rename"=>{"dynamicRegistration"=>true, "prepareSupport"=>true, "prepareSupportDefaultBehavior"=>1, "honorsChangeAnnotations"=>true}, "documentLink"=>{"dynamicRegistration"=>true, "tooltipSupport"=>true}, "typeDefinition"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "implementation"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "colorProvider"=>{"dynamicRegistration"=>true}, "foldingRange"=>{"dynamicRegistration"=>true, "rangeLimit"=>5000, "lineFoldingOnly"=>true}, "declaration"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "selectionRange"=>{"dynamicRegistration"=>true}, "callHierarchy"=>{"dynamicRegistration"=>true}, "semanticTokens"=>{"dynamicRegistration"=>true, "tokenTypes"=>["namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator"], "tokenModifiers"=>["declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary"], "formats"=>["relative"], "requests"=>{"range"=>true, "full"=>{"delta"=>true}}, "multilineTokenSupport"=>false, "overlappingTokenSupport"=>false}, "linkedEditingRange"=>{"dynamicRegistration"=>true}}, "window"=>{"showMessage"=>{"messageActionItem"=>{"additionalPropertiesSupport"=>true}}, "showDocument"=>{"support"=>true}, "workDoneProgress"=>true}, "general"=>{"regularExpressions"=>{"engine"=>"ECMAScript", "version"=>"ES2020"}, "markdown"=>{"parser"=>"marked", "version"=>"1.1.0"}}}, "trace"=>"off", "workspaceFolders"=>[{"uri"=>"file:///Users/joelkorpela/clio/themis/test", "name"=>"test"}]}
      @host_workspace_path = params["rootPath"]

      raise("host_project_root not found") unless host_project_root

      index_name = elasticsearch_index_name(@host_workspace_path)
      project_name = find_name(host_project_root)

      @container_workspace_path = @host_workspace_path.sub(host_project_root, "#{@project_root}#{project_name}")
      @search = Search.new(@host_workspace_path, index_name)
      @persistence = Persistence.new(@host_workspace_path, @container_workspace_path, index_name)

      Server::Capabilities
    end

    def on_initialized(_hash)
      Log.debug(`/app/exe/es_check.sh`)

      queue_task(worker: @local_synchronization) do
        @persistence.index_all(preserve: true)
      end
    end

    def on_workspace_reindex(params)
      queue_task(worker: @local_synchronization) do
        Log.debug("on_workspace_reindex: #{params}")
        @persistence.index_all(preserve: false)
      end
    end

    def on_textDocument_didSave(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/test/testing.rb"}}
      queue_task(worker: @local_synchronization) do
        uri = params["textDocument"]["uri"]
        file_path = strip_protocol(uri)

        @persistence.reindex(file_path)
      end
    end

    def on_workspace_didChangeWatchedFiles(params) # {"changes"=>[{"uri"=>"file:///Users/joelkorpela/clio/themis/components/foundations/extensions/rack_session_id.rb", "type"=>3}, {"uri"=>"file:///Users/joelkorpela/clio/themis/components/foundations/app/services/foundations/lock.rb", "type"=>3}, ...
      queue_task(worker: @global_synchronization) do
        file_paths = strip_protocols(params["changes"])
        @persistence.reindex(*file_paths)
      end
    end

    def on_textDocument_didOpen(params) # "textDocument":{"uri":"file:///Users/joelkorpela/clio/themis/components/payments/spec/services/payments/stripe/provider_spec.rb","languageId":"ruby","version":1,"text":"module Payments\n  module Stripe\n    describe Provider do\n      let(:connected_account_id) { provider_account.external_id }\n      let(:provider_account) { create(:payments_stripe_account) }\n      let(:account) { provider_account.account }\n      let!(:signup) { create(:payments_stripe_signup, application_status: :success, account: account) }\n\n      subject { provider_account.provider }\n\n      describe \".#get_api_version\" do\n        subject { Payments::Stripe::Provider.get_api_version }\n\n        let(:api_version) { \"2020-08-27\" }\n\n        it \"fetches the stripe api version\" do\n          result = subject\n          expect(result).to eq(api_version)\n        end\n      end\n\n      describe \"#default_required_payment_fields\" do\n        let(:expected_default_payment_fields) { \"cvv,name,email,address1,city,state,postal_code,country\" }\n\n        it \"has the expected default required payment fields\" do\n          expect(subject.default_required_payment_fields).to eq(expected_default_payment_fields)\n        end\n      end\n\n      de...
      queue_task(worker: @buffer_synchronization) do
        uri = params["textDocument"]["uri"]
        file_path = strip_protocol(uri)
        file_content = params["textDocument"]["text"]
        file_buffer = FileBuffer.new(file_content)

        @open_files_buffer[file_path] = file_buffer
        @persistence.reindex(file_path, content: { file_path => file_content })
      end
    end

    def on_textDocument_didClose(params) # "textDocument":{"uri":"file:///Users/joelkorpela/clio/themis/components/payments/spec/services/payments/stripe/provider_spec.rb","languageId":"ruby","version":1,"text":"module Payments\n  module Stripe\n    describe Provider do\n      let(:connected_account_id) { provider_account.external_id }\n      let(:provider_account) { create(:payments_stripe_account) }\n      let(:account) { provider_account.account }\n      let!(:signup) { create(:payments_stripe_signup, application_status: :success, account: account) }\n\n      subject { provider_account.provider }\n\n      describe \".#get_api_version\" do\n        subject { Payments::Stripe::Provider.get_api_version }\n\n        let(:api_version) { \"2020-08-27\" }\n\n        it \"fetches the stripe api version\" do\n          result = subject\n          expect(result).to eq(api_version)\n        end\n      end\n\n      describe \"#default_required_payment_fields\" do\n        let(:expected_default_payment_fields) { \"cvv,name,email,address1,city,state,postal_code,country\" }\n\n        it \"has the expected default required payment fields\" do\n          expect(subject.default_required_payment_fields).to eq(expected_default_payment_fields)\n        end\n      end\n\n      de...
      queue_task(worker: @buffer_synchronization) do
        uri = params["textDocument"]["uri"]
        file_path = strip_protocol(uri)

        @open_files_buffer.delete(file_path)
      end
    end

    def on_textDocument_didChange(params) # {"textDocument":{"uri":"file:///Users/joelkorpela/clio/themis/components/payments/spec/services/payments/stripe/provider_spec.rb","version":3},"contentChanges":[{"range":{"start":{"line":8,"character":6},"end":{"line":8,"character":6}},"rangeLength":0,"text":"\n      "},{"range":{"start":{"line":8,"character":0},"end":{"line":8,"character":6}},"rangeLength":6,"text":""}]}
      queue_task(worker: @buffer_synchronization) do
        uri = params["textDocument"]["uri"]
        file_path = strip_protocol(uri)
        file_buffer = @open_files_buffer[file_path]
        changes = params["contentChanges"]

        content = file_buffer.change(changes)

        path = file_path.start_with?(@host_workspace_path) ? file_path.sub(@host_workspace_path, "") : file_path
        searchable_file_path = path.sub(@host_workspace_path, "")
        readable_file_path = "#{@container_workspace_path}#{searchable_file_path}",

        serializer = Serializer.new(
          file_path: readable_file_path,
          content: content
        )

        if serializer.valid_ast?
          @last_valid_buffer[file_path] = file_buffer.dup
          file_buffer.change!(changes)
        end

        if @buffer_synchronization.queue_length == 0
          sleep(0.33) unless changes.first["text"] == "."

          if @buffer_synchronization.queue_length == 0
            if @last_valid_buffer[file_path].text == file_buffer.text
              @persistence.reindex(file_path, content: { file_path => file_buffer.text }, inline_flush: true)
            elsif @last_valid_buffer[file_path]
              @persistence.reindex(file_path, content: { file_path => @last_valid_buffer[file_path].text }, inline_flush: true)
            else
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

      uri = params["textDocument"]["uri"]
      file_path = strip_protocol(uri)

      position = params["position"]
      position["character"] -= 1

      definitions = @search.find_definitions(file_path, params["position"])
      definition = definitions.first

      if definition && definition["_source"]["type"] == "class"
        klass = definition["_source"]["name"]
      else
        return nil
      end

      @search.find_method_definitions(klass)
    end

    def on_textDocument_definition(params) # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/test/testing.rb"}, "position"=>{"line"=>19, "character"=>16}}
      uri = params["textDocument"]["uri"]
      file_path = strip_protocol(uri)

      assignments = @search.find_definitions(file_path, params["position"])

      assignments.map do |doc|
        SymbolLocation.build(
          source: doc["_source"],
          workspace_path: @host_workspace_path
        )
      end
    end

    def on_workspace_symbol(params) # {"query"=>"abc"}
      @search.find_symbols(params["query"])
    end

    private

    def queue_task(worker:)
      worker.post do
        yield
      rescue => e
        Log.debug("Error in thread:")
        Log.debug(e)
      end
    end

    def host_project_root
      @host_project_roots
        .split(",")
        .map { |path| path.delete("\"") } # Strange, not sure why these slashes are being added
        .keep_if { |path| @host_workspace_path.match?(path) }
        .sort_by(&:length)
        .last
    end

    def find_name(dir_path)
      dir_path.match(/\/([^\/]*?)(\/$|$)/)[1] # match the last directory in the path
    end

    def elasticsearch_index_name(path)
      Digest::SHA1.hexdigest(path)
    end

    def strip_protocols(changes)
      changes.map do |change|
        strip_protocol(change["uri"])
      end
    end

    def strip_protocol(uri)
      uri[7..-1]
    end
  end
end
