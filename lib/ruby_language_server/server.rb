# frozen_string_literal: true

require 'json'

# Deal with the various languageserver calls.
module RubyLanguageServer
  class Server
    Capabilities = {
      capabilities: {
        textDocumentSync: 1,
        hoverProvider: true,
        signatureHelpProvider: {
          triggerCharacters: ['(', ',']
        },
        definitionProvider: true,
        referencesProvider: true,
        documentSymbolProvider: false,
        workspaceSymbolProvider: false,
        xworkspaceReferencesProvider: true,
        xdefinitionProvider: true,
        xdependenciesProvider: true,
        completionProvider: {
          resolveProvider: true,
          triggerCharacters: ['.', '::']
        },
        codeActionProvider: true,
        renameProvider: true,
        executeCommandProvider: {
          commands: []
        },
        xpackagesProvider: true
      }
    }.freeze

    def initialize(mutex, index_name: :ruby_parser_index)
      @mutex = mutex
      @index_name = index_name
    end

    attr_accessor :io

    # params: {"processId"=>54359, "clientInfo"=>{"name"=>"Visual Studio Code", "version"=>"1.56.2"}, "locale"=>"en-us", "rootPath"=>"/Users/joelkorpela/clio/themis/test", "rootUri"=>"file:///Users/joelkorpela/clio/themis/test", "capabilities"=>{"workspace"=>{"applyEdit"=>true, "workspaceEdit"=>{"documentChanges"=>true, "resourceOperations"=>["create", "rename", "delete"], "failureHandling"=>"textOnlyTransactional", "normalizesLineEndings"=>true, "changeAnnotationSupport"=>{"groupsOnLabel"=>true}}, "didChangeConfiguration"=>{"dynamicRegistration"=>true}, "didChangeWatchedFiles"=>{"dynamicRegistration"=>true}, "symbol"=>{"dynamicRegistration"=>true, "symbolKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]}, "tagSupport"=>{"valueSet"=>[1]}}, "codeLens"=>{"refreshSupport"=>true}, "executeCommand"=>{"dynamicRegistration"=>true}, "configuration"=>true, "workspaceFolders"=>true, "semanticTokens"=>{"refreshSupport"=>true}, "fileOperations"=>{"dynamicRegistration"=>true, "didCreate"=>true, "didRename"=>true, "didDelete"=>true, "willCreate"=>true, "willRename"=>true, "willDelete"=>true}}, "textDocument"=>{"publishDiagnostics"=>{"relatedInformation"=>true, "versionSupport"=>false, "tagSupport"=>{"valueSet"=>[1, 2]}, "codeDescriptionSupport"=>true, "dataSupport"=>true}, "synchronization"=>{"dynamicRegistration"=>true, "willSave"=>true, "willSaveWaitUntil"=>true, "didSave"=>true}, "completion"=>{"dynamicRegistration"=>true, "contextSupport"=>true, "completionItem"=>{"snippetSupport"=>true, "commitCharactersSupport"=>true, "documentationFormat"=>["markdown", "plaintext"], "deprecatedSupport"=>true, "preselectSupport"=>true, "tagSupport"=>{"valueSet"=>[1]}, "insertReplaceSupport"=>true, "resolveSupport"=>{"properties"=>["documentation", "detail", "additionalTextEdits"]}, "insertTextModeSupport"=>{"valueSet"=>[1, 2]}}, "completionItemKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]}}, "hover"=>{"dynamicRegistration"=>true, "contentFormat"=>["markdown", "plaintext"]}, "signatureHelp"=>{"dynamicRegistration"=>true, "signatureInformation"=>{"documentationFormat"=>["markdown", "plaintext"], "parameterInformation"=>{"labelOffsetSupport"=>true}, "activeParameterSupport"=>true}, "contextSupport"=>true}, "definition"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "references"=>{"dynamicRegistration"=>true}, "documentHighlight"=>{"dynamicRegistration"=>true}, "documentSymbol"=>{"dynamicRegistration"=>true, "symbolKind"=>{"valueSet"=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]}, "hierarchicalDocumentSymbolSupport"=>true, "tagSupport"=>{"valueSet"=>[1]}, "labelSupport"=>true}, "codeAction"=>{"dynamicRegistration"=>true, "isPreferredSupport"=>true, "disabledSupport"=>true, "dataSupport"=>true, "resolveSupport"=>{"properties"=>["edit"]}, "codeActionLiteralSupport"=>{"codeActionKind"=>{"valueSet"=>["", "quickfix", "refactor", "refactor.extract", "refactor.inline", "refactor.rewrite", "source", "source.organizeImports"]}}, "honorsChangeAnnotations"=>false}, "codeLens"=>{"dynamicRegistration"=>true}, "formatting"=>{"dynamicRegistration"=>true}, "rangeFormatting"=>{"dynamicRegistration"=>true}, "onTypeFormatting"=>{"dynamicRegistration"=>true}, "rename"=>{"dynamicRegistration"=>true, "prepareSupport"=>true, "prepareSupportDefaultBehavior"=>1, "honorsChangeAnnotations"=>true}, "documentLink"=>{"dynamicRegistration"=>true, "tooltipSupport"=>true}, "typeDefinition"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "implementation"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "colorProvider"=>{"dynamicRegistration"=>true}, "foldingRange"=>{"dynamicRegistration"=>true, "rangeLimit"=>5000, "lineFoldingOnly"=>true}, "declaration"=>{"dynamicRegistration"=>true, "linkSupport"=>true}, "selectionRange"=>{"dynamicRegistration"=>true}, "callHierarchy"=>{"dynamicRegistration"=>true}, "semanticTokens"=>{"dynamicRegistration"=>true, "tokenTypes"=>["namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator"], "tokenModifiers"=>["declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary"], "formats"=>["relative"], "requests"=>{"range"=>true, "full"=>{"delta"=>true}}, "multilineTokenSupport"=>false, "overlappingTokenSupport"=>false}, "linkedEditingRange"=>{"dynamicRegistration"=>true}}, "window"=>{"showMessage"=>{"messageActionItem"=>{"additionalPropertiesSupport"=>true}}, "showDocument"=>{"support"=>true}, "workDoneProgress"=>true}, "general"=>{"regularExpressions"=>{"engine"=>"ECMAScript", "version"=>"ES2020"}, "markdown"=>{"parser"=>"marked", "version"=>"1.1.0"}}}, "trace"=>"off", "workspaceFolders"=>[{"uri"=>"file:///Users/joelkorpela/clio/themis/test", "name"=>"test"}]}
    def on_initialize(params)
      RubyLanguageServer.logger.info("on_initialize: #{params}")

      @root_path = params['rootPath']
      @root_uri = params['rootUri']
      @ruby_parser = RubyParser.new(@root_path, index_name: @index_name)

      Capabilities
    end

    def on_initialized(_hash)
      RubyLanguageServer.logger.info("RubyLanguageServer::VERSION #{RubyLanguageServer::VERSION}")

      RubyLanguageServer.logger.info(`/app/exe/es_check.sh`)

      # @ruby_parser.index_all
    end

    # {"textDocument"=>{"uri"=>"file:///Users/joelkorpela/clio/themis/test/testing.rb"}, "position"=>{"line"=>19, "character"=>16}}
    def on_textDocument_definition(params)
      RubyLanguageServer.logger.debug("on_textDocument_definition #{params}")

      definitions = @ruby_parser.find_possible_definitions(params["textDocument"]["uri"], params["position"])

      RubyLanguageServer.logger.debug("My definitions:")
      RubyLanguageServer.logger.debug(definitions)

      definitions

      # uri = uri_from_params(params)
      # position = postition_from_params(params)
      # other_definitions = @project_manager.possible_definitions(uri, position)

      # RubyLanguageServer.logger.debug("Other definitions:")
      # RubyLanguageServer.logger.debug(other_definitions)

      # other_definitions
    end

    def on_workspace_didChangeWatchedFiles(params)
      RubyLanguageServer.logger.debug('on_workspace_didChangeWatchedFiles')
      RubyLanguageServer.logger.debug(params)
      {}
    end

    def on_textDocument_hover(params)
      RubyLanguageServer.logger.debug('on_textDocument_hover')
      RubyLanguageServer.logger.debug(params)
      {}
    end

    def on_textDocument_documentSymbol(params)
      RubyLanguageServer.logger.debug('on_textDocument_documentSymbol')
      RubyLanguageServer.logger.debug(params)
      uri = uri_from_params(params)

      # {"kind":"module","line":4,"language":"Ruby","path":"(eval)","pattern":"module RubyLanguageServer","full_name":"RubyLanguageServer","name":"RubyLanguageServer"}
      # symbols = @project_manager.tags_for_uri(uri)
      # RubyLanguageServer.logger.debug("symbols #{symbols}")
      # symbols
    end

    def send_diagnostics(uri, text)
      # hash = @project_manager.update_document_content(uri, text)
      # io.send_notification('textDocument/publishDiagnostics', uri: uri, diagnostics: hash)
      io.send_notification('textDocument/publishDiagnostics', uri: uri, diagnostics: {})
    end

    def on_textDocument_didOpen(params)
      textDocument = params['textDocument']
      uri = textDocument['uri']
      RubyLanguageServer.logger.debug("on_textDocument_didOpen #{uri}")
      text = textDocument['text']
      send_diagnostics(uri, text)
    end

    def on_textDocument_didChange(params)
      uri = uri_from_params(params)
      RubyLanguageServer.logger.debug("on_textDocument_didChange #{uri}")
      content_changes = params['contentChanges']
      text = content_changes.first['text']
      send_diagnostics(uri, text)
    end

    def on_textDocument_completion(params)
      RubyLanguageServer.logger.info("on_textDocument_completion #{params}")
      uri = uri_from_params(params)
      position = postition_from_params(params)
      completions = @project_manager.completion_at(uri, position)
      RubyLanguageServer.logger.debug("completions: #{completions}")
      completions
    end

    def on_shutdown(_params)
      RubyLanguageServer.logger.info('on_shutdown')
    end

    private

    def uri_from_params(params)
      textDocument = params['textDocument']
      textDocument['uri']
    end

    Position = Struct.new('Position', :line, :character)

    def postition_from_params(params)
      position = params['position']
      Position.new((position['line']).to_i, position['character'].to_i)
    end
  end
end
