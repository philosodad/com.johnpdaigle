---
title: TDD Is Alive and Well and Living in New Jersey
date: 2014-05-17 22:32 -04:00
tags:
---

Actually, it's living in my heart, but I was born in New Jersey.

Don't tell anybody.

In a recent blog post, DHH, the creator of Ruby on Rails, claimed that TDD was dead. There were plenty of reasons why he said so and they have been pretty meticulously picked over by the community, so I don't want to reiterate them here. What I would like to focus on is one small point. According to DHH, it is difficult to write good unit tests in Rails. And he himself doesn't use TDD, because he doesn't enjoy it, because it's hard to write good tests in Rails.

Now, I don't actually agree with DHH on this. I find it pretty easy to write tests in Rails, I do it all day, every day. I keep my unit tests pretty pure, but I also write functional tests and integration tests because I need to know how objects interact and that the system is functioning. And I do think that sometimes, my team could skip some tests that we write.

But they aren't hard to write, or hard to run. Where they are hard to write, it is because we're doing something wrong, and need to do it differently, or someone wrote code without writing tests first. Which leads me to the following conjecture: 

*DHH finds it hard to write tests in Rails because he does not write his tests first, and therefore has written software that is difficult to test.*

In other words, he's confused the effect with the cause.
