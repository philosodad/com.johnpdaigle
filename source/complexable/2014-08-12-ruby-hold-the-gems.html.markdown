---
title: Ruby, Hold the Gems
date: 2014-08-12 07:21 EDT
tags:
---

I spent most of the weekend writing Ruby, which is a little unusual for me. I write Ruby all week, of course, but what I really write is Rails. The difference is that at work, we don't really solve our own problems if we don't have to. If there's a gem for it, we use it. So if we want a factory that builds objects for us, we import FactoryGirl.

I didn't really need a factory, but I didn't really have any idea how to build a generic factory. I've also sort of gotten used to using Factories, especially in my test code. So I wrote a very rudimentary generic factory as I went.

    :::ruby
    class Factory
      class << self
        def create type, opts={}
          klass = constantize(type)
          if klass.instance_method(:initialize)
                  .parameters.empty?
            klass.new
          else
            klass.new(opts)
          end
        end
        def constantize type
          const_get(type.to_s
                        .split("_")
                        .map(&:capitalize)
                        .join.to_sym)
        end
      end
    end

This is not very sophisticated, but it is a start. It at least points in a direction of where I might want to go, and if I hand it something like `Factory.create(:foo)`, I will get an instance of `Foo` back. That constantize method came in handy later as well.

Normally, if I want mocks or stubs, I use a mocking library of some kind. At work we've been using Mocha, but I was working on writing without any gems outside of core so that was right out. So what to do?

One of the main reasons to use mock objects in a test is so that you can define what return value you will get from an objects collaborators. In my case, there was a certain amount of random behavior in my code (it's a simulator) and a lot of objects don't have direct accessors for attributes. I ended up resorting to things like this:

    :::ruby
    trader_list = Factory.create(:trader_list)
    def trader_list.traders= traders  
      @traders = traders
    end

Which creates a new singleton method in this instance of `TraderList`, allowing me to set up some data for my test. Probably, this would be something worth adding to the Factory so I can take it out of my tests, but I'm not there yet.

Of course, MiniTest does allow mocking and stubbing, and MiniTest is core Ruby. The point wasn't that I absolutely had to do this, it was to do it. I wanted to spend some time with Ruby, not with all of her jewelry, if that makes sense. The core language gives us so much, and we really don't spend a lot of time with it in everyday work.

Which makes sense: when I'm building something for money, if there's a quicker way to use code that has been tested by thousands of people in thousands of projects to accomplish a goal, it's downright irresponsible not to use it. Gems are a *good* thing, they make my life much easier. But the only way to have an idea how they work is to spend some time building that functionality yourself.

Overall, I'm pretty happy with the code I'm writing so far. Feel free to check out my [trading_network](https://github.com/philosodad/trading_network). One thing I haven't done, but really need to do, is to write a method that allows me to do some universal setup before each example in my tests.
