---
title: Adding CI and Coveralls to an Elixir Project
date: 2016-03-20 11:23 EDT
tags:
---

This week we'll continue working with the logging application we started in February. In the [first post](http://www.johnpdaigle.com/complexable/2016/02/20/building-a-simple-app-with-plugrouter-and-ecto.html), we build a simple application using Plug.Router and Ecto. [Next](http://www.johnpdaigle.com/complexable/2016/03/05/resetting-a-test-database-with-ecto.html), we refactored that application and generally improved its test behavior, setting it up to reset the test database. The [last post](http://www.johnpdaigle.com/complexable/2016/03/12/elixometer-and-influxdb.html) we set the project up to output performance metrics using [Elixometer](https://github.com/pinterest/elixometer) and [Influx](https://influxdata.com/). Today, I want to add continuous integration and test coverage metrics through [excoveralls](https://github.com/parroty/excoveralls).

We're going to connect two different CI services, not because it's terribly useful, but just to compare the difficulty of the two. The first one is TravisCI. 

[TravisCI](https://travis-ci.org/) is a popular service that supports Elixir very well. Travis builds are run in docker containers, and supports login through GitHub and other niceties. Travis builds are configured through a file in your base project folder called .travis.yml.

If you haven't used Travis before, now would be an excellent time to get a Travis account and connect it to your GitHub or BitBucket account. You might also want to fork the loggex project at the [[s8]](https://github.com/philosodad/loggex/releases/tag/s8) elixir-travis-coverallstag, which is the state we were in at the end of the last post.

Much like in the last post, the scope of this post doesn't include how to use Travis, Semaphore, or Coveralls as platforms. If you aren't familiar you'll probably have to do some clicking around to find what you need. But once you have your project set to build in Travis, all you need to do is add a .travis.yml file with the following content:

    :::yaml
    language: elixir
    elixir:
      - 1.2.2
    otp_release:
      - 18.2.1
    services: postgresql

Commit, and push to master. [[s9]](https://github.com/philosodad/loggex/releases/tag/s9)

That's it. I messed around a bit with this [[s9a]](https://github.com/philosodad/loggex/releases/tag/s9a)[[s9b]](https://github.com/philosodad/loggex/releases/tag/s9b) before I realized that I needed to specify the elixir version and I didn't need to have a command to build the postgres database. The `mix ecto.create` command we added to the `test_helper.exs` file takes care of that for us.

So now, if everything is going well, we've got our build wired up to work with a CI server.

Of course, Travis is not the only service out there, so I wanted to also show how to connect our project to [Semaphore](https://semaphoreci.com). Semaphore also has good Elixir support. One difference between the two is that Semaphore does not support logging in through GitHub (you'll have to sign up for an account) and it has more choices that you can make while setting up a project. Still, you should be able to walk through those steps and get your repo configured to build on Semaphore, but because Semaphore depends on environment variables to build the database, so we have to add those values into the `test.exs` file. Our old file had the postgres default username and password:

    :::elixir
    use Mix.Config
    config :loggex, Loggex.Repo,
      adapter: Ecto.Adapters.Postgres,
      pool: Ecto.Adapters.SQL.Sandbox,
      username: postgres 
      password: postgres
      database: "loggex_test",
      size: 1

And our change brings in environment variables:

    :::elixir
    use Mix.Config
    config :loggex, Loggex.Repo,
      adapter: Ecto.Adapters.Postgres,
      pool: Ecto.Adapters.SQL.Sandbox,
      username: System.get_env["DATABASE_POSTGRESQL_USERNAME"]
                || "postgres",
      password: System.get_env["DATABASE_POSTGRESQL_PASSWORD"]
                || "postgres",
      database: "loggex_test",
      size: 1

As always, some line breaks are for fitting in to this space (one day, I'm going to reformat this blog or move it to a better platform), so look for compilation errors.

At this point, if you push this project, it should build on both Semaphore and Travis, and provided your tests are passing (mine are) you should have passing builds[[s10]](https://github.com/philosodad/loggex/releases/tag/s10).

Naturally, since we've written tests, we want the world to know what wonderful tests we've written, right? So we'll add another web service, [Coveralls](https://coveralls.io), and set Travis to push a report to coveralls every time it builds. 

Coveralls, like Travis, supports GitHub login, so before setting your project up to use coveralls you'll need to log in to coveralls and set up coveralls for the repository you have the project in. Once that's done, we can set up Travis to push to Coveralls.

To do this, we'll want to add the coveralls package to `mix.exs` and make a change to `.travis.yml`. Adding coveralls into mix is easy, we just add the [excoveralls](https://github.com/parroty/excoveralls) dependency to the `deps` function:

    :::elixir
    defp deps do
      [
        {:httpoison, "~> 0.8.0"},
        {:cowboy, "~> 1.0.0"},
        {:plug, "~> 1.0"},
        {:exjsx, "~> 3.2"},
        {:postgrex, ">= 0.0.0"},
        {:ecto, "~> 1.1.2"},
        {:elixometer, github: "atlantaelixir/elixometer", 
                      override: true},
        {:uuid, "~> 0.1.1"},
        {:excoveralls, "~> 0.4", only: :test}
      ]
    end

Unfortunately, if we run `mix deps.get`, we'll get an error because excoveralls uses a different version of hackney than elixometer does. Fortunately, the error message tells you exactly what to do, so you can specify a version of hackney:

    :::elixir 
    defp deps do
      [
        {:httpoison, "~> 0.8.0"},
        {:cowboy, "~> 1.0.0"},
        {:plug, "~> 1.0"},
        {:exjsx, "~> 3.2"},
        {:postgrex, ">= 0.0.0"},
        {:ecto, "~> 1.1.2"},
        {:hackney, ~r/.*/,
           [git: "git://github.com/benoitc/hackney.git",
            branch: "master",
            manager: :rebar,
            override: true]},
        {:elixometer, github: "atlantaelixir/elixometer",
                      override: true},
        {:uuid, "~> 0.1.1"},
        {:excoveralls, "~> 0.4", only: :test}
      ]
    end

And I should be able to run:

    :::bash
    $ mix deps.get
    $ MIX_ENV=test mix coveralls

And get the happy news that my test coverage is 100%. Granted, there are only ten lines of code in the project that are considered "relevant", but all of them are tested. To have this run from Travis, we add a couple of lines to the `.travis.yml` file:

    :::yaml
    language: elixir
    elixir:
      - 1.2.2
    otp_release:
      - 18.2.1
    services: postgresql
    env:
      - MIX_ENV=test
    script: mix coveralls.travis

And now, assuming that I set everything up correctly, when I push to master,  I should see test coverage reflected on the coveralls web site. [[s11]](https://github.com/philosodad/loggex/releases/tag/s11)

At some point, I'm not going to be able to avoid actually deploying this project, but I have one more step of procrastination to go before we do that.
