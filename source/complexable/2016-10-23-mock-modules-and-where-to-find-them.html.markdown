---
title: Mock Modules and Where to Find Them
date: 2016-10-23 06:59 EDT
tags:
---

Coming from Ruby into Elixir has it's pitfalls. One thing that comes up a lot for TDD folks like myself is how to mock. I've found that this isn't as important in Elixir as it is in Ruby, but there are still a few cases, especially ones where there is a dependency on a third party service, that it is just inevitable. 

There are number of good articles on how to work with mocks in Elixir, and how to mock in Elixir. In this article, I want to look at two strategies for mocking a call to an HTTP server. To do this we'll work with the [Sendalot](https://github.com/philosodad/sendalot) tool that I've been meaning to turn into a service for a while now, but we won't be adding any functionality to it.

Sendalot is something I built as a mock service itself. At work, we process messages off a queue, and those messages have shard\_ids. It is important that we process messages with the same shard\_id in order, but not important that we process messages from different shards in any time based order. So Sendalot mocks the situation of sending many messages with different shard headers to some endpoint. At the moment it is pretty primitive.

So the thing we have to mock is the actual sending of the message, because we want to test whether or not we are sending what we expect to send in the order we expect to send it. In the code, there is a function

    :::elixir
    def send_message_from_shard_to_server message,
                                          shard,
                                          server do
      HTTPoison.post server,
                     message,
                     %{"#{@shard_header}": shard}
    end      

That handles the actual sending of the message, and all I really care about in testing it is that I'm sending the expected header as part of an HTTP request. In Ruby I might write something like `expect(HTTPoison).to receive(:post).with(...)` and that would be that. And in fact you can do that sort of mocking using the [Mock](https://hex.pm/packages/mock) library.

This is not the [recommended pattern](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/) to follow in Elixir for a couple of reasons, one of which is that it binds you to the HTTPoison library. Two alternatives are to create a test server and to abstract the HTTP library. Let's have a look at both.

### Creating a Test Server

In the `send_message_from_shard_to_server` function, the server is one of the arguments passed into the function. That makes it easy to create and use a test server. We start with a file `test/test_server.exs` 

    :::elixir
    defmodule TestServer do
      use Plug.Router
      require IEx

      plug :match
      plug :dispatch

      @port Application.get_env(:sendalot,
                                Sendalot)[:test_server_port]
      @host Application.get_env(:sendalot,
                                Sendalot)[:test_server_host]

      post _ do
        sender = Map.new(conn.req_headers)["senderid"]
        {:ok, message, _conn} = Plug.Conn.read_body(conn)
        update_messages_for sender, message
        test_store = Agent.get(:test_server, 
                               fn store -> store end)
        send_resp(conn,
                  200,
                  "Message: #{message} from #{sender}")
      end

      def start do
        Plug.Adapters.Cowboy.http TestServer, 
                                  [],
                                  port: @port,
                                  ref: :test_server
        Agent.start_link(fn -> Map.new end,
                                       name: :test_server)
      end

      def stop do
        Plug.Adapters.Cowboy.shutdown :test_server
      end

      def port, do: @port
      def host, do: @host
      
      defp update_messages_for sender, message do
        store = Agent.get(:test_server,
                          fn store -> store end)
        messages = Map.get(store, sender)
                   |> update_messages(message)
        Agent.update(:test_server,
                      fn stor -> Map.put(stor,
                                         sender,
                                         messages) 
                      end)
      end

      defp update_messages nil, message do
        [message]
      end
      defp update_messages messages, message do
        messages ++ [message]
      end
    end
     
`TestServer.start` starts the server and an Agent, which we can use to store what calls were made. In the `test_helper.exs` file we add a line to load the TestServer:

    :::elixir
    Code.require_file("test_server.exs", "./test")

And in each test file that requires the server:

    :::elixir
    setup do
      TestServer.start
      :ok
    end
    
And then we can query the Agent to find out what we sent to the server. Creating a fake server works well in situations like this one, where we don't have a real service that we need to test compatibility with.

The other pattern we'll look at is creating a module that encapsulates the message sending behavior, and then mocking that module.

### Mocking Module

We'll build with a very simple encapsulation, so simple, in fact, that it only passes all requests through to the `HTTPoison.Base` module. There are tests around this functionality, of course, so we'll be able to keep everything working (or breaking when expected.

The first change I want to make is to the Sendalot module itself, to replace usage of the HTTPoison library. So before, where the `send_message_from_shard_to_server` method was:

    :::elixir  
    def send_message_from_shard_to_server message,
                                          shard, 
                                          server do
      HTTPoison.post server,
                     message,
                     %{"#{@shard_header}": shard}
    end 

Now we'll replace the call to HTTPoison with a call to @http, which we'll define as a module attribute:

    :::elixir
    @http Application.get_env(:sendalot, Sendalot)[:http]

And then in config.exs:

    :::elixir
    config :sendalot, Sendalot, http: Sendalot.Http

And then we define a module to encapsulate HTTPoision:

    :::elixir
    defmodule Sendalot.Http do
      use HTTPoison.Base
    end

If we've done all this right, all of our tests should pass. We haven't done much of anything, but there is some groundwork we're laying. For one thing, we've decoupled the Sendalot code from the HTTPoison module. If we start to want to handle more protocols, or have more complicated logic around setting headers or using JSON, we've got a place to put it.

One of our motives for doing this in the first place was to create a module for testing. And of course we can, by adding another module:

    :::elixir
    defmodule Sendalot.TestHttp do
      use HTTPoison.Base
    end

And changing the `config/test.exs` file:

    :::elixir
    config :sendalot, Sendalot, http: Sendalot.TestHttp

And the tests will still pass. But this doesn't smell very good, because the `test_http.ex` file is sitting in our `lib` directory, so this piece of test code is going to become part of our production code. This is probably a dreadful idea, so we should move it into the test folder. If we do, it won't compile, because the project options default to only compiling `lib/`.\* 

Elixir's compile paths are set by an `elixirc_paths` option in the `project` section of the `mix.exs` file. We want to set that option explicitly:

    :::elixir
    def project do
      [app: :sendalot,
       version: "0.0.1",
       elixir: "~> 1.2",
       build_embedded: Mix.env == :prod,
       start_permanent: Mix.env == :prod,
       elixirc_paths: elixirc_paths(Mix.env),
       deps: deps]
    end

And define two private functions in the `mix.exs` file:

    :::elixir
    defp elixirc_paths(:test) do
      ["lib", "test/support"]
    end
    defp elixirc_paths(_), do: ["lib"]

And now we can move the test version of the http module out of the production code, and into the `test/support` folder, all the tests will pass and we can do additional mocking in this file. We'll look at how to use this mock module in another post.

\* Hat tip to @benwilson512 on the excellent elxirlang slack channel for explaining this to me in the first place.
