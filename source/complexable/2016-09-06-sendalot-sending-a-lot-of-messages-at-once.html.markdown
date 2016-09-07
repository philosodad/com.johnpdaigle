---
title: Sending a lot of messages with Sendalot
date: 2016-09-06 23:19 EDT
tags:
---

Some time back I needed to stress test a server, and I wrote a small tool to do it called [Sendalot](https://github.com/atlantaelixir/sendalot). Sendalot does pretty much what it says, it sends a lot of messages at once. In it's current incarnation, it is very simple, has to be run from inside IEx, and has very limited capabilities. It's still fairly useful, and I keep meaning to turn it into something more useful. For now, let's just walk through Sendalot and see how it does what it does.

Sendalot has four functions, each of which builds on the function before. The first function is:

    :::elixir
    def send_message_from_shard_to_server message,
                                          shard, 
                                          server do
      response = HTTPoison.post server,
                                message,
                                %{"#{@shard_header}": shard}
    end 

Which just sends some message to some server, with a header that identifies which shard, or process, is doing the sending. This function is called from the next:

    :::elixir
    def send_messages_from_shard_to_server messages,
                                           shard,
                                           server do
      messages
      |> Enum.each(fn(m) -> 
                     send_message_from_shard_to_server m,
                       shard,
                       server end)
    end

Which, given some enumarable data structure of messages and some some identifying shard, will call the `send_message_from_shard_to_server` method for each message.

    :::elixir
    def send_messages_from_shards_to_server messages,
                                            shards,
                                            server do
      shards
      |> Enum.map(fn(s) -> 
                  Task.async(fn -> 
                    send_messages_from_shard_to_server(messages,
                                                       s,
                                                       server) 
                             end) 
                  end)
    end

This is where the real work of the utility is. Given as inputs some enumerable of messages and some some enumerable of shards, for each shard value an asynchronous task will be created that will send each of the messages with that shard value as the identifying header.

Finally:

    :::elixir
    def send_n_messages_from_m_shards_to_server message_count,
                                                shard_count,
                                                server do
      messages = Enum.map((1..message_count),
                          fn(i) -> 
                            Integer.to_string(i) end)
      send_messages_from_shards_to_server messages,
                                          (1..shard_count),
                                          server
    end

This method will take an integer for `message_count` and `shard_count`, create a ranch for each, and use the string value of the integers as the message and shard headers.

So if you are in IEx, than

    :::elixir
    Sendalot.send_n_messages_from_m_shards_to_server(10,
                                                     5,
                                                     "localhost:2020")

Will make 50 posts to the endpoint "localhost:2020". The messages will be "1", "2", "3" etc. Each message will have a shard value ("1", "2"...) and each of these shard values will be the input to a Task, so there will be 5 concurrent streams of work going on. 

You can also define a list of real messages and call `send messages_from_shards_to_server` with the message list and a range instead of an integer for the shard ids. Using these strategies I have set Sendalot up on my laptop to have 10,000 concurrent processes sending 100 messages each. 

Which is great, but what I think I'd like to see is Sendalot as a configurable service. We'll probably work on that over the next month or so.
