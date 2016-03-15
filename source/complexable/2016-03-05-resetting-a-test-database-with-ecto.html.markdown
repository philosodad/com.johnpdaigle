---
title: Resetting a test database with Ecto
date: 2016-03-05 15:50 EST
tags:
---

This post references [the last post](http://www.johnpdaigle.com/complexable/2016/02/20/building-a-simple-app-with-plugrouter-and-ecto.html).

In this post, we're going to cover a very small amount of ground on the loggex project that I started a couple of weeks ago, mainly, cleaning up the code base a touch and adding configuration.

In the current implementation[[s4](https://github.com/philosodad/loggex/tree/s4)], we added a plug to the pipeline called `timefixer` that converted one of the JSON input variables into an `Ecto.DateTime` struct. It works, but of course it's going to cause problems if we want to define any other endpoints, for example, an endpoint that doesn't receive a `sendtime` parameter is probably going to fail.

Also, this is logic around the schema itself, so it probably belongs in the schema. So our first task is going to be to remove that plug and move the logic into the schema. As before, I'm driving this on my side with tests, but won't be including them in the post. I will be adding tags to the repository periodically so that you can check out the tests. And also, if someone else says I'm doing it wrong, they're probably right.

I'm also using [httpie](https://github.com/jkbrzt/httpie) for testing, because it's awesome. So I'm sending this message a lot

    :::bash
    $ http post "localhost:6438/log" sendtime="2016-02-29T02:58:09Z"

While I'm changing things, I'll also alias a few references, so that we can stop typing `Loggex.Repo` everywhere, and just type `Repo`.

The current state of the code before making any changes is [[s4]](https://github.com/philosodad/loggex/tree/s4).

Removing the existing implementation is pretty trivial, we just remove the timefixer plug and method from the `lib/loggex.ex` file. I tend to bounce around between test and REPL driven development, so the sequence I went through was something like this:

    :::bash
    $ iex -S mix
    
    :::iex 
    Loggex.start

And then in a different window
    
    :::bash
    $ http post "localhost:6438/log" sendtime="2016-02-29T02:58:09Z"
    
Which should result in a message letting me know that the response was successful. Once I remove the plug and the plug code, if I rerun the http request, I should be an error in iex and in bash. My tests also fail, so now my goal is simply to get that request to work.

This turns out to be remarkably easy. First we just need to define a function in the Loggex.Logline module to handle the typecasting.

    :::elixir
    def changeset(logline, params) do
      
      cast(logline,
           params, 
           [], 
           [
            :sendtime, 
            :responseCode, 
            :sender, 
            :body
           ]
          ) 
    end

The cast method is defined in the [Ecto Documentation](https://hexdocs.pm/ecto/Ecto.Changeset.html#cast/4), in this case we are declaring that all keys are optional, but that all keys should be kept. Not only does this handle typecasting, it handles converting JSON string keys into the atomized keys as well, so our rather awkward method in `loggex.ex` goes from this:

    :::elixir
    post "/log" do
      Map.keys(conn.params)
      |> Enum.reduce(%{}, fn(k,acc) -> 
           Map.put(acc, String.to_atom(k), 
           conn.params[k]) end)
      |> (&(Map.merge(%Logline{}, &1))).()
      |> Repo.insert
      send_resp(conn, 200, "Request Logged")
    end

to this:

    :::elixir
    post "/log" do
      Logline.changeset(%Logline{}, conn.params)
      |> Repo.insert
      send_resp(conn, 200, "Request Logged")
    end

Which is much better. [[s5](https://github.com/philosodad/loggex/tree/s5)]

The next thing that we probably want to do is introduce some configuration. Right now we're using the same database in dev, test, and production environments. To fix this, we can make some changes in the config folder. Right now the only file in that folder is config.exs, and it has the content that Ecto added already:

    :::elixir 
    use Mix.Config

    config :loggex, Loggex.Repo,
      adapter: Ecto.Adapters.Postgres,
      database: "loggex_repo",
      username: "postgres",
      password: "postgres",
      hostname: "localhost"

To use a test database in test, we need to add two new files to the /config folder, `test.exs` `dev.exs` (eventually we will need `prod.exs` as well). What we'll do is copy the existing config file, so that the contents of the test and dev config files are identical to the config.exs file. Then we can delete the config `:loggex, Loggex.Repo` block in `config.exs` and replace it with this:

    :::elixir
    use Mix.Config
    import_config "#{Mix.env}.exs"

In the `config/test.exs` file we alter the config to read like this:

    :::elixir
    use Mix.Config

    config :loggex, Loggex.Repo,
      adapter: Ecto.Adapters.Postgres,
      database: "loggex_test",
      username: "postgres",
      password: "postgres",
      hostname: "localhost"

This will cause issues if we try to run mix test, we're going to have to add this database and migration. That can be done by specificying the environment on the command line:

    :::bash
    $ MIX_ENV=test mix ecto.create
    $ MIX_ENV=test mix ecto.migrate

So now if we run `mix test`, tests will be run agains the test database. [[s6](https://github.com/philosodad/loggex/tree/s6)]

As it is now, the tests do not each clear the database before they are run. And  In order to fix this, we want to add some commands to the `test/test_helper.exs` file.

Specifically, we if we want to run tests inside of a transaction, so that they roll back, and we don't want to have to run `ecto.migrate` inside of dev and test everytime we change something, we're going to want to make a few changes to our `test/test_helper.exs` file. This file is created automatically, and contains the command `ExUnit.start()`. We can add the mix tasks that create and migrate the databases here: 

    :::elixir
    ExUnit.start()

    Mix.Task.run "ecto.create", ["--quiet"]
    Mix.Task.run "ecto.migrate", ["--quiet"]

That gets us started, we can run `mix test`, and it will create and migrate the test database if needed. But what about having all the tests run inside of transactions? Up to this point, we haven't looked at the tests at all. Here's the current state of the `test/loggex_test` file.

    :::elixir
    defmodule LoggexTest do
      use ExUnit.Case
      import Ecto.Query
      doctest Loggex
      
      setup do
        :random.seed(:erlang.now)
        {:ok, repo} = Loggex.start
        on_exit fn ->
          Loggex.stop
        end
        :ok
      end

      test "route exists" do
        ...
      end

      test "route inserts... into the database" do
        ...
      end
    end
        
If we run that file right now, we'll add two entries to the database every time. So what we want to do is to have the tests run inside of a transaction, so that we don't accumulate database entries. To do this, we'll add code to two files, `config/test.exs` and `test/loggex_test`. We'll change the pool manager for the `Ecto.Adapter` first, so that in test it uses `Ecto.Adapters.SQL.Sandbox` instead of the default of Poolboy.

    :::elixir
    use Mix.Config
    config :loggex, Loggex.Repo,
      adapter: Ecto.Adapters.Postgres,
      pool: Ecto.Adapters.SQL.Sandbox,
      username: "postgres",
      password: "postgres",
      database: "loggex_test",
      size: 1

Then in the test itself, we'll add a line to wrap each test block in a transaction:

    :::elixir
    setup do
      :random.seed(:erlang.now)
      {:ok, _repo} = Loggex.start
      Ecto.Adapters.SQL.restart_test_transaction(Loggex.Repo)
      on_exit fn ->
        Loggex.stop
      end
      :ok
    end

And now when we rerun the tests, we should start each test block with an empty database. [[s7](https://github.com/philosodad/loggex/tree/s7)]

[Next entry](http://www.johnpdaigle.com/complexable/2016/03/12/elixometer-and-influxdb.html), we'll look into either deployment or monitoring.
