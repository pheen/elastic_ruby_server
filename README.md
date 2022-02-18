# Todo

####  [Possible LSP Features](https://code.visualstudio.com/api/language-extensions/programmatic-language-features)

Supported:
- [x] [Show Definitions of a Symbol](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#show-definitions-of-a-symbol)
- [ ] [Find All References to a Symbol](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#find-all-references-to-a-symbol)
- [ ] [Highlight All Occurrences of a Symbol in a Document](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#highlight-all-occurrences-of-a-symbol-in-a-document)
- [ ] [Show all Symbol Definitions Within a Document](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#show-all-symbol-definitions-within-a-document)
- [x] [Show all Symbol Definitions in Folder](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#show-all-symbol-definitions-in-folder)
- [ ] [Format Source Code in an Editor](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#format-source-code-in-an-editor)
- [ ] [Format the Selected Lines in an Editor](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#format-the-selected-lines-in-an-editor)
- [ ] [Rename Symbols](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#rename-symbols)

Unsupported:
- [ ] [Provide Diagnostics](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#provide-diagnostics)
- [ ] [Show Code Completion Proposals](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#show-code-completion-proposals)
- [ ] [Show Hovers](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#show-hovers)
- [ ] [Help With Function and Method Signatures](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#help-with-function-and-method-signatures)
- [ ] [Possible Actions on Errors or Warnings](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#possible-actions-on-errors-or-warnings)
- [ ] [CodeLens - Show Actionable Context Information Within Source Code](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#codelens-show-actionable-context-information-within-source-code)
- [ ] [Show Color Decorators](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#show-color-decorators)
- [ ] [Incrementally Format Code as the User Types](https://code.visualstudio.com/api/language-extensions/programmatic-language-features#incrementally-format-code-as-the-user-types)

### Other
- [ ] attr_reader, etc.
- [ ] filter out let and let! definitions when outside of spec/ or test/
- [ ] filter out configurable folders from project symbol search (e.g. vendor/)
- [ ] check for branch switch, index new files and delete old ones
- [ ] maybe longer onChange debounce timer, then reindex first if go-to definition is triggered in the meantime
- [ ] handle `class_methods` block

```
class_methods do
  attr_writer :batch_size, :delay_to_batch_objects_together

  def key_from_context(context)
    context.try(:id) || context.to_s
  end
  ...

```
- [ ] profile `Persistence#index_all` and try to optimize
