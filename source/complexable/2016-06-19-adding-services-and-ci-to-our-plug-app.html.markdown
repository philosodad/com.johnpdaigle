---
title: Adding services and CI to our Plug App
date: 2016-06-19 11:43 EDT
tags:
---

In the [previous post](http://www.johnpdaigle.com/complexable/2016/06/12/deploying-a-plug-application-to-heroku.html) we deployed a Plug.Router application to Heroku. In this post, we'll add some services to help us understand how our app is behaving, and we'll also get our app deploying directly from our CI server.

There are plenty of instructions online for doing this. I went the easiest way I could, which was to first create the most basic .travis.yml file I could:

    :::yaml
    language: elixir
    elixir:
    - 1.2.2
    otp_release:
    - 18.2.1

Then install and run the travis CLI:

    :::bash
    $ gem install travis
    $ travis setup heroku

Which added a deploy section to my travis file with the secure api key, etc. 

Which was all I needed to deploy this application to Heroku from travis. If you check out the [application code](https://github.com/philosodad/ping_and_log/tree/v0.0.4) at this point, you'll probably also notice some changes where I've added a supervisor, but otherwise the code hasn't changed much. With a couple of minor additions we can easily add coveralls, so that the code builds, runs coveralls, and deploys if successful.

So now we have continuous deployment of our app, although it doesn't do a whole lot. Let's take a moment to reflect that this was incredibly easy to do. We are devops heroes.
