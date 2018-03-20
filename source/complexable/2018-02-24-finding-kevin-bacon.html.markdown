---
title: Finding Kevin Bacon
date: 2018-02-24 10:11 EST
tags:
---

###TL/DR

1. Filter a lot of data into a little data with Ecto
1. Move that data from one Postgres DB to another with Ecto
1. Export the data with Postgres `COPY` command

[Example Code](https://github.com/philosodad/dataday/tree/3.18)

### Introduction: A Few Good Names

This is series about about microservices.

In the last post, we downloaded three tab separated files from the [Internet Movie DataBase](http://www.imdb.com/interfaces/) and loaded them into a single Postgres Database, in three tables, `title_basics`, `name_basics`, and `title_principals`. We created a Phoenix application called `DataMunger` with three Schemas, `TitlePrincipal`, `TitleBasic`, and `NameBasic`. We can use these three tables to find information about movies (titles) and actors (names) by way of the `title_principals_table`. For example, in SQL, we can learn the names of the principal actors in the movie "Thor: The Dark World"

    :::psql
    data_imdb=# select primary_name from name_basics
    data_imdb-# where nconst in(
    data_imdb(# select p.nconst from title_principals p,
    data_imdb(# title_basics t
    data_imdb(# where t.primary_title ilike('thor%dark%')
    data_imdb(# and t.title_type='movie'
    data_imdb(# and p.tconst=t.tconst
    data_imdb(# and p.category ilike('act%'));
       primary_name    
    -------------------
     Natalie Portman
     Stellan Skarsgård
     Tom Hiddleston
     Chris Hemsworth
    (4 rows)

Or, I can find the titles of movies where Kirsten Dunst plays a principal role with Ecto:

    :::elixir
    iex(2)> q = Ecto.Query.from(
    ...(2)> n in DataMunger.NameBasic,
    ...(2)> where: ilike(n.primary_name, "Kirsten Dunst"),
    ...(2)> select: n.nconst)
    iex(4)> titles_from_nconst = fn(n) ->  
    ...(4)> Ecto.Query.from(               
    ...(4)> p in DataMunger.TitlePrincipal,
    ...(4)> where: p.nconst == ^n and      
    ...(4)> ilike(p.category, "act%"),     
    ...(4)> select: p.tconst) |>           
    ...(4)> DataMunger.ImdbRepo.all() end 
    iex(8)> q |> DataMunger.ImdbRepo.one() |>
    ...(8)> titles_from_nconst.() |>         
    ...(8)> Enum.map(fn(p) ->                
    ...(8)> Ecto.Query.from(                 
    ...(8)> t in DataMunger.TitleBasic,      
    ...(8)> where: t.tconst == ^p,           
    ...(8)> select: t.primary_title) |>      
    ...(8)> DataMunger.ImdbRepo.all() end)   

    11:54:00.602 [debug] QUERY OK....................
    SELECT t0."primary_title" FRO....................

    11:54:00.811 [debug] QUERY OK....................
    SELECT t0."primary_title" FRO....................
    [["The Virgin Suicides"], ["Get Over It"],
     ["Luckytown"], ["The Devil's Arithmetic"],
     ["The Animated Adventures of Tom Sawyer"],
     ["Woodshock"], ["The Beguiled"], [...], ...]
    iex(9)> v() |> Enum.count()
    71

And I might not even notice the N+1 problem I've got there, especially with better (or indeed any) indexes. 

In a future post, we'll be looking into the problem of finding the same relationships when the three tables are split across three microservices. To do this, we're going to split our database into three databases, and launch three webservices on Heroku to act as API backends. We can't do that as things stand, because I don't want to pay to host several million rows in a postgres database on Heroku. In fact, I'd like to stay on the free tier, so we're going to need to lose almost all of the data.

We can't just truncate the tables, because we want to maintain relationships. 

    :::iex
    title     title        name     title      title
              name                  name         
    -----     -----        ----     ----       -----
    t1 -----> t1:n1 -----> n1 ----> n1:t1 ---> t1 
        \ \-> t1:n4 --     n2   \-> n1:t2 ---> t2 
         \--> t1:nb - \    n3   |-> n1:t3 ---> t3   
                     \ \-> n4-  |-> n1:t4 ---> t4
                      |    n5 \ \-> n1:t5 ---> t5
                      |    n6  \--> n4:t1      t6
                      |    n7   |-> n4:t2      t7
                      |    n8   |-> n4:t4      t8
                      |    n9   \-> n4:tf --   t9
                      |    na   /-> nb:t1  |   ta
                       \-> nb ----> nb:t4  |   tb
                                \-> nb:t5  |   ta
                                           |   tb
                                           |   tc
                                           |   td
                                           |   te
                                           \-> tf

In the figure, t1 has 3 principal actors, n1, n4, and nb. Between the three actors, we have 6 movies, which would lead us to select even more actors, and so on. But if we only selected, say, 9 rows from each database, we would end up with titles in the `title` selection that didn't show up in the `title_name` selection, or `title_name` selections that didn't show up in `names`. So it's important that we select data algorithmically when trying to extract a useful subset of the data.

In the rest of this post, we'll be using Ecto to get a subset of the data that meets these constraints.

###Getting the Data Subset

There are a couple of approaches we could use, and probably there's an optimal algorithm for getting just exactly the data we want, but this is a case where the intuitive approach will probably do. Looking at the figure, it seems that by just following the arrows from `name` -> `title_principal` -> `title` -> `title_principal` -> `name` and so on, we should be able to rapidly expand our selection of names and titles until we have a nicely connected selection across all three databases. First we'll create new databases, then we'll write code to transform records from one type to another, then we'll write queries to extract the records we want and finally we'll put these together by loading the data into the new databases, 


####Create new tables

The database we have has some fields and some data that we know we aren't interested in. For example, there are a number of `title_type`s in the `title_basics` table: 

    :::psql
    data_imdb=# select distinct(title_type) from
     title_basics limit 5;
      title_type  
    --------------
     short
     tvMiniSeries
     movie
     tvEpisode
     video
    (5 rows)

But we're only interested in one `title_type`, `movie`. Similarly, in `title_principals`, there are a number of categories:

    :::psql
    data_imdb=# select distinct(category) 
     from title_principals limit 5;
        category     
    -----------------
     writer
     archive_footage
     composer
     archive_sound
     cinematographer
    (5 rows)

But we're only interested in `actor` or `actress`. So we'll create three new schemas that reflect our use case:

Create the migrations:

    :::bash
    $ mix ecto.gen.migration add_movies_table
    $ mix ecto.gen.migration add_actors_table
    $ mix ecto.gen.migration add_movies_actors_table

Define the migrations for movies:

    :::elixir
    defmodule DataMunger.Repo.Migrations.AddMoviesTable do
      use Ecto.Migration

      def change do
        create table("movies") do
          add :title, :string, size: 480
          add :tconst, :string, size: 9
          add :year, :integer
        end
      end
    end

actors:

    :::elixir
    defmodule DataMunger.Repo.Migrations.AddActorsTable do
      use Ecto.Migration

      def change do
        create table("actors") do
          add :name, :string, size: 480
          add :nconst, :string, size: 9
          add :birth_year, :integer
          add :death_year, :integer
        end
      end
    end

movie actors: 

    :::elixir
    defmodule DataMunger.Repo.Migrations.AddMoviesActorsTable do
      use Ecto.Migration

      def change do
        create table("movie_actors") do
          add :nconst, :string, size: 9
          add :tconst, :string, size: 9
          add :characters, {:array, :string}
        end
      end
    end

Run the migrations:

    :::bash
    $ mix ecto.migrate

####Transform a single record

We're going to want to transform a lot of different records from one type to another, `TitleBasic` to `Movie`, `NameBasic` to `Actor`, and `TitlePrincipal` to `MovieActor`, which means we're going to write some custom changesets. We can use tests to help us here, by defining what we want to have happen before we try to make it happen. The first two transformations are fairly straightforward:

    :::elixir
    defmodule DataMunger.ActorTest do
      use ExUnit.Case, async: true
      alias DataMunger.Actor
      import Ecto.Query

      setup do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(DataMunger.Repo)
      end

      test "can convert a name_basic record to an actor record" do
        ["Humphrey Bogart", "Natalie Portman"]
        |> Enum.each(fn(who) -> 
          [name] = from(n in DataMunger.NameBasic,
                      where: ilike(n.primary_name, ^who),
                      select: n) 
                   |> DataMunger.ImdbRepo.all() 
           change = Actor.changeset(%Actor{}, name)

           {:ok, actor} = DataMunger.Repo.insert(change)
           assert actor.name == name.primary_name
           assert actor.nconst == name.nconst
           assert actor.birth_year == name.birth_year
           assert actor.death_year == name.death_year
        end)
      end
    end

Here, we are looking up 2 actors by name to get their `NameBasic` structs, creating an `Actor` changeset for each one, inserting that changeset into the database, and comparing the relevant keys between `NameBasic` and `Actor`.

In `data_munger/lib/data_munger/actor.ex`:

    :::elixir
    def changeset(%Actor{} = actor, 
                  attrs = %DataMunger.NameBasic{}) do
      %{}
      |> Map.put(:nconst, attrs.nconst)
      |> Map.put(:name, attrs.primary_name)
      |> Map.put(:birth_year, attrs.birth_year)
      |> Map.put(:death_year, attrs.death_year)
      |> (&(changeset(actor, &1))).()
    end

    def changeset(%Actor{} = actor, attrs) do
      actor
      |> cast(attrs, [:nconst, :name, :birth_year, :death_year])
      |> validate_required([:nconst, :name])
    end

We can take a similar approach to movies, but the `MovieActor` transformation is a little different. When we defined this schema, we made the `characters` field an array type. In order to ensure that we're going to get records with multiple characters, we can add a constraint that the character field is more than 100 characters.

    :::elixir
    test "can convert a name_basic record to an actor record" do
      from(p in DataMunger.TitlePrincipal, 
           where: ilike(p.category, "act%") and 
           fragment("char_length(?)", p.characters) > 100, 
           select: p, limit: 3)
      |> DataMunger.ImdbRepo.all()
      |> Enum.each(fn(principal) -> 
         change = MovieActor.changeset(%MovieActor{}, principal)

         {:ok, movie_actor} = DataMunger.Repo.insert(change)
         assert movie_actor.nconst == principal.nconst
         assert movie_actor.tconst == principal.tconst
         assert Enum.count(movie_actor.characters) > 1
      end)
    end

But when we run this query, we're going to see a problem in our results:

    :::iex
    iex(309)> Ecto.Query.from(p in DataMunger.TitlePrincipal, 
    ...(309)> select: p.characters,                          
    ...(309)> where: ilike(p.category, "act%") and           
    ...(309)> fragment("char_length(?)", p.characters) > 100, 
    ...(309)> limit: 3) |>                                   
    ...(309)> DataMunger.ImdbRepo.all()                       
    ["[\"Housekeeper (segment \"The Ghost of Murder Hill\")\",
      \"Susan Castaneda (segment \"The Sailor's Secret\")\"]",
    .....

Specifically, the first result contains nested quotes. Now, we could probably parse the results in such a way as to keep that data, but in the interests of time, we'll just drop any sort of segment or episode information, by removing anything that is between `(` and `)`.

In `lib/data_munger/movie_actor.ex`:

    :::elixir
    def changeset(%MovieActor{} = movie_actor, 
                  %DataMunger.TitlePrincipal{} = attrs) do
      attrs = Map.from_struct(attrs)
      changeset(movie_actor, attrs)
    end

    def changeset(%MovieActor{} = movie_actor, attrs) do
      movie_actor
      |> cast(attrs, [:tconst, :nconst])
      |> add_category(attrs)
      |> validate_required([:nconst, :tconst])
    end

    @doc false 
    def add_category(changeset, attrs) do
      case attrs
           |> Map.get(:characters) |> IO.inspect  do

         nil -> changeset
         character_string -> 
           characters = character_string
                        |> String.replace(~r/\ \(.*\)/, "")
                        |> Poison.decode!()
                        changeset 
                        |> Ecto.Changeset.put_change(
                          :characters, characters)
      end
    rescue
      _ -> changeset
           |> Ecto.Changeset.put_change(:characters, [])
    end

Now we can convert one single record of any kind to its corresponding record in our new tables. See the [github repository](https://github.com/philosodad/dataday/tree/3.18) for details on how the `Movie` schema is handled.

####Extracting the Data

Extracting the data means solving the problem of getting a sparse, connected data set of fewer than 10000 rows for the largest database.

#####The Query Wild

We'll start in Postgres and explore the data we've got. The queries we use to do this will be refined and converted into Ecto when we have a better idea what we want to do. Let's start by asking a simple question: How many movies has Kevin Bacon been in? We'll start with getting a universal key:

    :::psql
    data_imdb=# select nconst from name_basics
    data_imdb-# where primary_name 
    data_imdb-# ilike('natalie portman');
      nconst   
    -----------
     nm0000204

Then use that universal key to answer the question:

    :::psql
    data_imdb=# select count(*) from title_principals p
    data_imdb-# join title_basics t
    data_imdb-# on (p.tconst=t.tconst)
    data_imdb-# where nconst='nm0000204' and
    data_imdb-# category ilike('act%') and
    data_imdb-# title_type='movie';
     count 
    -------
        36
    (1 row)

That's a fair number of movies. How many costars does that get us?

    :::psql
    data_imdb=# select count(distinct p.nconst) 
    data_imdb=# from title_principals p where 
    data_imdb=# p.tconst in
    data_imdb=# (select p.tconst from title_principals p
    data_imdb=# join title_basics t
    data_imdb=# on (p.tconst=t.tconst)
    data_imdb=# where nconst='nm0000204' and
    data_imdb=# category ilike('act%') and
    data_imdb=# title_type='movie');
     count 
    -------
       276
    (1 row)

So, if we want to limit to 10,000 rows, we won't be able to go 2 degrees from the source before passing our limit, because 200 squared is 40,000. If we include all the movies for all the actors, we're going to end up with a network that has a small number of extremely tightly coupled nodes, which isn't really the same shape as the IMDb database.

In the IMDb data, yes, there are 276 actors who are costars of Kevin Bacon, but there are 1.6 million actors who are not. Never-the-less, there is a short path from most actors to most other actors... if an actor has 100 costars in a career, and each of these has a 100 costars, that's 10,000 actors who have co-starred with a co-star of the first actor, and 1,000,000 who have co-starred with a co-star of a co-star. A network like this, where most nodes have similar *degree* (number of costars) and the path length between any two nodes is short is called a "small world" network. This is the property that we want to maintain in our own data. One thing we could try is limiting the number of costars by limiting the number of movies:

    :::psql
    data_imdb=# select count(distinct p.nconst) 
    data_imdb=# from title_principals p where 
    data_imdb=# p.tconst in
    data_imdb=# (select p.tconst from title_principals p
    data_imdb=# join title_basics t
    data_imdb=# on (p.tconst=t.tconst)
    data_imdb=# where nconst='nm0000204' and
    data_imdb=# category ilike('act%') and
    data_imdb=# title_type='movie' limit 3);
     count 
    -------
       22
    (1 row)

22 cubed is 10,648, so theoretically we won't even be able to get 3 degrees from the source before passing our limit. However, there's probably a good deal of overlap (that's also a characteristic of small-world networks), so 3 seems like a reasonable starting place for limiting movies per actor.

At this point we're passing my ability to write SQL, so lets see if we can do some exploring in Ecto. A query for finding three movies for an actor:

    :::elixir
    iex(15)> mfa = fn(a) -> Ecto.Query.from(                 
    ...(15)> p in DataMunger.TitlePrincipal,                 
    ...(15)> join: t in DataMunger.TitleBasic,               
    ...(15)> on: p.tconst == t.tconst,                       
    ...(15)> where: p.nconst == ^a and                       
    ...(15)> t.title_type=="movie" and                       
    ...(15)> ilike(p.category, "act%"),                      
    ...(15)> select: p.tconst,                             
    ...(15)> limit: 3) |> 
    ...(15)> DataMunger.ImdbRepo.all() end 
    #Function<6.52032458/1 in :erl_eval.expr/5>
    iex(16)> tfa.("nm0000204")
    ["tt2798920", "tt2180351", "tt0947798"]

A query for actors in a movie:

    :::elixir
    iex(20)> afm = fn(m) -> Ecto.Query.from(
    ...(20)> p in DataMunger.TitlePrincipal,
    ...(20)> where: p.tconst == ^m and      
    ...(20)> ilike(p.category, "act%"),     
    ...(20)> select: p.nconst) 
    ...(20)> |> DataMunger.ImdbRepo.all() end          
    #Function<6.52032458/1 in :erl_eval.expr/5>
    iex(21)> afm.("tt2798920")
    ["nm0000204", "nm0000492", "nm1935086", "nm0938950"]

    iex(22)> 

The movies for actor `mfa/1` query takes about 5 seconds to return, and the `afm/1` query takes half a second. We'll be happier if we add a couple of indexes.

    :::psql
    imdb# create index on title_principals 
    imdb# (tconst, nconst, category);
    imdb# create index on title_principals 
    imdb# (tconst, category);
    imdb# create index on title_basics
    imdb# (tconst, title_type);
    imdb# create index on name_basics
    imdb# (nconst);

On my machine, that drops both queries into the 1-2 millisecond range. The last index on `name_basics` we won't need until the end, but we might as well add it now.

Then we can write a function to chain our two queries together.

    :::elixir
    iex(81)> xs_from_ys = fn(vals, f) ->
    ...(81)> Enum.flat_map(vals, fn(v) ->
    ...(81)> f.(v) end) |> Enum.uniq end
    #Function<12.52032458/2 in :erl_eval.expr/5>
    iex(82)> afm.("tt0110413") |> xs_from_ys.(mfa)
    ["tt0085426", "tt0095250", "tt0099789", "tt0091954",
    "tt0093776", "tt0096294", "tt0080605", "tt0081145", 
    "tt0082177", "tt0110413", "tt0120915", "tt0121765"]

So now we can find how many movies and titles we have at various distances from our seed actor. 

    :::elixir
    iex(103)> mfa.("nm0000204") |> xs_from_ys.(afm) |>
    ...(103)> xs_from_ys.(mfa) |> xs_from_ys.(afm) |> 
    ...(103)> xs_from_ys.(mfa) |> xs_from_ys.(afm) |>
    ...(103)> xs_from_ys.(mfa) |> xs_from_ys.(afm) |>
    ...(103)> Enum.count()
    2927
    iex(103)> mfa.("nm0000204") |> xs_from_ys.(afm) |>
    ...(103)> xs_from_ys.(mfa) |> xs_from_ys.(afm) |> 
    ...(103)> xs_from_ys.(mfa) |> xs_from_ys.(afm) |>
    ...(103)> xs_from_ys.(mfa) |> xs_from_ys.(afm) |>
    ...(103)> xs_from_ys.(mfa) |> xs_from_ys.(afm) |>
    ...(103)> Enum.count()
    12325

This pattern of moving from movie to actor to movie to actor and so on should look familiar, we're basically recreating the logic from our ascii figure above.

After player around with this a bit, it seems like we can safely go about 4 degrees away from the seed if we limit the number of movies to three. This is imprecise, but it is a strategy that should build a sparse, connected, small worldy network.

#####Query Things

We'll clean up our queries and add them to a `GraphTraverse` module.

    :::elixir
    defmodule DataMunger.GraphTraverseTest do
      use ExUnit.Case, async: true
      alias DataMunger.GraphTraverse
      alias DataMunger.ImdbRepo
      alias DataMunger.TitleBasic
      alias DataMunger.TitlePrincipal

      describe "movies for actor" do
        test "given a name, finds 3 movie tconsts" do
          ["nm0000203", "nm0000702", "nm0000204", "nm0000102"]
          |> Enum.each(fn(n) ->
            GraphTraverse.movies_for_actor(n)
            |> Enum.map(fn(m) ->
              ImdbRepo.get(TitleBasic, m)
            end)
            |> Enum.map(fn(mov) ->
              assert mov.title_type == "movie"
            end)
            |> (&(assert Enum.count(&1) == 3)).()
          end)
        end
      end
    end

Our testing strategy is basically to call back to `TitleBasic` to make sure we got the right number of movies. We should also check that the movies we got back directly related to each name as an Actor in the `TitlePrincipal` table. We won't show that test here, but it is in the [example code](https://github.com/philosodad/dataday/tree/3.18).

We can pass these tests with the following code:

    :::elixir
    defmodule DataMunger.GraphTraverse do
      alias DataMunger.TitlePrincipal
      alias DataMunger.TitleBasic
      alias DataMunger.ImdbRepo
      import Ecto.Query, only: [from: 2]

      def movies_for_actor(actor, count \\ 3) do
        from(p in TitlePrincipal,
        join: t in TitleBasic,
        on: p.tconst == t.tconst,
        where: p.nconst == ^actor and
        t.title_type=="movie" and
        ilike(p.category, "act%"),
        select: p.tconst,
        limit: ^count)
        |> ImdbRepo.all()
      end
    end

The code and tests for the complementary `actors_for_movie` function and the `principals_from_movies` function are very similar so we won't show them here. We are interested in the code that puts these together. We'll test the functionality of finding many movies and actors from a single actor. In `test/data_munger/graph_traverse_test`: 

    :::elixir
    describe "gets actors and movies from one actor" do
      test "returns uniq collections" do
        {acs, mos} = ["nm0000204"]
                     |> GraphTraverse.movies_and_actors([], 2)
        actors
        |> Enum.each(fn(a) ->
          assert String.match?(a, ~r/nm[0-9]{7}/)
        end)
        assert actors 
               |> Enum.uniq()
               |> Enum.count() == actors 
                                  |> Enum.count()
        actors
        |> Enum.each(fn(a) ->
          assert String.match?(a, ~r/nm[0-9]{7}/)
        end)
        assert Enum.count(actors) > 18
        assert movies 
               |> Enum.uniq()
               |> Enum.count() == movies 
                                  |> Enum.count()
        assert Enum.count(movies) > 6
      end
    end

The API we're assuming here is that the `movies_and_actors` function is going to take three arguments, actors, movies, and a depth. The idea is to find all the costars of the first set of actors, then the costars of all the costars (for three movies) out to a certain search depth into the graph. In `/lib/data_munger/graph_traverse.ex`:

    :::elixir
    def movies_and_actors(actors, movies, 0) do
      {actors, movies}
    end

    def movies_and_actors(actors, _movies, depth) do
      new_movies = actors
                   |> Enum.flat_map(fn(a) -> 
                    movies_for_actor(a) end)
                   |> Enum.uniq()
      new_actors = new_movies
                   |> Enum.flat_map(fn(m) -> 
                    actors_for_movie(m) end)
                   |> Enum.uniq()
      movies_and_actors(new_actors, new_movies, depth-1)
    end

A bit of explanation: we're defining this as a recursive function, using the first pattern `(actors, movies, 0)` as the terminating condition, and the second pattern `(actors, _movies, depth)` is the recurrent procedure. In the recurring procedure, we use the list of actors to find 3 movies for each actor, and then we get all the actors for each of those movies. We go to the next recurrence with this new group of actors and movies. The `depth` variable keeps track of how deep we've gone into the recursion, ensuring that we'll exit when that value hits zero.

This solution could be improved in a couple of ways. The most obvious is that we don't use the results of previous searches to limit the current search, so we make a lot of repetitive calls to the database. In fact, we only carry the movies from one recursion to the next so that we can return them when we hit 0. If we were concerned with performance we'd have to use a technique such as memoization to avoid making repetitive calls, but since we aren't the naive version of the algorithm is fine. It's worth noting in any case, because recursion is used a lot in Elixir code and it's good to be aware of when you are falling into a common recursion pitfall.

In any case, we can now extract our sparse subgraph:

    :::elixir
    iex(326)> DataMunger.GraphTraverse.movies_and_actors(
    ...(326)> ["nm0000204", "nm0000702"], [], 4) 
    {["nm0427136", "nm0301556", "nm0473218", ...],
     ["tt0084627", "tt0085426", "tt0275909",  ...]}
    iex(327)> {actors, movies} = v()
    {["nm0427136", "nm0301556", "nm0473218", ...],
     ["tt0084627", "tt0085426", "tt0275909",  ...]}
    iex(329)> princs = movies |>                               
    ...(329)> DataMunger.GraphTraverse.principals_from_movies()
    [714013, 714015, 714014, ...]
    iex(330)> Enum.count(actors)
    4787
    iex(331)> Enum.count(movies)
    1966
    iex(332)> Enum.count(princs)
    8137

It's not perfect, but it's fine.

####Extract, Transform, Load

We're now just about done. All that's left is using the results from the functions in `GraphTraverse` to load data into the schemas we created way back in the Transform step. We'll look in depth at just `title_principal` -> `movie_actor`. Again, we start with a test (`test/data_munger/etl_test.exs`):

    :::elixir
    defmodule DataMunger.EtlTest do
      use ExUnit.Case, async: true
      require Ecto.Query
      alias Ecto.Query
      alias DataMunger.Etl
      alias DataMunger.Repo
      alias DataMunger.ImdbRepo
      alias DataMunger.Movie
      alias DataMunger.TitlePrincipal
      alias DataMunger.Actor
      alias DataMunger.MovieActor

      setup do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(DataMunger.Repo)
      end

      test "adds the actor-movies" do
        DataMunger.Etl.load_from_seed(["nm0000204"], 1)

        ids = [937006, 937007, 937009, 937008, 1024551, 
               1024552, 1024554, 1024553, 1029911, 
               1029913, 1029914, 1029912]
        title_principals = Query.from(
          p in TitlePrincipal,
          where: p.id in ^ids,
          select: {p.nconst, p.tconst})
        |> ImdbRepo.all()
        movie_actors = Query.from(
          ma in MovieActor, 
          select: {ma.nconst, ma.tconst})
        |> Repo.all()
        
        assert title_principals -- movie_actors == []
        assert movie_actors -- title_principals == []
        assert Enum.count(movie_actors) == 12
      end
    end

So obviously there's some cheating going on here, I'm counting on the movies being returned from the database to always be returned in order, and I checked before hand to see which ids I would get back from a call to `GraphTraverse.movies_and_actors/3`. But essentially, I want to know that I'm creating records that match on the relevant transformed fields (`nconst` and `tconst`). We put all of this together in `data_munger/lib/data_munger/etl.ex`:  

    :::elixir
    defmodule DataMunger.Etl do
      alias DataMunger.GraphTraverse
      alias DataMunger.TitlePrincipal
      alias DataMunger.MovieActor
      alias DataMunger.Repo
      alias DataMunger.ImdbRepo
      import Ecto.Query, only: [from: 2]

      def load_from_seed(seeds, depth) do
        {names, movies} = GraphTraverse.movies_and_actors(seeds, [], depth)
        principals = GraphTraverse.principals_from_movies(movies)
        from(p in TitlePrincipal,
         where: p.id in ^principals,
         select: p)
        |> ImdbRepo.all()
        |> Enum.each(fn(p) ->
          movie_actor_from_title_principal(p)
        end)
      end

      defp movie_actor_from_title_principal(principal) do
        %MovieActor{}
        |> MovieActor.changeset(principal)
        |> Repo.insert()
      end
    end

Similar strategies will load the `names` and `movies` tables. With this code written, we're ready to actually execute the ETL in development.

    :::psql
    data_imdb=# \c data_munger_dev
    You are now connected to database "data_munger_dev" as
    data_munger_dev=# select count(*) from actors;
     count 
    -------
         0
    (1 row)

    data_munger_dev=# select count(*) from movies;
     count 
    -------
         0
    (1 row)

    data_munger_dev=# select count(*) from movie_actors;
     count 
    -------
         0
    (1 row)

So at this point, if you haven't created the indexes we created earlier and you want to run this step, definitely create the indexes! Otherwise this will absolutely not run in a reasonable period of time:

    :::iex
    iex(1)> DataMunger.Etl.load_from_seed(
            ["nm0000204", "nm0000702"], 4)

If we check our work in psql:

    :::psql
    data_munger_dev=# select count(*) from movie_actors;
     count 
    -------
      8137
    (1 row)

    data_munger_dev=# select count(*) from actors;
     count 
    -------
      4787
    (1 row)

    data_munger_dev=# select count(*) from movies;
     count 
    -------
      1966
    (1 row)

    data_munger_dev=# select count(*) from movie_actors;
     count 
    -------
      8137
    (1 row)

Now that we have the data loaded into separate databases and the data set shrunk down to the size we wanted, we can export each database.

    :::psql
    data_munger_dev=# copy actors to <filepath>;
    COPY 4787
    data_munger_dev=# copy movies to <filepath>;                    
    COPY 1966
    data_munger_dev=# copy movie_actors to <filepath>;        
    COPY 8137

And finally, we're done! Next time, we'll look at creating our three phoenix services and launching them to heroku. [Code from this post here](https://github.com/philosodad/dataday/tree/3.18).

