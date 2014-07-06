---
title: That took longer than I thought it would...
date: 2014-07-06 14:19 EDT
tags:
---

I'm sitting in the Java-Vino coffee shop in the Virginia Highlands, writing a blog post.

Of course, I couldn't just *write* a blog post, that would be silly. First, I needed to set up this laptop to even be able to write blog posts, which involved installing a ruby distribution and running bundler, because I haven't installed middleman on this laptop before. So that took longer than I thought it would, and now I've forgotten what it was that I was going to write about when I sat down here to write something.

Which I guess is as good a topic as any: context loss. If I had realized that I was about to spend a lot of time reading blog posts while my computer installed stuff, I probably would have written myself a note on one of the 3 notebooks I carry everywhere I go, something like "blog post: how US China relations are like waterfall project" and then I would have the seed there to write a blog post that would **blow your mind**.

Sadly, I didn't do that. And I lost my context. And that's that for that, right? Whatever brilliant idea I had that I thought was worth the trouble of getting this computer set up to run this software is lost forever.

Looking at my notebooks, though, I've noticed that my daily notes are getting a lot less interesting these days, by which I mean that they are more like meeting logs than like troubleshooting or development guides. Which could mean that I'm going to more meetings these days (that's certainly true), or it could mean that I've become a note taking slacker because I feel really comfortable at work. And I think it's more the latter than the former: I'm not planning development in the short term the way I used to. Part of that is because I'm more senior and I'm expecting the junior programmer to take notes, and part of that is just slack.

Looking at the former case, though, it is true that I'm more often the senior member of the pair these days, with all the turnover we've had at DealerMatch, there aren't many programmers on the web team who have been there longer than I have, even though I've only been there for a year. Which means the turnover in our industry is *insane*, but we all already knew that. Anyway, the senior guy is usually not the note taker and the keeper of the context, for a couple of reasons. The most important reason to any junior programmers out there is that, especially when you are new to the code base, you want to be useful from day one. And one way to be useful is just to take notes. Let's say you have to add a new functionality to a web page using a front end web framework backed by rails. The button does some alteration to a specific model, maybe we're allowing our users to alter their profile in some way. Your notes might just read:

1. field to model (data migration?)
1. set endpoint to controller (users controller)
1. return value to view (rabl)
1. push back-end changes
1. front end stuff

Why is the front end stuff left so vague? Because at this point, you might not have a good idea about how that will be accomplished, or you and your pair may have decided to leave that for later, so there's no real hurry to figure it out now. The key thing is that at each step, you can add more details about what needs to be done, and if there is an interruption, you can put a note in about where you were and what needs to be done next, and that's useful. It's also very helpful to you as a developer on this team, because you are learning a way to approach this specific problem. Maybe it isn't the best approach, and the next person you pair with will have a different approach, but it's a plan of attack and that's a good thing to have.

It's helpful to have a plan of attack when you're dealing with an inveterate yak shaver as well. Just the innocuous question "how does this fit into the plan?" might be enough to get back on track. 

Write stuff down. It helps.
