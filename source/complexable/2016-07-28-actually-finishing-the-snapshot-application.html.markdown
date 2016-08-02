---
title: Actually Finishing the Snapshot Application
date: 2016-07-28 10:23 EDT
tags:
---

In [the last post](http://www.johnpdaigle.com/complexable/2016/07/20/finishing-the-snapshot-app.html) we moved forward on the snapshot application. At this point, it will (probably) return some json from the database, return error messages for bad get requests, and return error messages for every post request. What we still can't do is post data and store it.

We're starting with the code at [revision 6](https://github.com/philosodad/snapshots/tree/r06). Again, we'll have two parts to take care of, the schema and the route. Our interface for the schema expects a map with three keys, "x-guid", "x-ref-guid', and "body". We translated these fields into our three schema fields, "guid", "ref\_guid", and "message", when we did the error handling in the last post. Our create method looks like this:

    :::elixir
    def create map do
      params = %{"x-guid" => :guid,
                 "body" => :message,
                 "x-ref-guid" => :ref_guid}
               |> Enum.reduce(%{},
                              fn({key, value}, acc) ->
                                Map.put(acc,
                                        value,
                                        Map.get(map, key))
                              end
                              )
      changes = changeset %Snapshots.Snapshot{}, params
      case changes.valid? do
        true -> {:ok, "ok"}
        false -> {:error, error_from_changeset(changes)}
      end
    end

What we have to is insert the changes into the database. This turns out to be a 3 line change:

    :::elixir
    def create map do
      params = %{"x-guid" => :guid,
                 "body" => :message,
                 "x-ref-guid" => :ref_guid}
               |> Enum.reduce(%{},
                              fn({key, value}, acc) ->
                                Map.put(acc,
                                        value,
                                        Map.get(map, key))
                              end
                              )
      changes = changeset %Snapshots.Snapshot{}, params
      case Snapshots.Repo.insert(changes) do
        {:ok, _message} -> {:ok, "ok"}
        {:error, _errors} -> {:error, error_from_changeset(changes)}
      end
    end

So now we're applying the changes, if we call this method with a valid map, we will insert a valid changeset into the Repo. 

Now the question is: what do we want to return from this method? Our api returns a 204, with the href for the created resource in a header. So I think the best thing would be to return nothing. The route already has the guid for this resource, probably we should just turn the question of building the URL over to the route or a view.

Next we want to set the route so that it calls the schema with the right arguments. As you recall, two of the arguments we want are in headers, and one is the body of the message. Our route ends up looking like this:


    :::elixir
    post "/snapshot" do
      params = pull_headers(conn)
      |> Map.merge(conn.params)
      case Snapshots.Snapshot.create(params) do
        {:error, message} -> send_resp(conn, 400, message)
        {:ok, message} -> send_resp(conn, 204, "")
      end
    end

We're going to pull the headers out into a map, then merge them with the params, then call the create function with those params. We're getting the params by adding a plug:

    
    :::elixir
    plug Plug.Parsers, parsers: [:json, :urlencoded],
                    json_decoder: Poison

Between the :authorize and :match plugs. Pulling out the headers isn't particularly pretty:

    :::elixir
    defp pull_headers conn do
      ["x-guid", "x-ref-guid"]
      |> Enum.reduce(%{}, 
                     fn(header, acc) ->
                       case Plug.Conn.get_req_header(conn, 
                                                     header) 
                       do
                         [] -> acc
                         [value] -> Map.put(acc, header, value)
                       end
                     end
                    )
    end

But it works, the `pull_headers` function will return a map with the desired headers and their values included. So now we can post a snapshot and retrieve it from the database. The code deploys with a git push, after running tests on Travis and checking test coverage on Coveralls. Here's the [current state of the code on github](https://github.com/philosodad/snapshots/tree/r07).
