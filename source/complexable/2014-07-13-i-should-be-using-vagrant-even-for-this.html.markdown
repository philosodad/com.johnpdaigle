---
title: I should be using Vagrant, even for this
date: 2014-07-13 22:21 EDT
tags:
---

So the long title here probably gives more away than it should. But even so, I should be using Vagrant, even for the code for this website.

This website is built by Middleman, which is a static site builder. It's not complicated to set up, my GemFile for Middleman, Middleman-Blog, and a couple other things is about 10 lines long. It's very simple. Which is why it was so incredibly frustrating to sit down and realize that I was going to have to reinstall some stuff after upgrading (foolishly) to Mavericks. This is on a day when I already had to open up the back of the laptop and disconnect (I think) the battery wire because my keyboard and trackpad just stopped working. 

Whis is something of a design flaw. Even so, reinstalling the command-line tools, upgrading ruby (again) reinstalling the bundle (again) and again... I just hate doing that stuff. That's what all this stuff like bundler and rvm are supposed to be protecting me from, things are supposed to live in little walled gardens and whenever I go into the garden it's the same damn garden I left. Except that it isn't, because all of the gardens on my laptop live *on my laptop*, so whenever I change the laptop I create weird seismic shifts in the walled gardens, which may or may not result in a nokogiri install error.

For maximal peace of mind, I should probably be using Docker or Vagrant or c9.io, and have nothing installed on the laptop itself besides one version of ruby and whatever supports Vagrant or Docker. Its the software equivalent of Earthquake proof buildings, which seems like overkill... it's not like I change my laptop all that often. Of course, if you deal with disaster constantly, you don't need friendly disaster recovery systems, because you work with them all the time and they always seem friendly and normal. If you run xcode-select --install twice a day, you don't have to look it up. Your buildings aren't Earthquake proof, but you are an expert at assembling them. 

Note to all the devops personell: If you are a seasoned disaster recovery expert, you are doing something wrong.

Anyway, I don't recover from disasters often, and that's why I should build more robust systems. Fixing things is tedious, and a good programmer should be lazy enough to build things that won't have to be fixed all the time.
