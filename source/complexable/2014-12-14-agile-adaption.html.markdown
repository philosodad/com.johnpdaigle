---
title: Agile Adaption
date: 2014-12-14 12:50 EST
tags:
---

I'm a huge fan of Agile processes, and especially of XP. I'd like to think that my reasons for this are sound, that XP is a useful way to do software development. And at the same time, it's widely acknowledged that XP is not overly useful in certain scenarios. The whole idea of a Kanban process, for example, is to introduce a sort of rolling target without specific iteration goals, appropriate for groups that do a lot of support requests or similar work: High priority items that cannot be anticipated in planning.

There's also the fact that following XP, while it provides a lot of stability, can be restrictive. Restrictions can be liberating in a sense, but they can also be, you know, restrictive. So lately, I've been working with my team to try and find another process, something that fulfills the following goals:

1. We will always be able to respond quickly to support issues.
1. We will know what we have completed.
1. We will know what we planned to complete.
1. We will be able to judge whether we are improving as a team.

These goals should sound pretty familiar to anyone who has worked in an agile environment. Really, these are just restatements of some basic agile principles, responding to change, continuous improvement, etc. The reason it's useful to restate these things is that it is helpful to prioritize the principles as a team. When you have to make choices, it's good to have some goals that inform the choices you make.

This has led to the birth of a sort of hybrid XP/Kanban process that the team is very happy with, and one that I think is becoming more successful over time. Where the success is showing up is not just in productivity--although there have been some gains there--but in understanding our environment, recognizing the issues that the team has to overcome and the strengths that we can develop.

## Missions
Our team does not work in "sprints" or "iterations". One reason for this is that both of these terms are loaded with a little bit of baggage. The baggage is that somehow, after x iterations or sprints, we'll be finished with a given project. Since we develop about 20 products simultaneously by necessity, that doesn't really work. We also have a large customer base that needs support, as well as special requests that must be met quickly, as well as bugs that must be fixed. So overall, we don't live in a world with a finish line or a single product, we live in a quickly and constantly changing world with a huge number of moving parts. Our plans never survive the first day.

So we run "missions", paying homage to the old military adage "No plan survives contact with the enemy". Not that the customer is the enemy or anything, but we are managing a lot of complexity.

### Mission Planning

Once every two weeks, the team sets up some mission goals and operational plans. For example, we may plan on updating some old code to include behavioral tests, or we may plan on updating new code to add functionality, modifying our infrastructure, etc. We may set some guidelines, such as "The team plans to pair each day for 2 hours". This creates a focused set of work that is the things we plan on getting done. The plan is greatly influenced by the other meeting we have, the Mission Debrief.

### Mission Debriefing

This is essentially a retrospective (although we're changing the retro format a bit, which I might post on later). Basically, the idea is to look at the mission goals that we planned versus the reality of what happened, and try to decide why the situation was the way it was. I am a huge believer in the idea that a retrospective should be completely free of negativity, in our debriefs we are not concerned with whether things went "wrong", we're concerned with what happened and whether we could have planned for it happening or controlled it happening. It's about lessons learned and things accomplished, both of which are positives.

### Mission Control

Mission control is accomplished by the good old card wall. We color code our cards, but not by whether this is a feature, bug, tech task, or whatever. Everything is a unit of work, and the only differentiator between units of work is state (on hold, blocked) or origin (planned, unplanned). That's it. We've found it just isn't helpful to know how much infrastructure work we've done versus feature development, because whatever we've done is something that we either planned to accomplish because it matched our priorities of work, or that we were asked to accomplish. The work that was added to the wall is interesting in terms of whether it is a bug request or not, so at some point we may get into that taxonomy. But at the moment the real question is how much extra work is showing up that we have to do, and how that affects our ability to plan work. 

## Value

When you follow any process, there are people that will not like it. Some might say that you are using too much process, others that you are using too little. The mission debrief/mission planning meetings do take up time, so some may wonder whether they are useful or not, and others might wonder how we get by without weekly updates. 

Our stated goals, as a team, are to have a basis to decide whether what we're doing is working, whether we're getting the things done that we think need to get done. And it's really hard to do that if you don't use fixed time periods to look at what was done. There's a tendency *not* to have meetings that you don't consider mandatory, and that means that if you don't schedule the time to debrief, you never will. And without considering what lessons you have learned you essentially learn no lessons, which fights against continuous improvement and actually tends towards continuous degradation. Say you have a goal to add stronger infrastructure testing to a product. The team begins work on this, and then something comes up, and something else comes up, and the stronger infrastructure testing gets forgotten at some point. If the team doesn't periodically reflect, the next time they'll think about this goal that they never got to is the next time that there is a major problem that would have been avoided by completing the work. Then it becomes a new priority that has to get done, and the cycle repeats.

Forgotten goals remain forgotten by teams that do not periodically assess whether they are accomplishing their goals.

Of course, if you don't periodically plan your goals, you might not even get that far. Say you have a problem that could be ameliorated by adding some key piece of architecture. At a specific pain point, it gets brought up that this needs to be accomplished. It doesn't get prioritized right away, though, because the team is working on other things that are higher priority. Then, because the problem doesn't hurt as much over the next three weeks or so, the change doesn't get made. But then it comes up again, and it hurts even more, but it's harder to do now because the software has grown in complexity. And it gets forgotten again.

The team that meets periodically will remember this pain because it is on their list of things that happened recently. It can be added to the next mission (hopefully), because the team works in small missions and prioritizes work periodically. Even if it isn't added right away, it can at least go to the backlog, to be brought up again at the next planning. The key point is not to forget things that need to be done.

On the flip side, of course, if you spend too much time planning and analyzing, you don't allow any time for the work to get done, and you don't allow time for unplanned events. In our case, if we tried to plan every week, we'd be spinning our wheels--our ration of unplanned to planned work is about 1:1, and so some weeks we might not get anything done that we planned to do.

Two weeks seems good for now, although we may consider moving to three weeks in the future. The problem with three weeks is that it takes some of the urgency out of completing work, because the longer time frame creates an illusion that the team has more time. Of course, the mission length is arbitrary and the amount of time the team has to do work in is not, so lengthening the mission might do more harm than good.

One advantage of not measuring points, or allocating points, is that the team *can* be flexible about mission length. The analysis of the mission isn't "how much did we get done", it's "how did our planning prepare us for our reality", and that question is one that remains valid even if the team experiments with lengthening or shortening the mission time.

All in all, we've had some success with this lightweight approach to an agile process, finding a balance between the more rigorous methods that don't seem appropriate to our environment, and a total lack of process that would stand in our way. It isn't perfect, but because we have more freedom to change than most agile teams, we have the power to improve.
