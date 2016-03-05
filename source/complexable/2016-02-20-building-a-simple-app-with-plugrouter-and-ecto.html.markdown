---
title: Building a Simple App with Plug.Router and Ecto
date: 2016-02-20 09:37 EST
tags:
---

I've been working with a couple of Elixir technologies lately, Plug.Router and Ecto, and I'm pretty pleased with how easy it is to get them working together. Here's an example -- let's say I want to write a logger. The logger takes in whatever message hits its log endpoint and writes it to a database. We'll write a proof of concept logger in this post, [you can find the code on GitHub](https://github.com/philosodad/loggex). Occasionally you'll see a cryptic note like this [[s0]](https://github.com/philosodad/loggex), that is an indication that the code up to that point is available under the indicated tag. 

If you want to follow along with this exercise, you're going to need to have elixir and postgresql installed on your computer, or if you are a user of vagrant, you can try a prebuilt box for phoenix development like [this one](https://github.com/kiere/vagrant-phoenix-postgres). I haven't tried that box, but it's worth a shot.

We're going to use the logger to record the time the original message was received, the response code for the message, and the body of the message. So my endpoint is going to expect a block of JSON that looks something like this:

    :::json
    { 
      sender: "something.com" 
      time: <datetime>, 
      responseCode: 300, 
      body: "\{\"foo\": \"bar\"\}"
    }

And we're going to put that into a postgres database in a table that's called "messages".

So, we'll need to start a new elixir project:

    :::bash
    $ mix new loggex
    $ cd loggex

And add some dependencies to the `mix.exs` file. We'll need to add cowboy, plug, ecto, and postgrex:

    :::elixir
    def application do
      [applications: 
        [:logger,
         :cowboy,
         :plug,
         :postgrex,
         :ecto]
      ]
    end 
    defp deps do
      [
        {:httpoison, "~> 0.8.0"},
        {:cowboy, "~> 1.0.0"},
        {:plug, "~> 1.0"},
        {:exjsx, "~> 3.2"},
        {:postgrex, ">= 0.0.0"},
        {:ecto, "~> 1.1.2"}
      ]
    end

[[s1]](https://github.com/philosodad/loggex/tree/s1)[Plug](https://github.com/elixir-lang/plug) is the middleware framework that contains Plug.Router, [Cowboy](https://github.com/ninenines/cowboy) is a web server from Erlang, [Ecto](https://github.com/elixir-lang/ecto) is the database wrapper and [Postgrex](https://github.com/ericmj/postgrex) is the adapter between Ecto and Postgres. We could use a different database, there are several adapters available, but Postgres is sort of the defacto standard so we'll stick with it. Of course, once you have those dependencies noted you'll want to run `mix deps.get` to install them all.

Now that we're set up, we'll first add a route, then add the database migration, then wire it together to save the incoming message to the database. A quick side note, I'll be driving this with tests on my side but not including them in the post. The tests are in the GitHub repo, though.

Adding a route looks pretty simple, if you're familiar with Sinatra this probably looks familiar to you:

    :::elixir
    defmodule Loggex do
      use Plug.Router
      plug :match
      plug :dispatch

      post "/log" do
        send_resp(conn, 200, "No Response")
      end
    end

To start the router, use `iex -S mix` to start an iex session, and in iex:

    :::iex
    > Plug.Adapters.Cowboy.http Loggex, [], port: 6438

The port option is optional, it defaults to 4000. I have about six servers running on my laptop right now, so I'm getting creative with port numbers. In a later post we might look at how to make these values configurable, as well as how to start the server from the command line rather than from iex.

At this point, if you send an http request to `localhost:6438/log`, you should receive a 200 response back[[s2]](https://github.com/philosodad/loggex/tree/s2).

Next, we want to set up the database with ecto. Ecto has its own mix tasks, which makes this somewhat easier.

    :::bash
    $ mix ecto.gen.repo

This will generate a new file in `lib/loggex/` called `repo.ex`. You don't have to do anything to the repo file, but there are also changes to be made to your `config.exs` file. That file will now have some new material in it:

    :::elixir
    use Mix.Config
    config :loggex, Loggex.Repo,
      adapter: Ecto.Adapters.Postgres,
      database: "loggex_repo",
      username: "user", #CHANGE THIS LINE
      password: "pass", #CHANGE THIS LINE
      hostname: "localhost"

The `username` and `password` entries will need to be changed to a user on your installation of postgres. Once we have a repository, we can create the repository and generate a migration.

    :::bash
    $ mix ecto.create
    $ mix ecto.gen.migration add_loglines_table

This produces a basic migration file in `priv/repo/migrations/` which we'll edit to match the JSON schema we started with:

    :::elixir
    defmodule Loggex.Repo.Migrations.AddLoglinesTable do
      use Ecto.Migration
      def change do
        create table(:loglines) do
          add :sender, :string
          add :sendtime, :datetime
          add :responseCode, :integer
          add :body, :string
        end
      end
    end            

The `change` function is automatically reversible. Now, in order to be able to work effeciently with our new database and table, we'll want to add a schema at `lib/loggex/logline.ex`.

    :::elixir
    defmodule Loggex.Logline do
      use Ecto.Schema
      import Ecto.Changeset
                                                                                                                                                                                      
      schema "loglines" do
        field :sender, :string
        field :sendtime, Ecto.DateTime
        field :responseCode, :integer
        field :body, :string
      end
    end                

At this point, using iex, you should be able to start the repo with `Loggex.Repo.start_link` and insert a changeset into the repo. I put a lot of trial and error in, so here's an example iex session. Some of the longer lines have been moved to multiple lines, so you'll want to fix the query, it may not run if just pasted in.

    :::iex
    ex(1)> {:ok, repo} = Loggex.Repo.start_link
    {:ok, #PID<0.214.0>}
    iex(2)> change = %Loggex.Logline{sender: "sender",
                          sendtime: Ecto.DateTime.utc,
                          responseCode: 344,
                          body: "body goes here"}
    %Loggex.Logline{__meta__: #Ecto.Schema.Metadata<:built>
    iex(3)> import Ecto.Query
    nil
    iex(4)> Loggex.Repo.insert change

    16:16:38.577 [debug] INSERT INTO "loglines" ("body", "re
    {:ok,
     %Loggex.Logline{__meta__: #Ecto.Schema.Metadata<:loaded
      body: "body goes here", id: 3, responseCode: 344, send
      sendtime: #Ecto.DateTime<2016-02-21T21:15:54Z>}}
    iex(5)> query = from l in Loggex.Logline, 
                     where: l.responseCode == 344, 
                     select: l
    #Ecto.Query<from l in Loggex.Logline, where: l.responseC
    iex(6)> Loggex.Repo.one query

    16:17:45.614 [debug] SELECT l0."id", l0."sender", l0."se
    %Loggex.Logline{__meta__: #Ecto.Schema.Metadata<:loaded>
     body: "body goes here", id: 3, responseCode: 344, sende
     sendtime: #Ecto.DateTime<2016-02-21T21:15:54Z>}
    iex(7)> log = Loggex.Repo.one query

    16:18:00.319 [debug] SELECT l0."id", l0."sender", l0."se
    %Loggex.Logline{__meta__: #Ecto.Schema.Metadata<:loaded>
     body: "body goes here", id: 3, responseCode: 344, sende
     sendtime: #Ecto.DateTime<2016-02-21T21:15:54Z>}
    iex(8)> log.responseCode
    344

All the parts are here at this point[[s3]](https://github.com/philosodad/loggex/tree/s3), we just need to make them work together. Now, I'm fairly sure that there are better ways to do this than the way I've settled on. In particular, I'm doing some pretty gunky stuff to convert the input into a `%Loggex.Logline struct`. But here goes.

My first problem is that I've got a requirement to send in an Ecto.DateTime object, but I'll probably be receiving an iso datetime string. We'll take advantage of plug to handle this (again, this is just an example, this probably should go in the Schema).

    :::elixir
    defmodule Loggex do
      use Plug.Router
      use Plug.Builder

      plug Plug.Parsers, parsers: [:json, :urlencoded],
                         json_decoder: JSX
      plug :timefixer
      plug :match
      plug :dispatch

      def start do
        Plug.Adapters.Cowboy.http Loggex, [], port: 6438
        Loggex.Repo.start_link
      end

      def stop do
        Plug.Adapters.Cowboy.shutdown Loggex.HTTP
      end

      post "/log" do
        Map.keys(conn.params)
        |> Enum.reduce(%{}, fn(k,acc) -> 
           Map.put(acc, String.to_atom(k), conn.params[k]) 
           end)
        |> (&(Map.merge(%Loggex.Logline{}, &1))).()
        |> Loggex.Repo.insert
        send_resp(conn, 200, "No Response")
      end

      def timefixer conn, opts do
        conn = conn.params["sendtime"]
        |> Ecto.DateTime.cast!
        |> (&(Map.put(conn.params, "sendtime", &1))).()
        |> (&(Map.put(conn, :params, &1))).()
        conn
      end

    end

Let's walk through the plug pipeline one step at a time. The first plug is the JSON parser. It takes in a conn struct, reads the input body, and returns a new conn with a `params` key, the value of which is a map built from the input JSON.

We added `Plug.Builder` and a new plug, `:timefixer`, which we define as a function in the module. Time fixer takes the conn struct that the JSON parser returns and typecasts the `"sendtime"` value of the `conn.params` into an `Ecto.DateTime` struct, which is what the schema expects. The new conn is passed on to the `:match` plug.

The `:match` plug matches the incoming request to the `post "/log"` function, where we convert the params that came in into a `%Loggex.Logline{}` struct, so that we can insert that into the database. Again, we make pretty heavy use of the pipeline operator here. After inserting the new logline into the database, we return three values, the conn, a response code, and a message. These are passed to the `:dispatch` plug, which returns a 200 to the user. 

At this point we have a functional logger[[s4]](https://github.com/philosodad/loggex/tree/s4). It isn't as pretty as it could be, and it definitely needs a little cleanup and some error handling, but provided it gets exactly the right inputs, it will save a logline into the postgres database.

Next entry I'll look at how to improve this project by adding configuration, CI, and test coverage metrics. And of course you can find the code on GitHub, [https://github.com/philosodad/loggex](https://github.com/philosodad/loggex).


