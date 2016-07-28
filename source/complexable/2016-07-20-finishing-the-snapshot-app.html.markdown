---
title: Finishing the Snapshot App
date: 2016-07-20 23:28 EDT
tags:
---

In the last post, we started work on a simple application using Travis and Ecto. Our goal was to get an app that deployed through Travis to Heroku, containing a single post endpoint and a single get endpoint and employing a fairly primitive authorization scheme. What we have so far:

* Deployment through Travis to Heroku
* Primitive Authentication
* 404 responses to bad requests
* A schema that includes the **jsonb** datatype

So, what's next? We're starting on [revision 04](https://github.com/philosodad/snapshots/tree/r04), which has the schema but doesn't have any way to retrieve or post data to the schema. Where I'm going to start is with a `get` endpoint. This will test whether I am actually connected to the database and have run my migrations before I worry about putting anything in the database, so it seems a little simpler to me.

So we start with a route. I've decided that I'm not going to have the route do any work, it will put the burden of finding the record to return on the view (which I suppose makes the view more of a view-model). I'm not trying to build a nice MVC architecture, just to get something that works, so the route in `server.ex` looks like this:

    :::elixir
    get "/snapshot/:id" do
      case Snapshots.SnapshotView.return_snapshot id do
        {:error, message} -> send_resp(conn, 404, message)
        {:ok, snapshot} -> send_resp(conn, 200, snapshot)
      end
    end

It expects a SnapshotsView module with a `.return_snapshot/1` function.

    :::elixir
    def return_snapshot guid do
      case Snapshots.Repo.get_by(Snapshot, guid: guid) do
        nil -> {:error, 
          Poison.encode!(
            %{error: "No resource found for id: #{guid}"}
          )}
        snapshot -> {:ok, build_snapshot_view(snapshot)}
      end
    end

    defp build_snapshot_view snapshot do
      %{
        href: "#{Sets.snapshots_url}/snapshot/#{snapshot.guid}",
        snapshot: snapshot.message
      }
      |> Poison.encode!
    end

Testing this locally, it works, so I push it to Travis, and it fails to deploy to Heroku. This is because we haven't created or migrated our databases yet. In the terminal:

    :::bash
    $ heroku run mix ecto.create
    $ heroku run mix ecto.migrate

The `ecto.create` command throws a lot of errors, [but apparently we can ignore them all](http://wsmoak.net/2015/07/12/phoenix-and-ecto-from-mix-new-to-heroku.html). Now if we rerun our build, we should be able to call the `snapshots/:id` endpoint on our Heroku server and get back the 404 message. This tells me that I am not throwing any database errors when I look for a Snapshot in the database, which is basically what I'm looking for. The code up to this point is tagged as [r05](https://github.com/philosodad/snapshots/tree/r05).

Next we want to be able to add a new record. As a reminder, the idea of this application is to store snapshots of a business object. So the reference application is going to generate the guid for the snapshot and send it as a header. What I want to do then is to take the JSON body of the post and the headers of the request and combine them into a map, which I'll pass over to the schema to handle verification, saving, and error handling. We'll start in the schema, with a `create/1` method that takes a map.

This is the part of the day where my process went completely off of the rails, and I spent a very long time messing with Ecto.Changeset. I'll say this: I'm almost positive that there was an elegant way to change around some of the error messages and end up with a very slick solution. I did not discover that solution, but I'mnot entirely unhappy wiht the solution I did find. Here's the code for the `Snapshot.create/1` function, although without any handling for the happy path.

    :::elixir
    def create map do
      params = %{"x-guid" => :guid,
                  "body" => :message,
                  "x-ref-guid" => :ref_guid
               }
               |> Enum.reduce(%{},
                  fn({key, value}, acc) -> 
                    Map.put(acc, value,
                            Map.get(map, key)) end)
      changes = changeset %Snapshots.Snapshot{}, params
      case changes.valid? do
        true -> {:ok, "ok"}
        false -> {:error, error_from_changeset(changes)}
      end  
    end

The goal of the first expression is to create a mapping between the headers being sent and the schema fields, essentially, we want to one map that is being passed in and convert the keys to our desired values. Then we create an Ecto.Changeset:

    :::elixir
    def changeset snapshot, params do
      cast(snapshot, params, [:message, :guid, :ref_guid])
      |> validate_required([:message, :guid, :ref_guid])
    end

Which validates that the fields we need are present. Then we check the validity of the changeset with `changes.valid?`, and if it isn't we call the `error_from_changeset/1` function:

    :::elixir
    defp error_from_changeset(changes) do
      %{
        guid: "No x-guid header found",
        ref_guid: "No x-ref-guid header found",
        message: "No snapshot found"
      }
      |> Enum.filter_map(
                          fn({key, _value}) -> 
                            List.keymember?(changes.errors,
                            key,
                            0) 
                          end,
                          fn({_key, value}) -> 
                            value 
                          end
                        )
      |> Enum.join(",")
    end

An Ecto.Changeset struct has a number of attributes, including a list of all errors in the format `[key: {"string", []}, ... keyn: {"string", []}]`. We create a key with error messages and then use the `filter_map/3` method to compare our existing errors to that list and extract the appropriate error messages, which are then joined to a single string.

At this point, if we send a bad request. Unfortunately, there's no way to send a bad request because we haven't wired up our controller to the model yet. Since the model doesn't actually have a success case, we'll rewrite our controller to always fail:

    :::elixir
    post "/snapshot" do
      case Snapshots.Snapshot.create(%{}) do
        {:error, message} -> send_resp(conn, 400, message)
        {:ok, message} -> send_resp(conn, 204, "")
      end
    end

That builds and deploys, and returns the error messages we built. That's a reasonable checkpoint, so I'm going to [tag and release](https://github.com/philosodad/snapshots/tree/r06) the code up to this point and finish the post route next time.
