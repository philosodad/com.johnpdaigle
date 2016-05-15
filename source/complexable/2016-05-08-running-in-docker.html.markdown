---
title: Running in Docker
date: 2016-05-08 00:45 EDT
tags:
---

So it's been a long time, a little over a month, since I've looked at the logging application I was working on as a breakable toy, or updated this blog at all. But we're not done yet! If you haven't seen any of the previous posts about building a simple Elixir web application using Plug, you can find the [the first one here](http://www.johnpdaigle.com/complexable/2016/02/20/building-a-simple-app-with-plugrouter-and-ecto.html), where we set up the application to talk to the database, then there's some [refactoring](http://www.johnpdaigle.com/complexable/2016/03/05/resetting-a-test-database-with-ecto.html) and a few [metrics](http://www.johnpdaigle.com/complexable/2016/03/12/elixometer-and-influxdb.html) and most recently some [ci](http://www.johnpdaigle.com/complexable/2016/03/20/elixir-travis-coveralls.html). Today I'm thinking that I want two things, first, I want to build a start function for this app so that it will fire up from the command line, and second, I want to get it running on a Docker container. As before, I'll add a link the the tagged github commit that represents every section as we go, and some code examples might have line breaks for spacing reasons.

The first part is easy, since we already have a start function defined in the `/loggex.ex` file. First we need to add to the `mix.exs` file, then we need to modify the `start` function. First, the project mix file, we change the `application` function from this:

    :::elixir
    def application do
      [ applications: 
        [:logger, :cowboy, 
         :plug, :postgrex, 
         :ecto, :httpoison, 
         :elixometer] ]
    end

to this:

    :::elixir
    def application do
      [
        mod: {Loggex, []},
        applications: 
          [:logger, :cowboy, 
           :plug, :postgrex, 
           :ecto, :httpoison, 
           :elixometer]
      ]
    end

And then modify our existing `start/0` function in the `loggex.ex` file to be a `start/2` function:

    :::elixir
    def start _type, _args do
      Cowboy.http Loggex, [], port: 6438
      Repo.start_link
    end

Oh, and we need to add a `use Application` up at the top of the `loggex.ex` file:


    :::elixir
    defmodule Loggex do
      use Application
      use Elixometer
    ...
    end

For ease of testing, I'm going to add a new path:

    :::elixir
    get "/ping" do
      send_resp(conn, 200, "pong")
    end

And now in the command line:

    :::bash
    $ mix run --no-halt

Should start the server, and a simple get request to `localhost:6438/ping` should return a 200 with the content `pong`. [[s12]](https://github.com/philosodad/loggex/tree/s12)

Unfortunately, we've also broken our tests. If we run our tests at this point, we'll get an `Undefined Function` error for `Loggex.start/0`. We can fix that be doing a little repair work on the `Loggex` module:

    :::elixir
    def start( _type, _args ), do: start
    def start do
      Cowboy.http Loggex, [], port: 6438
      Repo.start_link
    end

And now we get a new `MatchError` because something is already started. It took me a bit to figure out what was going on here, and I'm not positive, but here goes: When we run the `Loggex.start/0` function, it starts a link. Because our app will probably start automatically when we start tests, the `mix test` command is running `start/2`, but because it doesn't have a flag not to quit, it's not keeping the web server up. But, that isn't closing the supervisor for the Ecto.Repo, and that remains up. Let's test this a bit:

    :::bash
    $ iex -S mix
    iex(1)> Loggex.start
    {:error, {:already_started, #PID<0.457.0>}}
    iex(2)> Loggex.stop
    :ok
    iex(3)> Loggex.start
    {:error, {:already_started, #PID<0.457.0>}}
    iex(4)> GenServer.whereis(Loggex.Repo)
    #PID<0.457.0>

So that is what's happening. I'm not sure that this is a good thing, because I'd like to really stop the whole stack cleanly with the `stop/0` function call. So what would be great would be two things: first, we'd like `Loggex.stop` to actually stop the entire process, and second, we'd like our tests to run.

Looking at the Ecto documentation, we see that the process that calls the `Repo.stop` function has to be the same as the function that calls `Repo.start_link`. So even if we find the pid of `Loggex.Repo` and call the stop function, it isn't going to work.

    :::iex
    iex(6)> GenServer.whereis(Loggex.Repo) |> Loggex.Repo.stop
    ** (exit) time out
     (ecto) lib/ecto/adapters/postgres.ex:56: 
            Ecto.Adapters.Postgres.stop/3
    iex(6)> 

Now, we can make the tests pass without solving this problem, by changing the `setup` function in `loggex_test.ex`:

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

The error is in the match on `Loggex.start`, if we change that line to get rid of the match, then the tests will pass:

    :::elixir
    setup do
      :random.seed(:erlang.now)
      Loggex.start
      Ecto.Adapters.SQL.restart_test_transaction(Loggex.Repo)
      on_exit fn ->
        Loggex.stop
      end
      :ok
    end

But that feels a little weak. What if we really want to kill that link? I'm sort of stuck at this point, I know I need a supervisor, but I'm not exactly sure how to set it up. So, I'm just going to post this and work on deploying to Heroku. [[s13]](https://github.com/philosodad/loggex/tree/s13)
