---
title: Consistent But Maybe A Little Confusing
date: 2015-10-17 15:37 EDT
tags:
---

A couple of weeks ago I started migrating my [mogrify](https://github.com/philosodad/mogrify) library from Ruby to Elixir. Mogrify comes out of some work I did a few years back with [Dan Tao](http://philosopherdeveloper.com/) while we were writing a data access layer betwee [Padrino](http://www.padrinorb.com/) and [Neo4j](http://neo4j.com/) via the [neography gem](https://github.com/maxdemarzi/neography). It started out because we needed to symbolize a bunch of keys in a hash, and while there is a gem for that, it's part of Active Record or Active Model or something huge, and we only needed the one function.

That function became several functions, and now theres this tiny little gem that does a few basic things with Enumerables in Ruby. For example, you can pass a block in with an array, and the hashmogrify function will use the block to create keys for a hash, where the values are the array.

For example, let's say I want to take an array of strings, and covert it to a hash where the key is the string reversed and turned into a symbol. 

    :::irb
    :006 > ["ab", "ac", "ad"].hashmogrify{|s| s.reverse}.
    :007 >   symogrify
    => {:ba=>"ab", :ca=>"ac", :da=>"ad"} 

Not terribly useful, perhaps, but we had some other tasks in the writing of the DAL that made it useful. 

I'm pretty happy with mogrify, so as I mentioned I thought it would be cool to port it over to Elixir, where I'm calling it [mogrexfy](https://github.com/philosodad/mogrexfy).

This naming is terrible, by the way, because there's an imagemagick filter called mogrify, but I didn't know that when I started, and here we are.

I decided to start with handling symbolizing (or, in the case of Elixir, Atomizing) keys. Sometimes, a map comes back from JSX with string keys, and I'd rather have it come back with atom keys.

Seems simple enough, and the elixir code *is* simple enough. The work is done by basically injecting the result of atomizing the keys into an empty map.

    :::elixir
    defp atomog (map) do
      atomkeys = fn({k, v}, acc) ->
        Map.put_new(acc, atomize_binary(k), v)
      end
      Enum.reduce(map, %{}, atomkeys)
    end

The `atomog` function is called by the `atomogrify` function, which returns `{:ok, <the new map>}`. 

    :::iex
    iex(1)> Mogrexfy.atomogrify %{"a" => "b", "c" => "d"}
    {:ok, %{a: "b", c: "d"}}

So far, so good.

Of course, I might pass in a map that has some keys that are already atoms, so we want to make sure that that works.

    :::iex
    iex(3)> Mogrexfy.atomogrify %{"a" => "b", c: "d"}
    {:ok, %{a: "b", c: "d"}}

And it does. Or does it?

    :::iex
    iex(5)> Mogrexfy.atomogrify %{a: "b", "c" => "d"}
    ** (SyntaxError) iex:5: syntax error before: "c"
    
There seems to be a problem with how I'm writing my map. In fact, there is. There's a difference between how the `a: b` syntax is handled and how the `a => b` syntax is handled.

    :::iex
    iex(6)> %{:a => "b", "c" => "d"}
    %{:a => "b", "c" => "d"}
    iex(7)> %{a: "b", "c" => "d"}   
    ** (SyntaxError) iex:7: syntax error before: "c"

And it has nothing to do with whether I'm using strings or atoms, using `:c => "d"` causes the same error.

So what's going on here? The short answer is that you shouldn't combine the `a: b` syntax with the `a => b` syntax, although clearly you *can* if the `a => b` syntax comes *first*. The longer answer is captured in [the issue](https://github.com/elixir-lang/elixir/issues/3794#issuecomment-143865327) I opened about this. 

This is mentioned in the documentation, and had I bothered to look I would have noticed it. I could have typed `h %{}` into IEx and been informed that the keyword syntax has to be used last. The authors of elixir have chosen to treat these things differently. The real question, I guess, is why. So rather than ask, I did some code spelunking. I still don't know, but there are some readily available hints.

One cool thing about Elixir is the Abstract Syntax Tree, and the fact that you can examine it by using `quote`.

    :::iex
    iex(9)> quote do: %{a: :b, c: :d}
    {:%{}, [], [a: :b, c: :d]}

    iex(10)> quote do: %{"a" => :b, c: :d}
    {:%{}, [], [{"a", :b}, {:c, :d}]}

Why are these things different? The first result shows that we are going to imply %{} to a keyword list, the second to a list of two item tuples. Actually, the keyword list *is* a list of two item tuples, if you quote `[{:a, :b}, {:c, :d}]`, `[a: :b, c: :d]` is what you get. To me, this looks like one piece of syntatic sugar infecting another. But once I figured out that this was what was going on, things made more sense, and it was clear that this is indeed consistent through Elixir syntax.

And while I'm still not sure what exactly is going on to create a keyword list from a list of tuples, I've had a lot of fun quoting chunks of code just to see how the compiler is going to see them. It's interesting.
