---
title: It's not delivery...
date: 2013-03-31 18:16 -05:00
tags:
---

I've been coaching in an enterprise for a while now, I guess about a year. And every group that I coach says the same thing, they say that they, unlike everyone else, deliver on time.

Yep, it's those other groups that didn't deliver on time, they say, and that's why the place is in the situation that it's in. The situation isn't pretty, but this group, the group I'm talking to, they delivered. 

Sure, sure, there are some bugs. Some of them are integration bugs, and if they are, they are a result of the other group being late. But this group, the group that's talking, they delivered. On time. Yeah, I mean, maybe not all the bugs are integration bugs. And maybe there were some missed requirements, but whose fault is that? If the Business had been clearer, this group, the group I'm talking to, this group would have delivered. On time and under budget. If they had known all the requirements. 

Well, yeah. Some of the defects are code defects that are undeniably in the code base that this group built. But you can't expect them to pick up everything, some defects are going to happen. That's why there is a QA cycle, anyway. And sure, the original QA cycle is overdue, but this group delivered software, damnit. On time, under budget, functionish software. They delivered.

That is not delivery. 

Code is delivered when it is in production. Handing off code that may or may not work well with other code is not delivery. Delivery requires that the code be tested and be fit for service. Delivery isn't some handoff ceremony where QA comes in and tells you they'll take it from here. Delivery is the act of putting code into the hands of users, so that it can be used.

In his excellent book, [Code Simplicity](http://shop.oreilly.com/product/0636920022251.do), Max Kanat-Alexander says that the purpose of software is to help people. If your software isn't helping people, you haven't delivered it.

It's a comforting illusion to imagine that you've delivered on time, and that all those other groups didn't. Maybe it's useful propaganda to tell your boss. But it's a dangerous thing to start believing your own propaganda. If you can't be honest with your coach, or honest with your boss, or honest with your underlings, at least be honest with yourself. That thing you did, that release... that wasn't delivery. That software isn't helping people, because it can't be released, because it is buggy and non-functional and doesn't do what you promised it would. It doesn't matter which group is the most to blame, or whether you can shift responsibility to some other person, the software *still* isn't helping anybody.

You did *not* deliver. That was digiorno, maybe, but it wasn't delivery.

So what can you do about it?

Honestly, I think you know the answer to this question. If you have dependencies, test them. If you have questions, get the answered. If you need to work together with other groups, get them on the phone. And if you have to release less in order to release without bugs, *do so*. You know where your pain points are, you just have to be honest enough to admit you have a problem.
