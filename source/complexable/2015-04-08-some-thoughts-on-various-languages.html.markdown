---
title: Some thoughts on various languages
date: 2015-04-08 19:06 EDT
tags:
---

My life as a developer is both repetitious and varied. It's repetitious in that I seem to be always solving the same problem. I write plugins and libraries for BitPay. I know how the architecture is going to lay out, what the method signatures are, return types, requirements, I know pretty much everything I need to know to write the program. My professional life tends to feel like I'm writing kata more than writing software. It's a chance to practice my basic skills, write high quality software, critique my tests from the last project and basically just get better at writing software faster.

On the other hand, this year I've written code in Ruby, Elixir, Java, Objective-C, Python, and Go. Every language I've written in has it's own packaging manager, developent ecosystem, testing framework, and style. So I thought I might take a moment to consider some toolsets for the polyglot life.

First, I can't really comment on the various IDEs. If a language seems to sort of rely on an IDE, like Java or Objective-C, I'll use the IDE that's appropriate for that language. But mostly, I use Vim. Knowing vim well feels like a superpower to me. That's probably some kind of psychological affect born of the fact that Vim has a steep learning curve, I'd hate to think that I'd invest all that energy into something that wasn't a superpower.

So since I almost always use the same editor, there's some conflict between the layout of my Python files and my Ruby files. According to the various style guides, Ruby indents by two spaces, Python indents by four spaces, and Go indents by one tab. Enter the awesome [Editorconfig](http://editorconfig.org/) plugin. For a given project, I can thrown the following text into a .editorconfig file in the root folder and my tabs will be correct for the language I'm using.

    :::yaml
    root = true
    [*.go]
    indent_style = tab
    indent_size = 2
    
    [*.py]
    indent_style = space
    indent_size = 4
    
    [*.sh]
    indent_style = space
    indent_size = 2
   
I was iffy on adding editorconfig into my workflow, and it took a surprisingly long time to get it to work in the tmux/vim configuration I use, but a little googling and a few lines in my .bash\_profile later, and everything worked fine. Haven't thought about it since, which to me is really the hallmark of a good tool. If I don't have to think about it, I'm thinking about something else.

