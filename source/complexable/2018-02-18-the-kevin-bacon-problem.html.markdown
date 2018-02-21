---
title: The Kevin Bacon Problem
date: 2018-02-18 13:27 EST
tags:
---

### TL/DR

1. Download compressed .tsv files
1. Import tsv files into postgres database
1. Create phoenix.ecto project
1. Connect project to tables from import step
1. [Code Here](https://github.com/philosodad/dataday/tree/2.18)

### Tech Stack

Postgres 10.x, Elixir 1.4+, Erlang 19+

### Motivation

This is a post about microservices. Actually, it's a series of posts about microservices, because if I could put everything into one POST, it wouldn't be a microservice. 

Where we're going in the future is to put three microservices up on Heroku, with Postgres databases, each one serving a small subset of the Internet Movie DataBase. Then we're going to look at the problem of querying data across them, possibly creating a very small [oracle of bacon](https://oracleofbacon.org/help.php) along the way.

The three datasets are title.basics, which contains the names of movies and a unique identifier for each; name.basics, which contains the names of actors and crew and a unique identifier for each, and title.principals, which contains all the unique name/title combinations as well as some other data. Side note: On the `imdb.com/datasets` website, title.principals is not described this way, and I've downloaded that data three times and gotten two different schemas, so YMMV.

These datasets are big enough that, if we want to do this project on Heroku's free tier (which I do), we're going to need to filter out a lot of data. But we want to filter out that data such that we have connections (via the title.principals dataset) between all the actors and movies that we select. Given that we're taking a dataset with twenty-three million or so rows and breaking it down to a dataset of ten thousand, we could easily end up with disjoint actors and movies. 

We'll get into that requirement in more detail in a future post, in this post, we'll set up to filter that data with Elixir. We'll download the datasets, import them into a postgres database, create a phoenix ecto project, and write the schemas and configuration we need to connect to the existing tables.

### Let us cut Footloose

#### Get The Data into Postgres:

The first step is to get the data and prepare it for import. This involves using `head` and `tail` to split the .tsv file in two:

    :::bash
    $ wget https://datasets.imdbws.com/title.basics.tsv.gz
    $ gunzip title.basics.tsv.gz 
    $ head -n 1 title.basics.tsv > title.basics.headers.tsv
    $ tail -n +2 title.basics.tsv > trunc.title.basics.tsv
    $ rm title.basics.tsv

Repeat with title.principals.tsv.gz and name.basics.tsv.gz. We should end up with six files, three containing the column headers, and three containing the column data. This will make importing into Postgres easier.

Now we want to create a postgres database. I created one owned by the postgres user, although I'm not sure that it matters. You have to execute the `copy` command as a root user, so we end up altering the grants on the tables anyway.

    :::bash
    $ createdb -O postgres imdb_data
    $ psql imdb_data 

Create a table for the title.basics data. We can refer to the title.basics.headers.tsv file we created earlier for the column names. 

    :::psql
    imdb=# create table title_basics(
    imdb(# tconst varchar(9),
    imdb(# title_type varchar(80),
    imdb(# primary_title varchar(512),
    imdb(# original_title varchar(512),
    imdb(# is_adult boolean,
    imdb(# start_year smallint,
    imdb(# end_year smallint,
    imdb(# runtime_minutes int,
    imdb(# genres varchar(80)
    imdb(# )
    CREATE TAB, 

Now that we've created a table for the title.basics data, we can import the trunc.title.basics.csv file that we created. Remember, this is the data without the header columns.

    :::psql
    imdb=# COPY title_basics FROM '/path/to/trunc.title.basics.tsv';
    COPY 4817652

Now update the privileges on the `title_basics` table so that the postgres user can access it.

    :::psql
    imdb=# grant all on title_basics to postgres;
    GRANT

Now we repeat this process for trunc.title.principals.tsv and trunc.name.basics.tsv. When I was doing this, I ran into some errors, either because the ordering of my columns didn't match the tsv column ordering, or because I was using smallint where I should have used int, or I wasn't allowing the varchar size to be large enough. Eventually, my final schemas looked like this:

    :::psql
    data_imdb=# \d title_principals
                       Table "public.title_principals"
       Column   |          Type          | Coll| Null| Def
                |                        | atio| able| aul  
    ------------+------------------------+-----+-----+----
     tconst     | character varying(9)   |     |     | 
     ordering   | smallint               |     |     | 
     nconst     | character varying(9)   |     |     | 
     category   | character varying(80)  |     |     | 
     job        | character varying(480) |     |     | 
     characters | character varying(480) |     |     | 

    data_imdb=# \d name_basics 
                              Table "public.name_basics"
           Column       |          Type          | Collati
    --------------------+------------------------+--------
     nconst             | character varying(9)   |       
     primary_name       | character varying(240) |       
     birth_year         | smallint               |       
     death_year         | smallint               |       
     primary_profession | character varying(180) |       
     known_for_titles   | character varying(180) |       

    data_imdb=# \d title_basics
                            Table "public.title_basics"
         Column      |          Type          | Collation |
    -----------------+------------------------+-----------+
     tconst          | character varying(9)   |           |
     title_type      | character varying(80)  |           |
     primary_title   | character varying(512) |           |
     original_title  | character varying(512) |           |
     is_adult        | boolean                |           |
     start_year      | smallint               |           |
     end_year        | smallint               |           |

Make sure you have all your data loaded and your privileges set:

    :::psql
    data_imdb=# select count(*) from title_basics;                                                                      
      count  
    ---------
     4817652
    (1 row)

    data_imdb=# select count(*) from name_basics;                                                                       
      count  
    ---------
     8435455
    (1 row)

    data_imdb=# select count(*) from title_principals;
      count   
    ----------
     27109331
    (1 row)

    data_imdb=# \dp
                                             Access privile
     Schema |       Name       |   Type   |   Access privil
    --------+-------------------------+----------+---------
     public | name_basics      | table    | paul=arwdDxt/pa
            |                  |          | postgres=arwdDx
     public | title_basics     | table    | paul=arwdDxt/pa
            |                  |          | postgres=arwdDx
     public | title_principals | table    | paul=arwdDxt/pa
            |                  |          | postgres=arwdDx
    (3 rows)

If that looks more or less like what you're looking at, you're ready to move on.

#### Connect the database to a Phoenix project

We're going to use Ecto for the next part, and for convenience, we're going to create an Phoenix ecto project. We'll probably put the microservices we'll be building in a later post into this same umbrella project.

    :::bash
    $ mix new --umbrella dataday
    $ cd dataday/apps/
    $ mix phx.new.ecto data_munger
    
This project assumes that there is a `data_munger` database, which we will create next time. The config for that database is already set up. To connect to our `imdb_data` database, we need to add configuration to `/data_munger/config/dev.exs`.

    :::elixir
    config :name_basics, DataMunger.ImdbRepo,
      adapter: Ecto.Adapters.Postgres,
      username: "postgres",
      password: "postgres",
      database: "imdb_data",
      hostname: "localhost",
      pool_size: 10

We also need to add the new `DataMunger.ImdbRepo` to our supervision tree. In `data_munger/lib/data_munger/application.ex`

    :::elixir
    def start(_type, _args) do
      import Supervisor.Spec, warn: false

      Supervisor.start_link([
        supervisor(DataMunger.Repo, []),
        supervisor(DataMunger.ImdbRepo, []),
      ], strategy: :one_for_one, name: DataMunger.Supervisor)
    end

Now if we write a schema for one of the tables, we should be able to access it. Create a file `data_munger/lib/data_munger/name_basic.ex`:

    :::elixir
    defmodule DataMunger.NameBasic do
      use Ecto.Schema
      import Ecto.Changeset
      alias DataMunger.NameBasic


      @primary_key{:nconst, :string, []}
      schema "name_basics" do
        field :birth_year, :integer
        field :death_year, :integer
        field :primary_name, :string

      end

      @doc false
      def changeset(%NameBasic{} = name, attrs) do
        name
        |> cast(attrs, [:nconst, 
                        :primary_name,
                        :birth_year,
                        :death_year])
        |> validate_required([:nconst, :primary_name])
      end
    end

You might notice the line `@primary_key{:nconst, :string, []}` above the schema definition. When we created this table, we didn't give it an autoincrement id, but there is a good natural key we can use in the dataset, the `nconst` value, so we can instruct Ecto that we'll use that as the primary key.

Let's test our new schema in iex:

    :::elixir
    iex(1)> require Ecto.Query
    Ecto.Query
    iex(2)> Ecto.Query.from(                                 
    ...(2)> n in DataMunger.NameBasic,                      
    ...(2)> where: ilike(n.primary_name, "Natalie Portman"),
    ...(2)> select: n) |>
    ...(2)> DataMunger.ImdbRepo.all()

    00:37:47.847 [debug] QUERY OK source="name_basics" db=1
    722.7ms
    SELECT n0."nconst", n0."birth_year", n0."death_year", n
    0."primary_name" FROM "name_basics" AS n0 WHERE (n0."pr
    imary_name" ILIKE 'Natalie Portman') []
    %DataMunger.NameBasic{__meta__: #Ecto.Schema.Metadata 
    <:loaded, "name_basics">,
     birth_year: 1981, death_year: nil, nconst: "nm0000204"
     , primary_name: "Natalie Portman"}

Fun fact, Natalie Portman's [Bacon/Erdős](https://en.wikipedia.org/wiki/Erd%C5%91s%E2%80%93Bacon_number) number is lower than Kevin Bacon's, but not lower than Paul Erdős's.

We can repeat this with the other two tables. One thing is, we don't have a natural key for the `title_principals` table, so we should go ahead and add an automatic autoincrement column to that table, if we don't, Postgrex will not be happy and we won't be able to search the table.

    :::psql
    data_imdb=# alter table title_principals
    data_imdb-# add column id
    data_imdb-# serial primary key;
    ALTER TABLE

Once we've added an id column to the table, we can add the schema file `/data_munger/lib/data_munger/title_principal.ex` with the contents:

    :::elixir
    defmodule DataMunger.TitlePrincipal do
      use Ecto.Schema
      import Ecto.Changeset
      alias DataMunger.TitlePrincipal

      schema "title_principals" do
        field :nconst, :string
        field :tconst, :string
        field :category, :string
        field :characters, :string
        field :ordering, :integer
      end

      @doc false
      def changeset(%TitlePrincipal{} = title, attrs) do
        title
        |> cast(attrs, [:nconst,
                        :category,
                        :tconst,
                        :characters,
                        :ordering])
        |> validate_required([:nconst, :tconst])
      end
    end

And test our new schema in IEx:

    :::iex
    iex(6)> Ecto.Query.from(                
    ...(6)> n in DataMunger.TitlePrincipal, 
    ...(6)> where: n.nconst == "nm0000204",
    ...(6)> select: n,
    ...(6)> limit: 1) |>
    ...(6)> DataMunger.ImdbRepo.all()

    01:22:47.033 [debug] QUERY OK source="title_princip....
    SELECT t0."id", t0."nconst", t0."tconst", t0."categ....
    [%DataMunger.TitlePrincipal{__meta__: #Ecto.Schema.....
      category: "actress", characters: "[\"Nina\"]",
      id: 1437846, nconst: "nm0000204", ordering: 9,
      tconst: "tt0185275"}]

I've truncated some of the output, but it should look something like that.

Finally, we add the `title_basics` schema (`/data_munger/lib/data_munger/title_basic.ex`), this time using the `tconst` field as a natural key:

    :::elixir
    defmodule DataMunger.TitleBasic do
      use Ecto.Schema
      import Ecto.Changeset
      alias DataMunger.TitleBasic


      @primary_key{:tconst, :string, []}
      schema "title_basics" do
        field :primary_title, :string
        field :original_title, :string
        field :start_year, :integer
        field :end_year, :integer

      end

      @doc false
      def changeset(%TitleBasic{} = name, attrs) do
        name
        |> cast(attrs, [:nconst,
                        :primary_name,
                        :birth_year,
                        :death_year])
        |> validate_required([:nconst, :primary_name])
      end
    end

And verify that we have access:

    :::iex
    iex(9)> Ecto.Query.from(               
    ...(9)> t in DataMunger.TitleBasic,    
    ...(9)> where: t.tconst == "tt0185275",
    ...(9)> select: t) |>                  
    ...(9)> DataMunger.ImdbRepo.all()      

    03:28:42.722 [debug] QUERY OK source="title_basic.....
    SELECT t0."tconst", t0."primary_title", t0."origi.....
    [%DataMunger.TitleBasic{__meta__: #Ecto.Schema.Me.....
      end_year: nil, original_title: "Developing",
      primary_title: "Developing", start_year: 1994,
      tconst: "tt0185275"}]

Next, we're going to work on how to start filtering through this data. The code up to this point is [avaiable here](https://github.com/philosodad/dataday/tree/2.18), and my first pass at solving all these problems is [available here](https://github.com/philosodad/tiny_bacon_oracle) if you want to read ahead.
