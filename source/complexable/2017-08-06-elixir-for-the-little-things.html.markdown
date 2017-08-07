---
title: Elixir for the Little Things
date: 2017-08-06 11:37 EDT
tags:
---

A lot of blog posts, videos, books, and tutorials about programming Elixir tend to focus on the big things: web apps, web apps with Plug, web apps with Phoenix, web apps that need to handle 80 million concurrent requests, web apps that need to be web scale, big things. Big things are important.

But we don't exclusively write big things, sometimes we write smaller things. Sometimes, you're at work, and you're faced with a problem like "convert these 20 basically identical yaml files into 20 basically identical xml files". The question is, what tool do you reach for when that happens?

Because even if you're working in a PhP shop out in Bakersfield, you can use Elixir for scripting stuff. And it can make your life pretty good if you do. The [Sendalot](https://github.com/atlantaelixir/sendalot) tool I've talked about before is an example of this, a little script that I can open up, mess around with, and start sending hundreds of thousands of simultaneous requests from my laptop to a server. Is it pretty? No. But it gets that specific job done and we break it out from time to time.

A week or so ago, I was faced with a little scripting job where we had to take about 20 basically identical YAML files, and convert them to 20 basically identical XML files. My pair that day and I are both big fans of Elixir, so naturally we solved this with a little Elixir script.

So, obviously the first thing we needed was a library that could turn Elixir data structures into XML, or YAML into Elixir data structures, or possibly both. A quick check on Hex led to the [yaml\_elixir](https://hex.pm/packages/yaml_elixir) library, which is pretty effective at reading YAML files and turning them into Elixir maps.

    :::elixir
    def file_to_map(path) do
      File.cwd!
      |> Path.join(path)
      |> YamlElixir.read_from_file
    end

This takes a relative path (like "assets/test.yml") to a .yml file and returns a map, when run from the top level of the project. So that's the first half of the problem solved. 

Unfortunately, writing the XML was not going to be quite so simple, because a) we needed to join multiple YAML files into a single XML file, and because we only need a part of each, and the nesting of the eventual XML file is going to be slightly different than the nesting of the YAML file.

All of which leads to this code:

    :::elixir
    def get_env_entries(map) do
      get_env_entries({}, 
                      Map.get(map,
                              "env_entries"))
    end

    defp get_env_entries(acc, env_entries) do
      with false <- Enum.empty?(Map.keys(env_entries)),
           entry_name <- env_entries
                         |> Map.keys()
                         |> List.first(),
           entry_map <- create_entry(env_entries,
                                     entry_name) do
        acc
        |> Tuple.append(entry_map)
        |> get_env_entries(Map.delete(env_entries,
                                      entry_name))
      else
        _ -> acc
             |> Tuple.to_list
      end
    end

Where we are using the `with` statement in a recursive method, with the exit condition being the terminal condition of the recursion. To be honest, I didn't actually see this as a possibility until my pair pointed it out, but it makes perfect sense, the `with/do/else` control structure is just that, a control structure, so clearly we can use it as one.

In this case, `get_env_entries/1` acts as the entry point to the recursion, taking as it's argument the map produced from the original yaml file. It passes on an empty tuple (the initial accumulator), and the sub map under the `"env_entries"` key. 

This sub map is actually composed of several sub maps, and the goal of the code is to take each key and generate a flattened and transformed version of that nested map. That is what the `create_entry/2` method will do, but that code isn't terribly important. It takes a map and a key and returns a map. So, we get the first key from the `"env_entries"` sub map, and send that key and the map to the `entry_map` transformer. That map gets appended onto the accumulator, and then we make a recursive call back to `get_env_entries/2`, calling `Map.delete/2` to remove the key we just transformed. When we run out of keys, the `Enum.empty?/1` call that we make at the start of the `with` statement returns true, and we convert the Tuple into a property list and return it.

When I write it up like that, it feels sort of complicated. But the funny thing is this was developed mostly using iex, so once we had the recursive call with the delete, the empty check, and the return taken care of we were able to sort of REPL-drive the rest very quickly and easily, just filling in transforms in the middle until the correct accumulator was returned. It was fast, and it was extremely fun. 

In any case, there was obviously more to be done once we had these property lists (remember, we had two files, so there was another `get_entries` type of method) we had to turn them into XML. The tool we used for this was [xml\_builder](https://hex.pm/packages/xml_builder). 

    :::elixir
    defp generate_env_elements(env) do
      env
      |> Enum.reduce({}, 
              fn(lst, acc) -> XmlBuilder.element(:Env, lst) 
                              |> (&(Tuple.append(acc, &1))).()
              end)
      |> Tuple.to_list
    end

This code is much more my style, for better or worse. I'm a fan of the `reduce/3` function and of anonymous functions. I don't know if this is more readable than a recursive approach to this same problem, but in any case, we take the list we built in the last stage, and for each entry in the list we create an XML element tuple. The reduce returns a tuple of tuple which we convert back into a list, because for whatever reason, it seems like the XxlBuilder API takes in lists and returns tuples, except when it returns an XML string.

So, I think that in the first method we could have used `Enum.reduce/3`, but I'm not 100% positive that the internal function would have been readable, and we might have ended up with a nested with statement anyway. The second method was much more straightforward and the with statement would have been overkill. But in any case, a few hours of hacking along, 100 lines of code or so later, and we had that yak shaved and the YAML converted to XML. It definitely wasn't harder than it would have been in any other language, and I think that the control structures and functional nature of Elixir made it an excellent choice for this problem... after all, we were only transforming some data from one form into another, and that's an area where Elixir really shines.
