---
title: To make maps out of JSON
date: 2019-04-12 08:43 EDT
tags:
---

We maintain a small Elixir library called [Morphix](https://hex.pm/packages/morphix), described as "a small package of convenience methods for working with Maps, Tuples, and Lists". In the nature of libraries, it keeps growing, and as far as I can tell from the last several pull requests and changes, the main motivation for growth has been to work with JSON.

That's certainly the case with the last change my collaborator and I made to the library. The problem we had is probably a fairly common one having to do with mapping nested data structures from JSON to Ecto, which is that JSON keys are traditionally camelCase and Ecto keys are typically snake\_case.

So you might have the following JSON:

    :::json
    {
      "title": "Cloud Dragon Skies",
      "publicationDate": 2005,
      "author": {
         "name": "N.K. Jemison",
         "birthYear": 1972
      }
    }

Which corresponds to the following schema in a Phoenix application:

    :::elixir
    schema "short_stories" do
      field :title, :string
      field :publication_date, :integer

      embeds_one :author,
                 Author,
                 primary_key: false,
                 on_replace: update do
        field(:name, :string)
        field(:birth_year, :integer)
      end

      timestamps()
    end

Okay, so this is terrible data design, but let's just ignore that for a moment and think about what we need to do to convert one of these things to the other. We're going to want to convert the key "birthYear" to "birth\_year", for example. With a schema this small it would be no problem to just write a direct mapper with specific keys, but it would be nice to just transform the keys.

There are several libraries that will transform strings between CamelCase, pascalCase, and snake\_case. My favorite is [Inflex](https://hex.pm/packages/inflex), which has a very straightforward API.

We could import Inflex and write some code to transform the keys, but I'm pretty lazy and I know that I've written this code before, when I wrote the code to convert string keys to atoms in arbitrarily deep maps. And then a bit later, someone else wrote the code to convert atom keys to strings in arbitrarily deep maps. This particular problem of making conversions to keys in nested maps is built into Morphix.

To convert strings to atoms in [version 0.6.0](https://github.com/philosodad/morphix/blob/v0.6.0/lib/morphix.ex) the Morphix library depends on a private method called `depth_atomog\3`:

    :::elixir
    defp depth_atomog(map, safe_or_atomize, allowed \\ []) do
      atomkeys = fn {k, v}, acc ->
        cond do
          is_struct(v) ->
            Map.put_new(acc, safe_or_atomize.(k, allowed), v)

          is_map(v) ->
            Map.put_new(
              acc,
              safe_or_atomize.(k, allowed),
              depth_atomog(v, safe_or_atomize, allowed)
            )

          is_list(v) ->
            Map.put_new(
              acc,
              safe_or_atomize.(k, allowed),
              process_list_item(v, safe_or_atomize, allowed)
            )

          true ->
            Map.put_new(acc, safe_or_atomize.(k, allowed), v)
        end
      end

      Enum.reduce(map, %{}, atomkeys)
    end

This method looks more complicated than it is, I think, or it least it looks complicated to me. The `atomkeys` function handles the issue of what to do with each key/value combination in the map, and we use `Enum.reduce` to build a new map. If the value we see is a map we make a recursive call, and if it's a list we make a call to a list processor (in case there's a map in the list). We pass in the method `safe_or_atomize` and call it on each key we see. If we dig into the code we'll see that we pass a couple of different functions into this method, either `atomize_binary/2` or `safe_atomize_binary/2`. "Safe" in this case means that strings will only be converted to existing ones. The "allowed" list provides another way to control what strings will be converted. 

Converting keys from atoms to strings is handled by the `srecurse\3` method:

    :::elixir
    defp srecurse(map, helper, allowed \\ []) do
      stringkeys = fn {k, v}, acc ->
        cond do
          is_struct(v) ->
            Map.put_new(acc, helper.(k, allowed), v)

          is_map(v) ->
            Map.put_new(
              acc,
              helper.(k, allowed),
              srecurse(v, helper, allowed)
            )

          is_list(v) ->
            Map.put_new(
              acc,
              helper.(k, allowed),
              sprocess_list_item(v, helper, allowed)
            )

          true ->
            Map.put_new(acc, helper.(k, allowed), v)
        end
      end

      Enum.reduce(map, %{}, stringkeys)
    end 

Which does exactly the same things, just with a different second argument.

Which means it should be very simple to convert keys using any transformer and DRY our code up at the same time by introducing a new public method in [Morphix 0.7.0](https://github.com/philosodad/morphix/tree/v0.7.0), which is called `morphiform!/3`. We can use this in our code writing a transformer that takes two arguments (the key and the `allowed` list):

    :::elixir
    defp transform(params) do
      Morphix.morphiform!(params, &update_key/2)
    end

    defp update_key(key, []) when is_binary(key) do
      Inflex.underscore(key)
    end

    defp update_key(key, []), do: key

And the camel cased strings are converted into snake cased strings at whatever level of the map they're at, and any non-string keys are ignored. We've expanded what Morphix can do and reduced its line count by about 30.
