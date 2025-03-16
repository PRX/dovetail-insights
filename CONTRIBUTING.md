# Contributing

### Table of Contents

-   [Recommended Tooling for Development Environment](#recommended-tooling)
-   [Development Environment Setup](#environment-setup)

## Development Environment

These steps assume you have followed PRX's [Local Development Environment guide](https://github.com/PRX/internal/wiki/Guide:-Local-Development-Environment), which will install a number of dependencies. You can fulfill those dependencies however you'd like, but you may need alter the procedures in this document to match your environment.

### Environment Setup

1.  Clone the project repository:

    ```shell
    git clone https://github.com/PRX/dovetail-insights.git
    cd dovetail-insights
    ```

1.  Install Ruby and other runtimes:

    ```shell
    asdf install
    ```

1.  Configure a dedicated local hostname in puma-dev:

    ```shell
    echo 4203 > ~/.puma-dev/insights.dovetail.prx
    ```

    You will access the local development server at [http://insights.dovetail.prx.test](http://insights.dovetail.prx.test/) or [https://insights.dovetail.prx.test](https://insights.dovetail.prx.test/).

1.  Configure BigQuery credentials

    Create a file called `config/bigquery-keyfile.json`, and add JSON client credentials for Google Cloud that have access to the BigQuery database you want to use. If you're not sure which credentials to use or where to get them, please ask around.

1.  Configure local environment variables.

    Make a copy of the example file.

    ```shell
    cp env-example .env
    ```

    Set `BIGQUERY_PROJECT` to the Google Cloud project name that contains the BigQuery database you want to use. Set `BIGQUERY_CREDENTIALS` to the _path_ of a file that contains BigQuery API credentials from above. (i.e., `./config/bigquery-keyfile.json`)

    Set `ID_HOST`. You can decide if you want to use a local, staging, or production [ID server](https://github.com/prx/id.prx.org). Set `PRX_ID_CLIENT_APP_KEY` to a client key from whichever server you chose.

1.  Install Ruby gems.

    ```shell
    bundle install
    ```

1.  Install npm packages.

    ```shell
    yarn install
    ```

### Running the Application

Once your environment has been setup, you should be able to start the Rails server and load the site in a browser:

```shell
bin/rails s
```

The site will be available at [insights.dovetail.prx.test](http://insights.dovetail.prx.test/).

### Recommended Tooling

Integrating your IDE with the various tools that this project uses to maintain code quality and styles can lead to faster development, by catching issues during development rather than when they reach CI.

One way to do development work on Insights with comprehensive realtime coverage of these tools is to use [VS Code](https://code.visualstudio.com) with the following features and extensions:

1. The [Ruby LSP](https://shopify.github.io/ruby-lsp/) [extension](https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp) supports linting and formatting of Ruby code using the project's [`Rubocop`](https://ruboCop.org) configuration (which is the highly opinionated set of rules provided by [`standard`](https://github.com/standardrb/standard) and [`standard-rails`](https://github.com/standardrb/standard-rails)).

    Ensure that you have `diagnostics` and `formatting` enabled under `rubyLsp.enabledFeatures` settings. The project's VS Code settings are configured to format-on-save.
1. The [ERB Linter extension](https://marketplace.visualstudio.com/items?itemName=manuelpuyol.erb-linter) integrates with [erb_lint](https://github.com/Shopify/erb_lint), which is a linter for ERB files. The project's `erb_lint` configuration also uses the rules provided by `standard` and `standard-rails`, with some exceptions based on the nature of ERB files.

    The project's VS Code settings are configured to format-on-save ERB files. Note that this formats both Ruby code embedded in the ERB file, as well as some basic aspects of the the host language code (like HTML).
1. The [ESLint extension](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint) integrates with [ESLint](https://eslint.org) to provide linting and static analysis of JavaScript code. The project is also configured to check JavaScript code style with `ESLint` via [`Prettier`](https://prettier.io), thus the extension will surface style issues as well.
1. While `ESLint` is used to _check_ for `Prettier` style violations in JavaScript, neither `ESLint` nor the ESLint extension will automatically format code. The [Prettier extension](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode) provides a formatter for VS Code, which is configured to format-on-save.

    `Prettier` is also used to check style for CSS, JSON, and YAML files, so the project is configured to format-on-save for those file types as well using the extension.
1. [TypeScript](https://www.typescriptlang.org) support is built into VS Code, and while there is no TypeScript code in Insights directly, the TypeScript compiler is used to check the project's JavaScript code.

Code is checked as part of the project's CI process. To run these checks locally using the tools like `RuboCop` and `ESLint` directly, you can use `bin/rails lint`, which avoids any potential configuration issues or conflicts that may prevent the IDE from fully checking the codebase.
