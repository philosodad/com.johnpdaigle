---
title: Phoenix on Heroku, Again
date: 2018-03-25 11:15 EDT
tags:
---

People have posted this before, with descriptions and diagrams and everything, but it's the next step in our series about microservices (see [Part 1](),[Part 2a](), and [Part 2b]()), so here it goes.

You have installed: Elixir 1.6, Phoenix 1.3, Erlang 20.1, PostgreSQL 10.1

Make a phoenix app:

    :::bash
    $ mix phx.new movie_actors --no-brunch --no-html

create migration:

    :::bash
    $ head movie_actors.tsv 
    24436   nm0000064       tt0006371       {"Factory Worker"}
    24437   nm0621770       tt0006371       {Rozika}
    24438   nm0362815       tt0006371       {"David Fravoe"}
    24439   nm0166588       tt0006371       {"Captain Halliday"}
    24440   nm0110838       tt0006371       {Marcus}
    24441   nm0411935       tt0006371       {"Marcus' Wife"}
    24442   nm0361882       tt0006371       {Carl}
    24443   nm0351734       tt0014504       {"Dr. Borris' Sekretärin"}
    24444   nm0221509       tt0014504       {"Idea - Zirkusartistin"}
    24445   nm0727210       tt0014504       {"Frank - Ideas Partner"}
    $ cut -f 2- movie_actors.tsv > movie_actors_cut.tsv
    $ head movie_actors_cut.tsv 
    nm0000064       tt0006371       {"Factory Worker"}
    nm0621770       tt0006371       {Rozika}
    nm0362815       tt0006371       {"David Fravoe"}
    nm0166588       tt0006371       {"Captain Halliday"}
    nm0110838       tt0006371       {Marcus}
    nm0411935       tt0006371       {"Marcus' Wife"}
    nm0361882       tt0006371       {Carl}
    nm0351734       tt0014504       {"Dr. Borris' Sekretärin"}
    nm0221509       tt0014504       {"Idea - Zirkusartistin"}
    nm0727210       tt0014504       {"Frank - Ideas Partner"}
    $ rm movie_actors.tsv 
    $ mv movie_actors_cut.tsv movie_actors.tsv 
    $ mix ecto.gen.migration create_movie_actors

Write the migration:

    :::elixir
    defmodule MovieActors.Repo.Migrations.CreateMovieActor do
      use Ecto.Migration

      def change do
        create table(:movie_actors) do
          add :nconst, :string
          add :tconst, :string
          add :characters, {:array, :string}

          timestamps()
        end
      end
    end

Write a `priv/repo/seeds.exs` file

    :::elixir
    alias MovieActors.MovieActor
    alias MovieActors.Repo

    defmodule MovieActors.Seeds do


      def store_it(row) do
        row = row.characters
              |> String.replace(~r/{|}|\\N/, "")
              |> String.split(",")
              |> (&(Map.put(row, :characters, &1))).()
        changeset = MovieActor.changeset(%MovieActor{}, row)
        Repo.insert!(changeset)
      end
    end

    File.stream!("movie_actors.tsv")
    |> CSV.decode!(headers: [:nconst, :tconst, :characters], separator: ?\t)
    #|> IO.inspect
    |> Enum.each(&MovieActors.Seeds.store_it/1)

Load the seeds file in `dev` and `test`:

    :::bash
    $ mix run priv/repo/seeds.exs
    $ MIX_ENV=test mix run priv/repo/seeds.exs

Let's check out data in `psql`:

    :::psql
    postgres=# \c movie_actors_test postgres
    You are now connected to database "movie_actors_test" as user "postgres".
    movie_actors_test=> select * from movie_actors where nconst = 'nm0000204';
      id  |  nconst   |  tconst   |       characters        |        inserted_at         |         updated_at         
    ------+-----------+-----------+-------------------------+----------------------------+----------------------------
     7040 | nm0000204 | tt0110413 | {Mathilda}              | 2018-03-31 23:41:52.604364 | 2018-03-31 23:41:52.604369
     7168 | nm0000204 | tt0121765 | {Padmé}                 | 2018-03-31 23:41:52.655398 | 2018-03-31 23:41:52.655403
     7252 | nm0000204 | tt0120915 | {"Queen Amidala",Padmé} | 2018-03-31 23:41:52.696957 | 2018-03-31 23:41:52.696962
     7501 | nm0000204 | tt0121766 | {Padmé}                 | 2018-03-31 23:41:52.793724 | 2018-03-31 23:41:52.793729
    (4 rows)

    movie_actors_test=> \c movie_actors_dev postgres
    You are now connected to database "movie_actors_dev" as user "postgres".
    movie_actors_dev=> select * from movie_actors where nconst = 'nm0000204';
      id  |  nconst   |  tconst   |       characters        |        inserted_at         |         updated_at         
    ------+-----------+-----------+-------------------------+----------------------------+----------------------------
     7040 | nm0000204 | tt0110413 | {Mathilda}              | 2018-03-31 23:42:08.499758 | 2018-03-31 23:42:08.499763
     7168 | nm0000204 | tt0121765 | {Padmé}                 | 2018-03-31 23:42:08.593704 | 2018-03-31 23:42:08.59371
     7252 | nm0000204 | tt0120915 | {"Queen Amidala",Padmé} | 2018-03-31 23:42:08.663436 | 2018-03-31 23:42:08.663441
     7501 | nm0000204 | tt0121766 | {Padmé}                 | 2018-03-31 23:42:08.855257 | 2018-03-31 23:42:08.855263
    (4 rows)

    movie_actors_dev=> 