[Cucumber](https://cukes.info/) has been another winner. It doesn't work in every language, you can't always install something that runs gherkins against feature steps. But of the languages I've worked with this year, there's a version of Cucumber for about half of them. The advantage for me is that because I'm actually solving the exact same problem, I'm able to use the same gherkin files for multiple languages, which means I can version the gherkin files and lock releases together. So regardless of language, if you are using a version of BitPay Client that is version 2.4, you know that it handles refunds. I like this, because it allows for short cards and everyone understands what the requirements are.

Actually, that's really all the generic toolkit stuff I've added. I haven't needed anything else. The languages themselves have been encouraging me to use better mental tools.

So I'll share some thoughts on the languages themselves. 

## Ruby

[Ruby](https://www.ruby-lang.org/en/) is the language I know best, and the one I've been working in the longest. I have trouble talking about Ruby in the same way that I have trouble talking about air. It's just there.

Ruby has basically everything. I've sometimes thought that Ruby has it's own version of rule 37: If you've asked "Is there a gem for that?", then there is a gem for that.

So, yeah, Ruby. Ruby is awesome.

## Elixir

[Elixir](http://elixir-lang.org/) is an absolute joy to use. For everything. I haven't gotten into a language like this since I met Ruby and Python a decade ago. Back then, I wrote almost everything in Java, and I hated it. Java was the thing that stood between me and what I wanted to accomplish. Ruby and Python changed that, they became the tools that I could use to write code. I used them in any class that didn't actually require that I use C.

Elixir has that sort of affect on me. I want to use it for everything. Here's the thing about Elixir... lets say you pass a struct into a function. Let's say you didn't write the function. You know, for a fact, that unless you explicitly use the return value of that function to change a attribute of that struct, that struct won't change.

It took me a long time to realize that this was what immutable meant. It doesn't mean that I can't bind a variable to a different value, it means that I have to be the one who binds a variable to a different value. It won't ever just happen to me somewhere else, in a mysterious tangle of code that's been maintained by mad priests for decades. Contrast this with, say, working with openssl, and you'll sort of see what I mean.

On the other hand, Elixir does not have a cucumber library, and the webdrivers aren't as mature as they are in other languages. So for testing, it's got some shortcomings. But it has an awesome set of libraries for just about everything else, because it inherits the entire Erlang ecosystem. It has a great build/dependency management tool in mix, a simple package manager with [hex](https://hex.pm/), it's fast, it's wicked, and has great syntax and appears to defy the laws of physics.

I've posted before about using the [Erlang libraries with Elixir](http://www.johnpdaigle.com/complexable/2014/12/22/from-keys-to-pem-in-elixir.html) and comparing [Elixir to Ruby](http://www.johnpdaigle.com/complexable/2014/12/30/translating-ruby-to-elixir.html).

## Python

I actually wrote two [Python](https://www.python.org/) libraries, one for Python 2.x and one for 3.x, because the code for making a two version solution is so very ugly. So that's a downside to working in Python. I think that overall that's becoming less of a problem over time, and most of the libraries that I wanted to use were available for both. I was able to reuse about 90% of my code and use the same requirements.txt file for handling dependencies.

For functional testing, the bug bear of most projects, Python was as easy to use as Ruby. The [Behave](http://pythonhosted.org/behave/) library is slick, well documented, easy to use and about as close to Capybara as anything I've seen outside of Ruby. Building step definitions, etc. was a breeze. The core code pretty much wrote itself.

Dependency management with [Pip](https://pip.pypa.io/en/stable/) was pretty simple, finding documentation was easy, and deploying via [PyPi](https://pypi.python.org/pypi) is about as simple as working with Rubygems. If you aren't used to Python, Peter Downs has written a [simple guide](http://peterdowns.com/posts/first-time-with-pypi.html) to deploying with Pip that was invaluable to me.

## Android

I don't want to talk about it.

## Go

It took me a long time to get this code working in [Go](http://golang.org/), a couple of weeks. A lot of that was just figuring out how to structure a project in Go, finding test libraries, realizing that the test libraries didn't work the way I wanted them to, and deploying.

The biggest problem for me is that Go does not have a REPL. If you are used to having an interactive interpreter available, working without one is like working without a limb. It's really hard to narrow down what any given value is at a specific point. If I had used a better IDE, or maybe learned to use the debugger, this probably would have been a lot easier for me, but I didn't, so I suffered a good bit and wrote a lot of useless print statements.

That isn't really Go's fault, though, so lets talk positives. Go is pretty simple, there aren't a lot of things to learn to get started. It has a lot in common with C, but doesn't make you collect your own garbage and has a sort of tenuous Objecty thing going on with defining methods that is actually sort of nice. So in Go, you can write something like this:

    :::go
    type Client struct {
      Pem      string
      ApiUri   string
      Insecure bool
      ClientId string
      Token    Token
    }
    func (client *Client) GetInvoice(invId string) 
                        (inv invoice, err error) {
      url := client.ApiUri + "/invoices/" + invId
      htclient := setHttpClient(client)
      response, _ := htclient.Get(url)
      inv, err = processInvoice(response)
      return inv, err
    }
	  client := new(Client)
    clinet.GetInvoice("astring")

Which sort of looks like OO, but is really syntatic sugar for a fairly common patter in C. In C, I would create an empty `invoice` struct, and pass both it and the client in as pointer arguments, with the error as the return value. The Go convention is a lot clearer about which struct is holding the data, which one is the return value, and passes the error if something goes wrong.

Package management in Go is pretty much just github or bitbucket or whatever repository you're using. That's okay, but it does lead to some weirdness about how you structure your development environment versus your deployment repository. There aren't really any established best practices that I could find.

Testing was a weakness, specifically webdrivers. WebDriving in Go was weak enough that I actually ended up using a python script instead and reading the needed values from files. Since I'm only using an API, not building a web site, that was acceptable. I think that if I actually were building a web site I'd end up having a worse problem.

The library I ended up using for most of my testing was [Ginkgo](http://onsi.github.io/ginkgo/), which wasn't hard to learn and had all the matchers and syntatic sugar that I would expect from a modern testing library.

## Conclusions

I'm a fan of Elixir, and it is my favorite out of these languages. That said, Python was the easiest for me to develop in other than Ruby, partly because I've written more code in Python, but partly because if you are used to a dynamically typed, object oriented language, Python holds very few surprises. 

Go was the greatest struggle, but a lot of that was me fighting the uptight Go compiler and trying to understand the idioms of the language. Once the code was written, it felt readable and clean, and I'm very confident in it.

I've had a lot of fun working in a lot of languages this year, and I highly recommend this as an experience. If you have some non-trivial but small problem that you know well, there are a lot worse things you can do with your time than build it in different languages, and these specific languages are pretty good choices for variety in writing style and tooling.

