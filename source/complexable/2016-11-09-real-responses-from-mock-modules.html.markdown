---
title: Real Responses from Mock Modules
date: 2016-11-09 21:32 EST
tags:
---

[A couple of weeks ago](http://www.johnpdaigle.com/complexable/2016/10/23/mock-modules-and-where-to-find-them.html), I wrote about how to move a mock module out of your production code and into your test folder. Today we'll follow up with a short post on getting fake responses from your mock module. For this example I'm going to use HTTP mocking, because that is the one thing I have to mock more than any other, and because it is a heck of a lot easier than mocking Logger, which is the other thing I'd really like to mock.

So we'll start with a very simple project. Our project will be a library that calls the NASA near earth object apis, which we'll call [near\_earth](https://github.com/philosodad/near_earth). 

Now, this is obviously a bit contrived as an example, but that's okay. We'll start by setting up without any mocking, this app is going to test directly against the APIs[[github tag: nomock](https://github.com/philosodad/near_earth/tree/nomock)].

At this point, we've added the `http_poison` library and set up a single test:

    :::elixir
    test "retrieves asteroids by designation" do
      {:ok, asteroid} = NearEarth.get_asteroid("3542519")
      assert asteroid["name"] == "(2010 PK9)"
    end

The idea being to call the APIs and make sure we get back a known asteroid. This test is pretty easy to pass, in the `NearEarth` module we define a method (the entire URL is not shown)

    :::elixir
    def get_asteroid asteroid do
      {:ok, response} = HTTPoison.get("https://api.nasa....")
    end

And that test passes. So, we're happy with that, but now we want to test what happens when the API returns a 404. We write another test:

    :::elixir
    test "will return a not found message for a missing asteroid" do
      assert {:error, :not_found} == NearEarth.get_asteroid("fakevalue")
    end

It's pretty unlikely that there is now, or will ever be, an asteroid with the official designation "fakevalue", but still it might be nice to be able to fake that response somehow. So we decide to use the [explicit interface pattern](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/). This involves a few steps. First, we want to replace our `HTTPoison` call with a call to a module we define, and we want to create a test version of the module. So step one is to create an application environment variable that sets the name of the module. In `test.exs`:

    :::elixir
    config :near_earth, http: NearEarth.TestHttp

I'm not going to define this in any other module, because I'm going to use `env_helper` to provide me with a default:

    :::elixir
    defmodule Sets do
      import EnvHelper
      app_env(:http, [:near_earth, :http], NearEarth.Http)
    end

The `NearEarth.Http` module can just pass through to HTTPoison:

    :::elixir
    defmodule NearEarth.Http do
      use HTTPoison.Base
    end

And initially, so can the test library, so it will initially have the same code. We create a file called `test_http.ex` with the same content as above, and put it in a `test/support/` folder. Then we add this file to the compile path by making a change to the `mix.exs` file. Briefly, add this line to the `project` section:

    :::elixir
    elixirc_paths: elixirc_paths(Mix.env),

And define two private methods:

    :::elixir
    defp elixirc_paths(:test) do
      ["lib", "test/support"]
    end

    defp elixirc_paths(_) do
      ["lib"]
    end
     
For more explanation of why we're doing this, read the [previous post](http://www.johnpdaigle.com/complexable/2016/10/23/mock-modules-and-where-to-find-them.html).

Once we've done that, we're going to add a mock response to the test module 

    :::elixir
    def get("https://api.nasa.gov/neo/rest/v1/neo/fakevalue?api_key=DEMO_KEY") do
      {:ok, %HTTPoison.Response{headers: [], status_code: 404}}
    end

    def get(args) do
      HTTPoison.get(args)
    end

The second method is required because we have redefined `get/1` in this module, and `HTTPoison.get/1` will no longer be found automatically. We've got a failing test now, which we can pass by writing the code to handle the 404 response[[github tag: mock404](https://github.com/philosodad/near_earth/tree/mock404)].

Now, obviously we could mock the other response as well, and probably should, but what is interesting to me here is that we are using two different approaches in our testing. One test calls the actual API, the other test is will short circuit and return a faked response. We use this at work all the time, because a lot of our HTTP calls are to services that we built or to services we have built simulators for, and that are usually running locally on our dev boxes. In those cases, we really want to call those services most of the time. But, we also want to simulate various types of errors that are are hard to force, and in those cases we can use the mock to throw the appropriate errors. Also, some of the services we call are not ones that we build, or that we have built mock services to simulate, and in those cases we always want to use the fake responses. What is nice about this is that we have a lot of flexibility in how we use this pattern in our testing.

I would encourage anyone who isn't familiar with this pattern to [fork the repo](https://github.com/philosodad/near_earth) and try some different scenarios, such as handling a network timeout or a 401 response, and see how you can use the mock module to simulate those responses. Have fun!
