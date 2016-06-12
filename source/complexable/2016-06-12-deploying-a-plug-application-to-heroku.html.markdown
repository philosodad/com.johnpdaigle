---
title: Deploying a Plug.Router Application to Heroku
date: 2016-06-12 09:17 EDT
tags:
---

For this blog post, we're going to start with a fresh application, keeping our focus on maintaining a deployment to heroku. The minimum project is a simple Plug.Router app that serves a web page of some kind. So it has to run from the command line with `mix run --no-halt`. We'll create a new elixir app with `mix new ping_and_log` and then add the needed dependencies for Plug.Router. 

From the [last post](http://www.johnpdaigle.com/complexable/2016/05/08/running-from-shell.html), we know that we need to make a few changes to our mix file in order for the app to run from the command line, and of course we should define a start function and add a route.

I'll skip the step-by-step here and just reference a working Plug.Router app ([tagged on github](https://github.com/philosodad/ping_and_log/tree/v0.0.1)). This app has one route '/ping', and it respongs with "I say PONG". 

The rest of this post assumes that you have already installed the Heroku toolbelt and have a heroku account. If that isn't the case, you should probably take a few minutes to follow one of [Heroku's guides](https://devcenter.heroku.com/start) up to the "logs" section.

What happens when we try to deploy this app to Heroku? In order to deploy we'll need a custom buildpack, [available from hashnuke](https://github.com/HashNuke/heroku-buildpack-elixir). From inside the top level of our application directory, we run the command:

    :::bash
    $ heroku create –buildpack \
    "https://github.com/HashNuke/heroku-buildpack-elixir.git"

That should give us a new application in heroku. We can find the URL for this app by using the heroku cli:

    :::bash
    $ heroku apps:info   

Navigating to this URLs `/ping` route should give you an error, because we haven't deployed anything yet. So let's deploy our application using git:

    :::bash
    $ git push heroku master

This should give us a lot of output, ending with the message `remote: Verifying deploy.... done.` and some more boilerplate. If we visit our applications `/ping` page now, we'll get a new error. This is progress.

What's happening here? The new error should be suggesting that you check the logs, so we'll do that.

    :::bash
    $ heroku logs

Somewhere in the log you'll see an error: `Web process failed to bind to $PORT within 60 seconds of launch`, which tells us that Heroku was expecting our app to start up using an environment variable that we aren't using.

The best way to do config in Elixir is always in the config files. The less good, but somewhat easier, way to work with environment variables is to use [env\_helper](https://github.com/manheim/env_helper), which is an environment variable helper that we built at Manheim.

We're going to use env\_helper. Add this to your mix.exs file or just [checkout the next version of the app](https://github.com/philosodad/ping_and_log/tree/v0.0.2):

    :::elixir
    defp deps do
        [
          {:cowboy, "~> 1.0.0"},
          {:plug, "~> 1.0"},
          {:env_helper, "~> 0.0.2"}
        ]
    end

And then add a file, Settings.ex, with this content:

    :::elixir
    defmodule Settings do
      import EnvHelper
      system_env(:port, 26439, :string_to_integer)
    end

And then change your '/ping' route to:

    :::elixir
    def start do
      Cowboy.http PingAndLog, [], 
                  port: Settings.port
    end

At this point, your app should start locally on port 26439 (feel free to change that) unless you set the environment variable PORT. You can test this:

    :::bash
    $ PORT=29322 mix run --no-halt

This should start up your cowboy server, and if you navigate to `localhost:29322/ping` you should get a response with the body "I say PONG".

There's still a few things to be done, like making the env\_helper settings respond to the `Mix.env`, and all of that cleanup is in the [next github tag](https://github.com/philosodad/ping_and_log/tree/v0.0.3). However, at this point, if we push to `heroku master`, we should have a running elixir app on Heroku.
