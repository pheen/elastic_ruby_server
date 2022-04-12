# Elastic Ruby Server

A Ruby language server with persistent storage backed by Elasticsearch. The goal of this language server is to provide reasonably accurate static analysis while staying performant for large projects.
&nbsp;

| Features  |  |
| ------------- | ------------- |
| [Definitions](#definitions) | Jump to definitions for methods, variables, etc. |
| [Definition Search](#definition-search)  | Search definitions in all files |
| [Diagnostics](#diagnostics) | Indicates issues generated with Rubocop |
| [Formatting](#formatting) | Supports formatting only modified lines |
| [Highlights](#highlights) | Highlight all occurrences in a document |
| [References](#references) | Show where a method/variable/symbol is being used |
| [Rename](#rename) | Update all references to a method/variable/symbol |

&nbsp;
<a id="definitions"></a>
## Definitions
Peek or go to the definition of a method/variable/symbol

- Command: `Go to Definition`
- Keybinds:
  - `f12`
  - `cmd + click`

&nbsp;
- Supported framework definitions:
  - Rails:
    - belongs_to
    - has_one
    - has_many
    - has_and_belongs_to_many
  - RSpec:
    - let!
    - let

![goto-definition](https://code.visualstudio.com/assets/api/language-extensions/language-support/goto-definition.gif)

&nbsp;
<a id="definition-search"></a>
## Definition Search
Quickly navigate to definitions anywhere in a project.

- Command: `Go to Symbol in Workspace...`
- Keybind: `cmd + t`

![workspace-symbols](https://code.visualstudio.com/assets/api/language-extensions/language-support/workspace-symbols.gif)

&nbsp;
<a id="diagnostics"></a>
## Diagnostics
Enable and configure Rubocop to highlight issues by adding .rubocop.yml to the root of a project.

&nbsp;
<a id="formatting"></a>
## Formatting
Formats modified lines using a light Rubocop configuration. Duplicate changes are ignored so formatting will not be applied when undoing the automatic formatting then re-saving.

- Trigger: on save
- Command: `Format Selection`
- Keybind: `cmd+k cmd+f`

![format-document](https://code.visualstudio.com/assets/api/language-extensions/language-support/format-document.gif)

&nbsp;
<a id="highlights"></a>
## Highlights
See all occurrences of a method/variable/symbol in the current editor.

![document-highlights](https://code.visualstudio.com/assets/api/language-extensions/language-support/document-highlights.gif)

&nbsp;
<a id="references"></a>
## References
See all the locations where a method/variable/symbol is being used. Only locations in the the file being edited are shown currently.

- Command: `Go to References`
- Keybind: `shift + f12`

![find-references](https://code.visualstudio.com/assets/api/language-extensions/language-support/find-references.gif)

&nbsp;
<a id="rename"></a>
## Rename
Change the name of a method/variable/symbol.

- Command: `Rename Symbol`
- Keybind: `f2`

![rename](https://code.visualstudio.com/assets/api/language-extensions/language-support/rename.gif)

&nbsp;
# Installation
**1.** Install the `Elastic Ruby Language Server` extension and Docker if needed.

**2.** Configure `elasticRubyServer.projectPaths`. **Important:** A project must be a sub-directory of one of these paths to be readable by the langue server.
- Configure in VSCode's JSON settings (`cmd + shift + p` and search for `Preferences: Open Settings (JSON)`).
- Don't use your home directory as a project path or docker will use a large amount of CPU %.
```
"elasticRubyServer.projectPaths": [
	"/Users/<name>/projects",
	"/Users/<name>/a_folder/more_projects"
]
```

**3.** Install dependencies needed for the extension to interact with docker:
```bash
> cd ~/.vscode/extensions/blinknlights.elastic-ruby-client-0.5.1/
> npm install
```

**5.** Reload VSCode

**6.** Navigate to any `.rb` file to activate the extension. The extension will automatically download the language server's docker image and start indexing a workspace. Indexing may take a few minutes for large projects.

&nbsp;
## Configuration
- `elasticRubyServer.port`. The default is `8341`.

&nbsp;
## Custom Commands
Run commands with `cmd + shift + p`.
- `Reindex Workspace` deletes all current data for the project and starts reindexing all files.
- `Stop Server` to shutdown the Docker container.

&nbsp;
# How does it work?
The server runs inside a docker container and has its own instance of Elasticsearch. Clients connect through TCP allowing multiple clients to connect to a single instance of the server.

Ruby files are converted to an AST with [Parser](https://github.com/whitequark/parser) which is serialized by the language server and indexed into Elasticsearch. Data is persisted in a named Docker volume.

Definitions are searched by storing a `scope` which is built for a given location using rules mimicking Ruby's variable scope. When searching with `Go To` the correct definitions are chosen largely based on this scope. Multiple definitions will be shown if more than one match the search criteria.

&nbsp;
## Troubleshooting
- Check that the container is running. The image name is `blinknlights/elastic_ruby_server` which is ran with the name `elastic-ruby-server`. You could check with `docker ps` or in the Docker app:

  ![Screen Shot 2021-07-01 at 8 41 06 PM](https://user-images.githubusercontent.com/1145873/124217196-bc1a4380-daac-11eb-9f9a-e05bca82d5f6.png)

&nbsp;
# todo:
Got this after doing the npm install for your extension:
found 2 moderate severity vulnerabilities
  run `npm audit fix` to fix them, or `npm audit` for details

&nbsp;
## License
[MIT](https://choosealicense.com/licenses/mit/)
