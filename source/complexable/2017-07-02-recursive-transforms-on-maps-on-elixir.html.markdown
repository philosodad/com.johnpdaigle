---
title: Recursive Transforms on Maps on Elixir
date: 2017-07-02 13:22 EDT
tags:
---

Some time ago, a co-worker and I wrote the [mogrify](https://github.com/philosodad/mogrify) gem, which contained a few non-destructive tranformers for Enumerables in Ruby. So, for example, the `symogriform` method converts string keys to symbols in a Ruby has, including keys for nested hashes. This is usefull, or at least a convenience, when working with JSON and so when I started writing APIs with elixir I wanted to write an equivalent library.

That library is called [morphix](https://hex.pm/packages/morphix). The implementation is fairly straightforward, but I thought it might be interesting to look at it anyway. It uses some guard clauses and a lot of recursion, but other than that I think that most of the code would translate fairly directly into other languages.

Morphix contains 4 basic methods `atomorph-`, `morphiflat`, `compact-`, and `morphiphy`. `atomorph-` and `compact` come in two flavors, `fy` and `form`, which are non-recursive and recursive versions, respectively, and each of these is available either with a '!' or without. So, `compactiform` is the recursive version of `compatify`, and returns `{:ok, map}` or `{:error, message}` depending.

So, what's wrong with these naming conventions? Well, to start with, you have to know them to use them. It isn't obvious what `compactify` does, or that it is not a deep transform while `compactiform` is. A better name would be `compact` and `deep_compact`, which makes the difference obvious. Similarly, `atomorphify` is a fairly non-obvious name versus, say, `atomize_keys`. From a marketing, and to a lesser degree, usability standpoint, Morphix is a mess. Heck, even the name is sort of difficult. "'Morphix'? What the heck is that?

Basically, the names are clever, and clever is always a gamble.

Fortunately, the code isn't clever, so we'll be able to walk through it pretty easily. The method I wrote most recently was the `compactif-` code, and there were some unexpected pitfalls that caused me to run rapidly from version 0.0.5 to 0.0.7, fixing various issues that weren't showing up until I ran it against some real world examples.

So the point of the `compactif-` group of functions is to take a map and remove keys from the map if they have nil or empty map values. The shallow version is very simple:

    :::elixir
    def compactify!(map) when is_map(map) do
      map
      |> Enum.reject(fn({_k,v}) -> is_nil(v) end)
      |> Enum.into(%{})
    end

This simply uses `Enum.reject/2` to remove the values, producing a keyword list, and `Enum.into/2` to take that list and turn it back into a map. More interesting is the `compactiform!/1` method:

    :::elixir
    def compactiform!(map) when is_map(map) do
      compactor = fn({k, v}, acc) ->
        cond do
          is_map(v) and Enum.empty?(v) -> acc
          is_map(v) -> Map.put_new(acc, k, compactiform!(v))
          is_nil(v) -> acc
          true -> Map.put_new(acc, k, v)
        end
      end
      Enum.reduce(map, %{}, compactor)
    end

This follows a pattern established in the deep atomizing method in this library, defining an anonymous function that contains the transformer and the recursive call, then reducing into an empty map with the transformer. There's a problem with this method, however, which shows up when you have a value that is a struct.

    :::iex
    iex(1)> d = DateTime.utc_now
    %DateTime{calendar: Calendar.ISO, day: 8, hour: 13, microsecond: {973343, 6},
     minute: 44, month: 7, second: 12, std_offset: 0, time_zone: "Etc/UTC",
     utc_offset: 0, year: 2017, zone_abbr: "UTC"}
    iex(2)> Morphix.compactiform(%{a: d})
    {:error,
     %Protocol.UndefinedError{description: "", protocol: Enumerable,
      value: %DateTime{calendar: Calendar.ISO, day: 8, hour: 13,
       microsecond: {973343, 6}, minute: 44, month: 7, second: 12, std_offset: 0,
       time_zone: "Etc/UTC", utc_offset: 0, year: 2017, zone_abbr: "UTC"}}}
 
Fun fact: structs are **bare maps**, so `is_map(struct)` returns `true`, but they don't implement Enumerable. The best way I found to check whether something is a struct or not was to check for the `__struct__` key:

    :::elixir
    def compactiform!(map) when is_map(map) do
      compactor = fn({k, v}, acc) ->
        cond do
          is_map(v) and Map.has_key?(v, :__struct__) -> 
            Map.put_new(acc, k, v)
          is_map(v) and Enum.empty?(v) -> acc
          is_map(v) -> Map.put_new(acc, k, compactiform!(v))
          is_nil(v) -> acc
          true -> Map.put_new(acc, k, v)
        end
      end
      Enum.reduce(map, %{}, compactor)
    end

Which may not be the smartest way to do this, but it does work. So, that took care of version 0.0.6, and I felt pretty much done.

Not so fast, of course. One problem is that if the compactor returns an empty map, you end up with an empty map. My goal was to treat empty maps as nil values, so an additional call to `compactify!` was required in order to finish out the library. 


    :::elixir
    def compactiform!(map) when is_map(map) do
      compactor = fn({k, v}, acc) ->
        cond do
          is_map(v) and Map.has_key?(v, :__struct__) -> 
            Map.put_new(acc, k, v)
          is_map(v) and Enum.empty?(v) -> acc
          is_map(v) -> Map.put_new(acc, k, compactiform!(v))
          is_nil(v) -> acc
          true -> Map.put_new(acc, k, v)
        end
      end
      Enum.reduce(map, %{}, compactor)
      |> compactify!
    end

So, 3 short minor versions later, and I had my nested compactor and was ready to use it in a project at work. Of course, we ended up not using the new method and using `atomorphiform!/1` in an unrelated part of the codebase, but that seems to always be the way. I like this pattern, though and I wish I could figure out a way to make it more generic.
