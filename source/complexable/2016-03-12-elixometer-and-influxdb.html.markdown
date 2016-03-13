---
title: Elixometer and InfluxDB
date: 2016-03-12 23:26 EST
tags:
---

[Last time](http://www.johnpdaigle.com/complexable/2016/03/05/resetting-a-test-database-with-ecto.html), we took the simple [Loggex](https://github.com/philosodad/loggex/) application that we wrote and made some changes to separate the test database from the development database. Eventually we'll also want to put this app into production, but before we do let's add some metrics. What we want to be able to do is to measure how many requests per second the app is handling at a given time. In order to do this we're going to use two new technologies, a time series database called [InfluxDB](https://influxdata.com/) and [Elixometer](https://github.com/pinterest/elixometer), which is a light wrapper around an Erlang library called [Exometer](https://github.com/Feuerlabs/exometer).

So, first, you'll want to install InfluxDB, which is pretty easy to do, and you'll also want to install the Chronograf tool so that you can create a dashboard to view your metrics with.

How to do this is a little outside the scope of this blog post, but if you are on a mac or linux machine this is really just a matter of picking these things up from your package manager of choice.

When you have them installed and running you should be able to see their dashboards at 8083 for InfluxDB and 10000 for Chronograf.

Assuming you have that, let's add our libraries. The first one we'll add is a slightly customized version of elixometer from atlantaelixir, that contains several reporters that aren't in the basic build. We add this to the mix.exs file, in the `deps` function:

    :::elixir
    defp deps do
    [
      ... 
      {:elixometer, github: "atlantaelixir/elixometer",
        override: true}
      ...
    ]
    end

Also add `:elixometer` to the `:applications` list in the `application` function.

Now we want to add and configure the exometer influxdb reporter itself. This is done in the environment config file. In this case, we are probably going to use a different reporter in production, so we'll add the configuration to the `config/dev.exs` file:

    :::elixir
    config( :exometer, report: 
       [reporters: [{:exometer_report_influxdb, [
         protocol: :http,
         port: 8086,
         host: "localhost",
         db: "exometer",
         tags: ["loggex"]
       ]}]])
 
     config(:exometer, :subscriptions, [
                    {:exometer_report_influxdb,
                     [:erlang, :memory], 
                     :total, 5000, true, []
                    },
                   ]
                  )

     config(:elixometer, 
            reporter: :exometer_report_influxdb,
            env: Mix.env, 
            metric_prefix: "loggex") 

Now we just have to add some metrics to the code itself. We want to capture the requests per second being handled by our logging application, so we'll add the metric to the endpoint function in `loggex.ex`. Also, we need to add `use Elixometer` to the top of the file.

    :::elixir 
    update_spiral("loggex.count.pps", 
                  1, 
                  time_span: :timer.seconds(1),
                  slot_period: 1000)

This is a spiral metric, which counts up and the resets repeatedly. In this case, it will reset every second.

If we send data to influx right now, it won't work, because we haven't created the `exometer` database in influx. Assuming you've installed influx correctly, you should be able enter the influx shell and create a database.

    :::bash
    $ influx
    Connected to http://localhost:8086 version 0.10.1
    InfluxDB shell 0.10.1
    > create database exometer
    > show databases
    name: databases
    ---------------
    name
    _internal
    exometer

Now, I just need to send some data to the logger. To do this, I'm hacking a tool I wrote called [sendalot](https://github.com/atlantaelixir/sendalot) to send to this particular endpoint. And of course we'll have to start the Loggex application, which we're still doing from inside iex.

    :::bash
    $ iex -S mix
    iex> Loggex.start

Then, after we send messages to the `log` endpoint of the app, we'll see our new measurement in the influx ci or web tool:

    :::bash
    > use exometer
    Using database exometer
    > show measurements
    name: measurements
    ------------------
    name
    loggex_dev_spirals_loggex_count_pps
 
And that's basically it. Right now, our app is, on my machine at least, handling about 4000 posts a second according to this metric. I'll leave it to you to figure out how to display this metric in Chronograf. There wasn't much code for this post, so there's only one commit. [[s8](https://github.com/philosodad/loggex/tree/s8)]
    
