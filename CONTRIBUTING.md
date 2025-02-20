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

    Set `ID_HOST`. You can decide if you want to use a local, staging, or production ID server. Set `PRX_CLIENT_ID` to a client key from whichever server you chose.

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
