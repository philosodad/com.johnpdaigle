---
title: From Keys to PEM in Elixir
date: 2014-12-22 16:16 EST
tags:
---

I'm on vacation right now, which means I'm working, but not really *working* working. In particular, I'm putting together the [elixir library](https://github.com/philosodad/bitpay-elixir) for [BitPay](https://bitpay.com/), which is a project I've wanted to jump on for a couple of months now.

[Elixir](http://elixir-lang.org/) is essentially [Erlang](http://www.erlang.org/) for Rubyists. It's a fun language to write in (at least, I find it fun) but it can be pretty challenging if you aren't used to functional programming in general and Erlang in particular. The reason for this is that some of the libraries you end up needing are Erlang libraries, so you have to be able to hack a little Erlang to do what you want to do in Elixir. It's a little like CoffeeScript that way.

My main language is Ruby, with CoffeeScript/JavaScript in a distant second. So when I started the Elixir library it made sense to take the Ruby library as a starting point and try to copy from one to the other. 

The first task that I had to do was to figure out how to get Elixir to generate a .pem string of an Elliptic curve private key. This is a requirement of all of the libraries, it's an assumption that we will save the key in this format. In Ruby, creating a brand new pem looks like this:

    :::ruby
    def generate_pem
      key = OpenSSL::PKey::EC.new("secp256k1")
      key.generate_key
      key.to_pem
    end

Because Ruby has pretty excellent bindings to the OpenSSL library. In elixir, I had to jump through a few more hoops. Here's the same code in Elixir:

    :::elixir
    def generate_pem do
      keys |>
      entity_from_keys |>
      der_encode_entity |>
      pem_encode_der
    end
    defp keys, 
      do: :crypto.generate_key(:ecdh, :secp256k1)
    defp entity_from_keys({public, private}) do
      {:ECPrivateKey,
        1,
        :binary.bin_to_list(private),
        {:namedCurve, {1, 3, 132, 0, 10}},
        {0, public}}
    end       
    defp der_encode_entity(ec_entity), 
      do: :public_key.der_encode(
        :ECPrivateKey, 
        ec_entity)
    defp pem_encode_der(der_encoded), 
      do: :public_key.pem_encode(
        [{:ECPrivateKey, 
          der_encoded,
          :not_encrypted}])

This looks like a lot more code, but of course I could have written the private functions into the public function, as they are all one line functions. It was sort of a design choice, I like using the pipe operator. And in fact, originally, the code I had looked a lot more like this:

    :::elixir
    def generate_pem do
      {public, private} = :crypto.
                           generate_key(
                             :ecdh,
                             :secp256k2)
      entity = {:ECprivateKey,
                 1,
                 :binary.bin_to_list(private)
                 {:namedCurve, 
                  {1, 3, 132, 0, 10}},
                 {0, public}}
      der_en = :public_key.der_encode(
                :ECPrivateKey,
                entity)
      :public_key.pem_encode(
         [{:ECPrivateKey,
           der_en,
           :not_encrypted}])
    end

Which would have saved me a lot of lines. But I think the first version is a little more readable, because it gives you more intent, generate the keys, create an entity, DER encode that entity, then encode the result of that into a PEM. Each step feeds smoothly into the next. I could do the same thing using anonymous functions in the second case, but that would have generated code that was hard to read.

So that was where I ended up. I suppose the real question is how did I get there, because it wasn't particularly trivial. 

I spent a lot of time in iex, Elixir's REPL, and a lot of time reading Erlang documentation. I ended up attacking the problem from two directions. According to the Erlang documentation for [public\_key](http://erlang.org/doc/man/public_key.html), this is the signature for `public\_key:pem\_encode`:

    :::erlang
    pem_encode(PemEntries) -> binary()

Which wasn't terribly useful to me, because I wasn't sure what a PemEntries input should look like. The documentation just told me that it was a `pem_entry()`, which wasn't terribly helpful. However, since I had a Ruby Library that would generate a PEM, I decided to go the other direction and use `pem_decode`:

    :::erlang
    pem_decode(PemBin) -> [pem_entry()]

In iex, that looked like:

    :::elixir
    ex(347)> :public_key.pem_decode pem
    [{:ECPrivateKey,
      <<48, 116, ...>>,
      :not_encrypted}]

Which meant that to create the pem file, I needed to figure out what the binary in the second term was. Erlang documentation said I needed a `DER or encrypted DER`, so, again working backwards, I assumed it was a DER. `der_decode` required:

    :::erlang
    der_decode(Asn1type, Der) -> term()

The documentation for `pem_entry` had the first term listed as a `pki_asn1_type()`, so I guessed I could reuse the :ECPrivateKey from the previous output and ran:

    :::elixir
    iex(348)> [{type, der, _}] = :public_key.pem_decode pem
    [{:ECPrivateKey,
      <<48, 116, 2,...>>,
      :not_encrypted}]
    iex(349)> :public_key.der_decode(type, der)
    {:ECPrivateKey, 1,
     [153, 197, 18, 51,..],
     {:namedCurve, {1, 3, 132, 0, 10}},
     {0,
      <<4, 35, 56, 210,...>>}}

I wasn't entirely sure what the thing was that had been returned, but my guess (bolstered by a little messing around in iex), was that the output from `der_decode` was the input to `der_encode`, and in that case I was looking at the Erlang representation of an EC private key. [The public\_key users guide](http://www.erlang.org/doc/apps/public_key/users_guide.html) has the following description of EC public key:

    :::erlang
    #'ECPrivateKey'{
          version,       % integer()
          privateKey,    % octet_string()  
          parameters,    % der_encoded() - {
            'EcpkParameters', #'ECParameters'{}} |
            {'EcpkParameters', {namedCurve, oid()}} |
            {'EcpkParameters', 'NULL'} % Inherited by CA
          publicKey      % bitstring()
    }.

So now I was in pretty good shape. Going now from the other direction, looking in the [crypto](http://erlang.org/doc/man/crypto.html) library, `crypto:generate_keys` has this signature:

    :::erlang
    generate_key(Type, Params) -> {PublicKey, PrivKeyOut}
    Type = dh | ecdh | srp
    Params = dh_params() | ecdh_params() ...

And chasing down the definition of `ecdh_params` I found:

    :::erlang
    ecdh_params() =  ec_named_curve() | ec_explicit_curve()

With a little iex hacking:

    :::elixir
    iex(350)> :crypto.generate_key(:ecdh, :secp256k1)
    {<<4, 110, 141, 241,...>>,
     <<77, 235, 81, 108, 207,...>>} 

Which is half of what I needed to get the ECPrivate key entity, the first returned parameter being the publicKey bitstring. The answer to how to turn the private key binary into an octet\_string was actually in the elixir documentation, in the [String](http://elixir-lang.org/docs/stable/elixir/String.html) module. So now I could generate keys, turn them into an entity, encode that entity into DER, then encode that DER into PEM, by running the steps backwards.

In retrospect, this looks pretty simple. What was hardest for me was changing how I was thinking about the problem. In Ruby, you look for objects that have methods that return things that you want, based on the state of the object. So the OpenSSL object has the method, and I initialize the object with the parameters I want in order to set up a state in which the object can be sent a request to essentially output a display of itself, the PEM. In Elixir/Erlang, the modules contain functions and each function has a fairly specific and small job to do. The 'Aha' moment for me was when I started solving the problem backwards. Every "encode" function had a corresponding "decode" function, and that allowed me to start at the end and work my way back. I don't know how universal that is going to be as an approach, it could be that some functions don't have reverse functions.

In his [book on Elixir](https://pragprog.com/book/elixir/programming-elixir), Dave Thomas suggests a different way of looking at programming: looking at programming as *transforming data*. Maybe the real insight that solved this problem was that, when I stopped looking for objects and just started thinking about the output I wanted and how to generate it from any starting point. That started sort of a recursive algorithm: I knew how to get a from b, then b from c, then c from d, and finally the whole process bottomed out with d being generated from known constants. This approach stood me in good stead when I started the next problem, which was generating the BitPay "SIN" number from the output of my pem generator. The code for the whole library is [on github](https://github.com/philosodad/bitpay-elixir). 

