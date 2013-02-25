---
title: "Going Bowling, Scala Style"
date: 2013-01-18 06:05 -05:00
tags: TDD, Scala, Snippets
---

Among my many goals this year is to learn more Scala, by which I mean, learn any Scala. I took the first chunk of Martin Odersky's [Functional Programming in Scala](https://www.coursera.org/course/progfun) coursera in the fall before circumstances intervened, and I liked what I saw. Scala seems to be worth learning, familiar enough to be easy to learn but introducing enough new material to change how I program.

Sidenote--I also wrote a novel in the fall. Having too many goals is worse than having too few--right now, in addition to trying to learn Scala, I'm trying to learn Calculus and Game Theory. Note to self: have fewer projects.

This blog is also a project, and I haven't updated it in three months. So this is sort of a theme, the more stuff I take on, the less stuff I get done. I'm sure there's a way to write that as a Taylor Expansion, but that's another blog post.

This blog post is about Kata.

What I thought we be a fairly trivial first stab at Scala was the [bowling game kata](http://butunclebob.com/ArticleS.UncleBob.TheBowlingGameKata), as introduced by Uncle Bob Martin. Essentially, the bowling game kata takes some series of numbers and sums them as if they represented a complete bowling game. I won't explain the rules of bowling here, if you are interested, wikipedia has a comprehensive article on [ten pin bowling](http://en.wikipedia.org/wiki/Ten-pin_bowling).

This is a TDD Kata, the first test should capture the gutter game, the second test the game where one pin is knocked down, the third test when you have one spare, the fourth test for one strike, and the last test for a perfect game.

In order to run this Kata, I had to first set up a Scala project. I decided to use SBT to do this, and luckily, a fairly short web search found a [step-by-step guide](http://www.paulbutcher.com/2011/09/scala-2-9-1-sbt-0-10-and-scalatest-step-by-step/) to setting up a simple Scala project using scalatest with sbt. 

So I built a `build.sbt` file that contained the following:

    :::scala
    name := "Bowling"
    
    version := "0.1"
    
    scalaVersion := "2.9.1"
    
    libraryDependencies ++= Seq(
      "org.scalatest" %% "scalatest" % "1.6.1" % "test"
      )

And a directory structure and some files to go with it,

    - scala-bowl
      - src
        - main
          - scala
            - Score.scala
        - test
          - scala
            - ScoreTest.scala

Once that was set up, I followed Uncle Bob's advice and wrote and passed his five tests, progressively adding bits of functionality as prescribed. Because my solution was recursive and a bit funky, it took a little bit of tweaking, but eventually it was done.

When I was done doing the kata in Scala, I decided to do the kata in Ruby, which meant that my first step was to create a new folder in my "bowling" folder to hold the project, then create an rvmrc file in that folder to set the ruby version (`rvm --rvmrc --create 1.9.3-p125`). Because I used [minitest](http://docs.seattlerb.org/minitest/MiniTest.html) as my testing framework, I didn't need to import any gems, but because this was a ruby project I did create a folder structure, specifically

    - ruby-bowl
      - src
        - game.rb
      - test
        - game_spec.rb

And then, of course, I needed to add the magic at the top of my test file to allow access to game.rb, 

    :::ruby
    $:.unshift File.join(File.dirname(__FILE__),'..','src')

    require 'game'
    require 'minitest/autorun'
   
And then I was ready to start my kata.

In other words, just like the Scala kata, I needed to *sweep the floor* before I started work. That is, I had to take the time to set up my environment.

Sweeping the floor is one of the little considered skills of TDD, but it's crucial to your practice that you can set things up quickly. Tools like rvm, Maven, and sbt insure that your environment is clean, that your kata doesn't have any external dependencies.
