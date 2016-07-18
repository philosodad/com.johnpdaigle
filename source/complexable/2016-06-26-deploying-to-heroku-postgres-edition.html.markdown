---
title: Deploying to Heroku, Postgres Edition
date: 2016-06-26 14:03 EDT
tags:
---

We've been messing around with Plug.Router/Ecto Elixir apps for a while now. We've added metrics, test coverage, deployment, and a few other things.

Today, we're going to start from scratch again, and this time we'll build an app that I actually need for work. What I want to do is store whatever json I'm sent, provided I see a couple of headers: one for the guid of the record and one for authentication. If these are given, we'll store the JSON. In addition to that, I want to be able to display the JSON back from a URL that is set to the GUID field we provided in the header. Something like `http://my.big.json.store/id/<guid>`. Pretty basic REST interface. 

The instructions assume that you have Elixir 1.2+, Erlang 18.x, and Postgres 9.4.x installed already.

So, let's get started. As usual I'll writing tests but won't be showing the tests, and I'll skip some of the boilerplate explanation that I've put into other posts, like [this one](http://www.johnpdaigle.com/complexable/2016/02/20/building-a-simple-app-with-plugrouter-and-ecto.html).

Where we'll start is with the app deployed, running on Heroku, and with a basic route alreay created to let us know that the app is up. [Here's that code in Github](https://github.com/philosodad/snapshots/tree/r01). If you want to use the existing application code to deploy to Heroku yourself, you can fork the repo, check out the r01 tag, and follow [these instructions](http://www.johnpdaigle.com/complexable/2016/06/12/deploying-a-plug-application-to-heroku.html) to create the Heroku app and [these instructions](http://www.johnpdaigle.com/complexable/2016/06/19/adding-services-and-ci-to-our-plug-app.html) to set your application up to deploy through Travis (assuming you have GitHub, Travis, and Heroku accounts).

The application we've deployed to start off doesn't do a whole lot, in fact it has exactly one endpoint that responds with a 404 to any request. It goes through a build server, than a test coverage tool, and then deploys to production, so there's a complete continuous deployment pipeline. I wouldn't use a deployment pipeline without a staging/qa server for testing if someone were giving me money, but we aren't using Travis for that right now. 

### Adding Authorization
The next thing I want to add is the post route for adding a record. We don't want just anyone adding a record, though, so we're going to want some sort of authorization scheme. Probably the best authentication scheme would be to use something like Oauth2, but since we only need one user, we're going to do something much simpler. We'll just use a single token that we match against an environment variable. Either you have the token and can post, or you don't have the token and you can't.

We'll build a simple plug to handle our authorization. The plug will look in the header, and if it sees the authorization token, it will pass the conn on, and if it doesn't, it will stop processing and return a 404. We'll put a call to our plug above the `:match` plug, and define the method at the bottom of the `lib/snapshots/server.ex` file.

    :::elixir
    plug :authorize
    ...
    defp authorize conn, opts do
      token = Sets.auth_token
      Plug.Conn.get_req_header(conn, "authorization")
      |> Enum.member?(token)
      |> case do
        true -> conn
        _ -> send_resp(conn, 404, "No resource found")
             |> halt
      end
    end

What I would expect if I deployed this would be for the system to refuse connections without the right token in the header. To test it out before I deploy it (beyond the test I've written for it), we'll run the server locally, setting the `AUTH_TOKEN` environment variable, then run a couple of web requests against the local server.

    :::bash
    AUTH_TOKEN=abcdedf mix run --nohalt

Let me repeat, this is not good security. It's barely security, and at some future point we should really look at using a real authorization/authentication library, but this will do for now.

This might be a good time to test deployment, because we're adding a heroku configuration: the `AUTH_TOKEN` environment variable, which on Heroku can be defined in the application dashboard under `Settings`. [This code](https://github.com/philosodad/snapshots/tree/r02) deploys and runs through my pipeline.

Before we move on it's a good idea to open up the [r02](https://github.com/philosodad/snapshots/tree/r02) repo and get a little familiar with the current project structure, because in the next section we're going to change a lot of files and you should have an idea of where everything is.

### Adding Ecto
Next, we'll add ecto and set up postgres. This is going to be slightly more complex than it was the [last time we set up postgres](http://www.johnpdaigle.com/complexable/2016/02/20/building-a-simple-app-with-plugrouter-and-ecto.html) because now we want to use the `map` option in order to store json directly to the database. The basics are the same, however, we'll add the dependency, configure the dependency, start up the app to connect to the database, and add a schema and a migration.

The first change is to add the dependency to `mix.exs`:

    :::elixir
    defp deps do
      [
        {:env_helper, "~> 0.0.3"},
        {:httpoison, "~> 0.9.0"},
        {:cowboy, "~> 1.0.0"},
        {:plug, "~> 1.0"},
        {:postgrex, "~> 0.11.2"}, #new
        {:ecto, "~> 2.0"}, #new
        {:poison, "~> 2.2"}, #new
        {:excoveralls, "~> 0.4", only: :test}
      ]
    end

`postgrex` connects `ecto` to Postgres, and `poison` is the default JSON library for `ecto`. Having added the dependency, we can add the configuration in either `config/`. In this case, I added two different configurations to start, on in `config/dev.exs`:

    :::elixir
    config :snapshots, Snapshots.Repo,
      adapter: Ecto.Adapters.Postgres,
      database: "snapshots_dev",
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      extensions: [{Postgrex.Extensions.JSON, 
                    library: Poison}] 

and one in `config/test.exs`:

    :::elixir
    config :snapshots, Snapshots.Repo,
      adapter: Ecto.Adapters.Postgres,
      database: "snapshots_test",
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      extensions: [{Postgrex.Extensions.JSON,
                    library: Poison}] 

Of course, we also need to define `Snapshots.Repo`, which we'll do in a file called `lib/snapshots/repo.ex`:

    :::elixir
    defmodule Snapshots.Repo do
      use Ecto.Repo, otp_app: :snapshots 
    end

And we need to add the repo to the list of ecto repos in `config/config.exs`:

    :::elixir
    config :snapshots, 
            ecto_repos: [Snapshots.Repo]

This should get us to the point where we can run `mix deps.get` and `mix ecto.migrate` and have a database created. If we have a database createde, than we can start the connector in the `lib/snapshots.ex` file:

    :::elixir
    def start( _type, _args ) do
      import Supervisor.Spec, warn: false
      children = [
        worker(Snapshots.Server, []), 
        worker(Snapshots.Repo, [] ), #new line
      ]
      opts = [strategy: :one_for_one, 
                  name: Snapshots.Supervisor]
      Supervisor.start_link(children, opts)
    end

At this point, if we try to run `mix test` without first running `MIX_ENV=test mix ecto.migrate`, we'll get this error: **(DBConnection.ConnectionError) connection not available because of disconnection** because the application can't start up without the database being created. The solution to that is to add a line to the `mix.exs` file:

    :::elixir
    def project do
      [app: :snapshots,
       version: "0.0.1",
       elixir: "~> 1.2",
       build_embedded: Mix.env == :prod,
       start_permanent: Mix.env == :prod,
       test_coverage: [tool: ExCoveralls],
       preferred_cli_env: ["coveralls": :test, 
                           "coveralls.detail": :test, 
                           "coveralls.post": :test],
       deps: deps,
       #here's the new line:
       aliases: ["test": ["ecto.create --quiet", 
                          "ecto.migrate", 
                          "test"]]
     ]

That will ensure that the database is created.

If we want to do anything with the database, we'll need a migration and maybe a Schema to take advantage of that. We'll create a new file `lib/snapshots/snapshot.ex` 

    :::elixir
    defmodule Snapshots.Snapshot do
      use Ecto.Schema
      
      schema "snapshots" do
        field :guid, :string
        field :ref_guid, :string
        field :message, :map
      end
    end

Then using `mix ecto.gen.migration` to create a file in `priv/repo/migrations`, which we edit like so:

    :::elixir
    defmodule Snapshots.Repo.Migrations.AddSnapshots do
      use Ecto.Migration

      def change do
        create table(:snapshots) do
          add :guid, :string
          add :ref_guid, :string
          add :message, :map
        end
      end
    end

And there's the snapshot record we wanted to be able to create. The `:map` type converts to jsonb in Postgres, so we can store and retrieve Map datastructures in the database.

Before we do anything else I'd really like to make sure that this deploys through our CI pipeline. The easiest way to test that is to just try to deploy right now, so I'll deploy [r03]() and see what happens.

What happens is that it fails on travis with this error **ERROR (undefined_object): type "jsonb" does not exist**. As it turns out, the default version of postgres that Travis is using is postgres 9.1, which doesn't have the JSON datatype. We need to specify the correct version in the `.travis.yml`:

    :::yaml
    addons: 
      postgresql: 9.4

With that addition, the application passes the travis build, but it fails to deploy to Heroku. The Heroku logs, in this case, don't yield much, but after trying to run the application locally we get an error indicating that the Postgres adapter hasn't been set up in production. In order to do that we're going to want to get some information from Heroku on running Postgres there. Following the instructions there we add the postgres service to our app:

    :::bash
    heroku addons:create heroku-postgresql:hobby-dev

And add a `config/prod.exs` file:

    :::elixir
    use Mix.Config
    config :snapshots, Snapshots.Repo,
      adapter: Ecto.Adapters.Postgres,
      url: System.get_env("DATABASE_URL"),
      extensions: [{Postgrex.Extensions.JSON,
                    library: Poison}]

And our [next checkpoint version, r04](https://github.com/philosodad/snapshots/tree/r04) gets through the CI server and deploys to Heroku.

The next part, building the views and posting the data, looks to be fairly involved so I'll leave it for another week.
