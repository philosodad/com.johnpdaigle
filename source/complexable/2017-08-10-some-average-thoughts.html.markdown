---
title: Some Average Thoughts
date: 2017-08-10 23:26 EDT
tags:
---

I'm a fan of role-playing games. You know, games like Dungeons & Dragons, where you sit around a table with other people and create a story based on a set of rules and a basic plot, using dice to determine the outcome of various plot points.

I mean, I say I'm a fan, but really I'm more of a dilletante. I like playing rpgs, and I don't mind running them, but I'm not particularly well versed. And most of them, let's face it, are sort of complicated. So, let's consider a simpler RPG, which I'll call "Treebark", because I don't have more imagination. Like most RPGs, Troubleshot is meant to be played by a group of people, with one person being the "Rulekeeper", responsible for the larger plot, and the rest will take on the role of a character and navigate their way through the plot.

Most role playing games take place in a universe that drives plot points. So, for example, in the world of "Shadowrun" everything is very cyberpunkish, corporations own the world, everyone is on the internet all the time, and criminal is a reasonable career choice for a bright young person. So of course, all the characters are various kinds of criminals.

Treebark is going to take place in a universe that I'm creating, something I've been noodling with rather than finishing my novel. The universe of Treebark is exactly like this one, except that some people, called druids, have magic powers. The magic powers are good for exactly two things: opening portals into other universes and keeping you alive once you get there.

And since this sort of thing is no fun if you only have human characters, we'll add other non-magical worlds that also connect to the magical ones, so that players can choose a character from one of those worlds rather than from one of ours. Also, there should be more than one kind of druid for the characters to play. We'll have three, and two character races to choose from.

When creating a character, most gaming systems have stats of some kind to describe the attributes of the character, and we'll have them in our game too. Three physical stats (strength, agility, endurance), three magical stats (affinity, integration, memory) and three communication (charisma, listening, talking). For a fully rounded character we'd need more, but for now lets focus only on the magical and communication stats. 

Like in traditional D&D, we'll roll dice for stats, in our case 6 three sided dice, so the lowest score is a 6 and the highest is an 18.

Now, there are three kinds of characters to play: scanners, weavers, and healers. These are three distinct branches of magic.

Scanners look ahead, they have skills such as predestination, strategic mapping, and remote viewing. A scanner is good at figuring out what kind of situation you're about to get into, and what needs to be done to accomplish a goal. 

Weavers are good at practical magic, they act in the moment. A weaver takes energy and weaves it into matter, or matter and weaves it into energy. There's always a certain danger that a weaver will blow themselves and everyone else up, but a skilled weaver could create and power wings for the entire group.

Healers look behind, to what ought to have been. Often weavers damage the reality they are working in, healers have skills such as patch rift, contain energy, unharm spirit. They can fix damaged people or places if that damage was relatively recent, and are especially good at repairing magical damage.

So a balanced party should have some representatives of all three classes, or at least some multi-class characters to fill all the roles.

Different stats miniums are required for different classes. Here's a handy chart:

|   | Scanner | Weaver | Healer |
 :--- | :---: | :---: | :---:  
| affinity | 12 | 14 | 13 |
| integration | 12 | 13 | 13 |
| memory | 13 | 13 | 13 |
| charisma | 14 | 13 | 12 
| listening | 14 | 12 | 13 
| talking | 12 | 12 | 12 
   
We have two races of characters as well, and it wouldn't make sense for each one to be exactly equal in all things, so we'll add some bonuses for each race in different areas. Our two races will come from two different realities that can meet in the games "middle ground". Naming things is hard(tm), so let's ignore that and just call our other race "Vulcans". What makes them different? They are slightly less empathetic and slightly more cerebral than Terrans. This give them a slight bonus in affinity and integration, while Terrans get a similar bonus for charisma and listening.

How much bonus, though? What do we want the effect of this to be? What are the potential affects of different bonus systems on the decisions that players might make about what character and race combination to choose? We could figure this out with math, I guess, but math is hard. Let's figure this out with Elixir. 

The first thing we'll need is a dice roller. I'm not sold on this three-sided die roll yet, so we'll roll some number (`n`) of dice, and allow selection of the number of faces (`m`) the dice have.

    :::elixir
    iex > roll = fn(n, m) -> Enum.map(1..n, 
    ... > fn(x) -> Enum.random(1..m) end) end
    ... > roll.(6,3)
    [2, 1, 1, 1, 2, 1]

Of course, I need the sum of that roll as well, but that's a simple `|> Enum.sum` away. One interesting question might be, what is the max roll and the min roll, and how many ways are there to get every roll in between? We know that the min roll is just the number of dice (in this case 6) and the max roll is the number of dice times the highest dice value (in this case `6 x 3 = 18`). That gives us a range from `n..n*m`. I also know, with some easy math, that the total number of possible rolls is `m^n`, assuming that ordering matters.  Elixir does not have an exponent operator, but Erlang does have a `:math.pow/2`, but however I find the answer, in this case there are 729 possible rolls of the dice.

