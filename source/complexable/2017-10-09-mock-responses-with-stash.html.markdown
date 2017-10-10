---
title: Mock responses with Stash
date: 2017-10-09 01:30 EDT
tags:
---

So a few posts ago, we looked at how to [abstract dependent modules](http://www.johnpdaigle.com/complexable/2016/10/23/mock-modules-and-where-to-find-them.html) in Elixir to make testing easier. That post and its [follow up](http://www.johnpdaigle.com/complexable/2016/11/09/real-responses-from-mock-modules.html) attempt to implement a pattern suggested by [Jose Valim](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/), which he called *explicit contract*. This pattern has the following characteristics:

1. The dependent module is wrapped, an interface is created to wrap around it.
1. A test version of the interface is created to handle test responses
1. Test responses are written in the test interface

Although, frankly, I think it falls somewhat short of a reasonable implementation of that pattern, because it's just too mocky. And we'll continue that half-baked iimplementation in this post, although hopefully in a future post we'll move our implementation into a more correct place.

This post is concerned with moving our test responses out of the test interface module and into the tests themselves. This is useful because we don't have to move from file to file while we're working on the tests. It should simplify our test code somewhat.

To do this, we're going to use a library called [Stash](https://hexdocs.pm/stash/api-reference.html), which is a wrapper around ETS, Elixir's build in key-value store. Adding Stash is simple, of course we add stash to our `mix.exs` file:

    :::elixir
    defp deps do
      [
        {:env_helper, "~> 0.0.4"},
        {:httpoison, "~> 0.10.0"},
        {:poison, "~> 3.0"},
        {:stash, "~> 1.0"}
      ]
    end

And then change the implementation of `test/support/http.ex`. Previously, we only had a mock response for the 404 case:

    :::elixir
    defmodule NearEarth.TestHttp do
      use HTTPoison.Base

      def get("https://api.nasa....?api_key=DEMO_KEY") do
        {:ok, %HTTPoison.Response{headers: [],
                                  status_code: 404}}
      end

      def get(args) do
        HTTPoison.get(args)
      end
    end

But now we're going to redefine the `get` method to use stash:

    :::elixir
    def get(route) do
      Stash.get(:near_earth, route)
    end

So whatever value is stored in the ETS table `:near_earth` for the key `route`, that's what the get method will return.

Obviously, to get our current tests working we're going to need to do some work. Right now, we have two tests. The first tests our response to a 404, the second actually makes a real call out to the near earth api to get an asteroid and then tests the parsing of that JSON file. To get the 404 test working, we add a response to the setup: 

    :::elixir
    setup do
      not_found = %HTTPoison.Response{status_code: 404}
      {:ok, %{not_found: not_found}}
    end

And then add that response to the `:near_earth` stash table in the test:

    :::elixir
    test "will return not found if 404", context do
      Stash.set(:near_earth, 
                "#{Sets.neo_url}fakevalue?api_key=#{Sets.api_key}",
                {:ok, context.not_found})
      assert {:error, :not_found} == 
             NearEarth.get_asteroid("fakevalue")
    end

So we've set the value of `"#{Sets.neo_url}fakevalue?api_key=#{Sets.api_key}"` to be an HTTPoison response with a status of 404.

The `get_asteroid` call uses the HTTP module:

    :::elixir
    def get_asteroid asteroid do
    url = "#{Sets.neo_url}#{asteroid}?api_key=#{Sets.api_key}"
      case Sets.http.get(url) do
        {:ok, response = %{status_code: 200}} -> 
          Poison.decode(response.body)
        {:ok, %{status_code: 404}} ->
          {:error, :not_found}
      end
    end

And because we're using the test http module in our test environment, we get back the fake 404 response and the test passes.

A similar strategy will work for getting the asteroid, although in that case we will need a fake asteroid JSON response to work with. My solution to this, for the moment, was to add that as a json file in the `test/support` folder and then add a module `stubs`:

    :::elixir
    defmodule NearEarthTest.Stubs do
      def asteroid do
        {:ok, asteroid} = File.read("test/support/asteroid.json")
        asteroid
      end
    end

Add the stub to the test setup:

    :::elixir

    asteroid_response = %HTTPoison.Response{status_code: 200, 
                          body: Stubs.asteroid}

    {:ok, %{asteroid: asteroid_response,
            not_found: not_found}}

And then put that in the test:

    :::elixir
    test "retrieves asteroid by designation", context do
      id = "3542519"
      Stash.set(:near_earth, 
                "#{Sets.neo_url}#{id}?api_key=#{Sets.api_key}",
                {:ok, context.asteroid})
      {:ok, asteroid_response} = NearEarth.get_asteroid(id)
      assert asteroid_response["name"] == "465633 (2009 JR5)"
    end

And again, we should have a passing test.

One obvious problem with this implementation is that I'm making everything very tightly coupled to the HTTPoison library. In a future post, we'll change the `http` module so that this coupling disappears, but for now we'll live with it.

We've refactored, and now we want to add an endpoint. In particular, I'd like to get all the asteroids that will make their closest approach today. Fortunately, NASA has a useful `/feed` endpoint that takes a start and end date as arguments. To write the failing test, we'll add another library to our codebase. [Faker](https://hex.pm/packages/faker) is a good library for generating fake data of various kinds, such as dates, addresses, and of course styles of beer. We use Faker at work mostly for dates, addresses and to generate fake car make and model names. Here, we're interested in the date functionality.

We'll also want to add another stub, this wone with a real JSON response from the feed api. We'll again use the `Stubs` module to import the file, and add the stub to the test setup:

    :::elixir
    asteroids_response = 
      %HTTPoison.Response{status_code: 200, 
                          body: Stubs.asteroids}
    {:ok, %{asteroids: asteroids_response,
            asteroid: asteroid_response,
            not_found: not_found}}

And then test against the stub by adding the fake response to stash:

    :::elixir
    test "retrieves today's asteroids", context do
      today = Date.utc_today
              |> Date.to_string
      tomorrow = Faker.Date.forward(1)
                 |> Date.to_string
      Stash.set(:near_earth, 
        "#{Sets.neo_url}feed?start_date=#{today}&end_date=#
    {tomorrow}&api_key=#{Sets.api_key}", 
        {:ok, context.asteroids})
      {:ok, asteroids} = NearEarth.get_today()
      assert asteroids == context.asteroids.body 
                          |> Poison.decode!
    end

Since we haven't implemented `get_today` at all, it's pretty clear we're going to get a failing test here. So, we'll get it passing:

    :::elixir
    def get_today do
      today = Date.utc_today()
              |> Date.to_string()
      tomorrow = :calendar.universal_time
                 |> :calendar.datetime_to_gregorian_seconds
                 |> (&(&1 + 86400)).()
                 |> :calendar.gregorian_seconds_to_datetime
                 |> elem(0)
                 |> Date.from_erl
                 |> elem(1)
                 |> Date.to_string 
      case Sets.http.get("#{Sets.neo_url}feed?start_date=#{t
    oday}&end_date=#{tomorrow}&api_key=#{Sets.api_key}") do
        {:ok, response = %{status_code: 200}} -> 
          Poison.decode(response.body)
      end

Granted, that could be the most convoluted method ever of getting a date string for tomorrow, but I think that this one will at least work. As always, [a working version of this code is available on github](https://github.com/philosodad/near_earth/tree/mock-with-stash).