Looking at a simple case, lets say I'm using a two sided die, and I have three die. `2^3=8`, the lowest possible sum is 3, and the highest is six. What is the distribution of rolls?

| roll | sum |
| :--- | ---: |
| `[1,1,1]` | 3 |
| `[1,1,2]` | 4 |
| `[1,2,1]` | 4 |
| `[1,2,2]` | 5 |
| `[2,1,1]` | 4 |
| `[2,1,2]` | 5 |
| `[2,2,1]` | 5 |
| `[2,2,2]` | 6 |

We see that there is one roll with a sum of 3, three rolls with a sum of 4, three rolls that sum to 5, and one that totals 6. So I would predict that most of the time I would roll a 4 or a 5 with these dice. I could put this in a distribution like this:

total | possible rolls
--- | ---
3 | 1
4 | 3
5 | 3
6 | 1

So, what if I wanted to come up with all the possible rolls, and the associated frequency distribution, for any set of m n-sided dice? Is there a clever algorithm that will help me here?

Probably, but I'm not smart enough to figure out clever solutions, and it wasn't easy enough to look up this answer, so I think I'll attack this with brute force. Something like this:

    :::elixir
    iex > all_rolls = fn(dice, faces) 
        >   -> (0..trunc(:math.pow(faces, dice) * 10)) 
        >     |> Enum.reduce(MapSet.new, 
        >       fn(x, acc) 
        >         -> MapSet.put(acc, 
        >           roll.(dice, faces)) 
        > end) 
        > end
    #Function<12.52032458/2 in :erl_eval.expr/5>
    iex > all_rolls.(2,4)
    #MapSet<[[1, 1], [1, 2], [1, 3], [1, 4], [2, 1], [2, 2], 
    [2, 3], [2, 4], [3, 1], [3, 2], [3, 3], [3, 4], [4, 1], 
    [4, 2], [4, 3], [4, 4]]> 

The brute force approach I'm using is to roll 10 times as many times as there are possible rolls, which hopefully will get me every roll at least once. The rolls are put in a MapSet, which assures that in the end I only have each roll once.

This works pretty well for small number, for example, for a roll of 6 3's we'll need to make about 7000 rolls to generate the set, but it doesn't work as well for large numbers. If we wanted all the possible rolls for six ten-sided dice we need to account for a million possible rolls, and the brute force approach would require 10 million rolls to generate them!

Also, after experimenting, it doesn't consistently generate them. So this approach isn't appropriate for large numbers. But it should do for some quick and dirty calculation, and of course if I come up with a better function later I can plug it in.

Once we've generated all of the rolls, we need to group them by sum, so that we know how many ways there are to generate each of the possible values. For any given set of m n-sided dice, the range of possible values is `m,,m*n`, so it would probably be helpful to initalize a map with keys across that range and a value of 0.

    :::elixir
    iex > empty_value_map = fn(dice, faces) 
        > -> Enum.reduce(dice..(dice*faces), %{}, 
        > fn(v, acc) 
        > -> Map.put(acc, v, 0) end) end
    #Function<12.52032458/2 in :erl_eval.expr/5>
    iex > empty_value_map.(3,2)
    %{3 => 0, 4 => 0, 5 => 0, 6 => 0}

    :::elixir
    iex > value_map = fn(dice, faces) 
        > -> Enum.reduce(all_rolls.(dice, faces), 
        > empty_value_map.(dice, faces), 
        > fn(roll, acc) 
        > -> Map.get_and_update(acc, Enum.sum(roll), 
        > fn(val) 
        > -> {val, val+1} 
        > end) |> elem(1) 
        > end) 
        > end
    #Function<12.52032458/2 in :erl_eval.expr/5>
    iex > value_map.(3,3)
    %{3 => 1, 4 => 3, 5 => 6, 6 => 7, 7 => 6, 8 => 3, 9 => 1}

Using our new function, we can compare things, for example, what is the distribution difference between three six-sided dice and six three-sided dice?

value | 6 x 3 | 3 x 6 
--- | :---: | :---:
3 | - | 1 
4 | - | 3 
5 | - | 6 
6 | 1 | 10 
7 | 6 | 15 
8 | 21 | 21 
9 | 50 | 25 
10 | 90 | 27 
11 | 126 | 27 
12 | 141 | 25 
13 | 126 | 21 
14 | 90 | 15 
15 | 50 | 10 
16 | 21 | 6 
17 | 6 | 3 
18 | 1 | 1 
*total* | 729 | 216

### Postscript

This post has been sitting on my computer for so long that I'mjust going to put i t up there so I can start on something else.
