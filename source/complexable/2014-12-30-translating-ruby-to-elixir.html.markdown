---
title: Translating Ruby to Elixir
date: 2014-12-30 01:00 EST
tags:
---

[Last week](http://www.johnpdaigle.com/complexable/2014/12/22/from-keys-to-pem-in-elixir.html), I wrote about convincing [Elixir](http://elixir-lang.org/) to convert a PEM string using the Erlang [crypto](http://erlang.org/doc/apps/crypto/index.html) and [public\_key](http://www.erlang.org/doc/apps/public_key/index.html) libraries. The reason I wanted to do that in the first place is that I'm writing a library for the [BitPay API](https://bitpay.com/developers) using Elixir, and the library uses the PEM file as a sort of Rosetta Stone for everything else it does, that is, if you have a PEM generated with any library in any language, you can use it to talk to BitPay in any other language. Part of doing that is generating the BitPay SIN number, which is a base58 encoded string, similar to a bitcoin address (so you could use these general instructions and code, with some changes, to generate a bitcoin address).

There are several existing libraries, and my best language is Ruby, so once again I started with the Ruby code as a basis for creating the Elixir code. A quick note about all of these code examples, if you copy/paste them, there's some possibility that you will need to eliminate some line breaks to make them work properly. It should be pretty clear from indentation where to do that.

    :::ruby
    def generate_sin_from_pem(pem = nil)
      # NOTE:  All Digests are calculated against 
      # the binary representation,
      # hence the requirement to use [].pack("H*") 
      # to convert to binary for each step
      key = OpenSSL::PKey::EC.new(pem ||= get_local_pem_file)
      key.public_key.group.
        point_conversion_form = :compressed
      public_key = key.public_key.to_bn.to_s(2)
      step_one = Digest::SHA256.hexdigest(public_key)
      step_two = Digest::RMD160.hexdigest([step_one].
        pack("H*"))
      step_three = "0F02" + step_two
      step_four_a = Digest::SHA256.hexdigest([step_three].
        pack("H*"))
      step_four = Digest::SHA256.hexdigest([step_four_a].
        pack("H*"))
      step_five = step_four[0..7]
      step_six = step_three + step_five
      encode_base58(step_six)
    end
       
My initial attempt at this was to create very much the same code, with a `step_one`, `step_two` and so forth. But what I ended up with quite different. First, an attempt at what the code looked like with lots of intervening variables:

    :::elixir
    def get_sin_from_pem pem do
      public_key = entity_from_pem(pem) |>
                   extract_coordinates |>
                   compress_key |>
                   Base.decode16(public_key) |>
                   elem(1) 
      step_one = :crypto.hash(:sha256, public_key)
      step_two = :crypto.hash(:ripemd160, step_one) |>
                 Base.encode16
      step_three = ("0F02" <> step_two)
      step_three_a = Base.decode16(step_three) |>
                     elem(1)
      step_four_a = :crypto.hash(:sha256, step_three_a)
      step_four = :crypto.hash(:sha256, step_four_a) |>
                  Base.encode16
      step_five = String.slice(step_four, 0..7)
      step_six = step_three <> step_five
      encode_base58 step_six
    end

Which is just as ugly in Elixir as it is in Ruby. For one thing, it doesn't really convey a lot of purpose. Why are we going through all of these steps? What are they for? `step_two` and `step_four` repeat the same code. Most of the step variables are used only once.

But before we discuss how to clean up this code at all, let's have a look at a couple of helper methods. The methods `entity_from_pem`, `extract_coordinates` and `compress_key` are not library methods. `entity_from_pem` is a helper method that wraps around some decoding methods in the Erlang crypto library which produce an Erlang `ECPrivateKey` entity. That entity contains the uncompressed public key as a binary, but in order to compress the key, we need to split the x and y coordinates and evaluate y as an integer. 

    :::elixir
    defp extract_coordinates(ec_entity) do
      elem(ec_entity, 4) |>
      elem(1) |>
      Base.encode16 |>
      split_x_y
    end
    defp split_x_y(uncompressed) do
      {String.slice(uncompressed, 2..65), 
       String.slice(uncompressed, 66..-1)}                                                                   
    end
    defp compress_key({x, y}) do
      convert_y_to_int({x, y}) |>
      return_compressed_key
     end                                                                                                                                                                         
    defp convert_y_to_int({x, y}) do
      ({x, String.to_integer(y, 16)})
    end
    defp return_compressed_key({x, y}) when 
          Integer.is_even(y), do: "02#{x}"                                                                                                    
    defp return_compressed_key({x, y}) when 
          Integer.is_odd(y),  do: "03#{x}"    

The thing that strikes me about this group of methods is how clear the Elixir guard clause syntax makes the compression scheme: when the y coordinate is even, return one thing, when it is odd, return another. It's one of those places where it seems like using a guard clause adds clarity over a conditional.

Back to the main method and its problems with variables: the only variables we seem to actually need are `step_three` and `step_five`, because we combine those two values. So one of the first things I wanted to do was to get rid of a few variables. To get rid of the `public_key` variable, I just needed to feed it into the next function. It would be convenient to use the pipe operator here, but the pipe operator replaces the first argument of the next function, so `public_key` could not be piped directly into the `crypto:hash` function. It can be piped into an anonymous function wrapped around `crypto:hash`, so that we end up with this:

    :::elixir
    def get_sin_from_pem pem do
      step_one = entity_from_pem(pem) |>
                 extract_coordinates |>
                 compress_key |>
                 Base.decode16(public_key) |>
                 elem(1) |>
                 (&(:crypto.hash(:sha256, &1))).()
      step_two = :crypto.hash(:ripemd160, step_one) |>
                 Base.encode16
      step_three = ("0F02" <> step_two)
      step_three_a = Base.decode16(step_three) |>
                     elem(1)
      step_four_a = :crypto.hash(:sha256, step_three_a)
      step_four = :crypto.hash(:sha256, step_four_a) |>
                  Base.encode16
      step_five = String.slice(step_four, 0..7)
      step_six = step_three <> step_five
      encode_base58 step_six
    end

And once that is done, we can get rid of `step_one` by piping the last line into an anonymous wrapper around the next hash function, then eliminate `step_two` by wrapping a function around string concatenation, and so on until we only have the two variables we actually need. That takes us here:

    :::elixir
    def get_sin_from_pem pem do
      step_three = entity_from_pem(pem) |>
                   extract_coordinates |>
                   compress_key |>
                   Base.decode16 |>
                   elem(1) |>
                   (&(:crypto.hash(:sha256, &1))).() |>
                (&(:crypto.hash(:ripemd160, &1))).() |>
                   Base.encode16 |>
                   (&("0F02" <> &1)).()
      step_five = Base.decode16(step_three) |>
                  elem(1) |>
                  (&(:crypto.hash(:sha256, &1))).() |>
                  (&(:crypto.hash(:sha256, &1))).() |>
                  Base.encode16 |>
                  String.slice(step_four, 0..7)
      (step_three <> step_five) |> encode_base58
    end

I could have stopped here (although with some more meaningful names), but naturally I didn't. For one thing, there are still these variables hanging out where they probably aren't needed. For another, there's a pattern that is used twice and can be extracted, where we decode a binary, hash it, then encode it again. Finally, I'm not sure that having all the messy details in the main body of the method enhances readability. I like using anonymous functions and it's good practice to do so, but we use the same pattern for an anonymous function four times, which makes me think that there's a named function to write. The code I ended up with addresses these issues.

    :::elixir
    def get_sin_from_pem pem do
      compressed_public_key(pem) |>
      set_version_type |>
      (&(&1 <> write_checksum &1)).() |>
      encode_base58
    end     

And the code itself transformed a bit from the code we see in the previous example. Looking at the code for `set_version_type`:

    :::elixir
    defp set_version_type public_key do
      digest(public_key, :sha256) |>
      digest(:ripemd160) |>
      (&("0F02" <> &1)).()
    end
    defp digest hex_val, encoding do
      Base.decode16(hex_val) |>
      elem(1) |>
      (&(:crypto.hash(encoding, &1))).() |>
      Base.encode16
    end

I don't know that this code is any easier to understand than the code for `step_three`, but it feels better to me. Rather than encoding and decoding in line, we set an assumption that we're always working with hex values and move the details of how those values are hashed to the `digest` function itself. The code is a little DRYer, and in a good way. It also might be a little clearer that we're executing a data transformation on the compressed public key, so the intent of the code is communicated more clearly.

This brings us to the last transformation, the base58 encoding itself. Here, I didn't follow the Ruby code at all, and I also didn't follow the code in the Base module of Elixir itself (although I probably should have). Instead, I just solved the problem using a simple base conversion algorithm and basic data types.

    :::elixir
    defp encode_base58 string do
      String.to_integer(string, 16) |>
      (&(encode("", &1, digit_list))).()
    end
    
    defp encode(output_string, number, _list) 
                when number <= 0, do: output_string
    defp encode(output_string, number, list) do
      elem(list, rem(number,58)) <> output_string |>
      encode(div(number, 58), list)
    end
    
    defp digit_list do
      #actual digit list is much longer!##
      "123...xyz" |>
      String.split("") |>
      List.to_tuple
    end

Some obvious differences between this code and the Ruby code is that the Ruby code uses iteration, not recursion, and the Ruby code uses a lot more variables. The Elixir solution is a little more elegant to my eye, and it doesn't use any tricks that aren't readily available in Ruby. We could translate the code into Ruby pretty easily:

    :::ruby
    def encode_base58 hex
      #again, this is not the actual 58 character string!
      list = "123...xyz".split("")
      encode("", hex.to_i(16), list)
    end

    def encode output_string, number, list
      return output_string if number <= 0
      encode(list[number%58] + output_string, number/58, list)
    end

Which I actually like a lot better than the current Ruby implementation.

So what did I learn from all of this? The main thing is that, while you can write Ruby in Elixir (to some extent) you really shouldn't. But writing the ruby-esque code got me to a point where I had tests that passed, and once I had that I was able to refactor pretty mercilessly to get to a solution I was a lot more happy with. If I had tried to arrive at the initial solution right away, I think I would have been more or less paralyzed. Also, I spent a good bit of time with both iex and irb open when writing the initial version of the function, because I needed to check, step-by-step, that I was getting the same results in Elixir as I was in Ruby. That sort of exploration is invaluable, but in my case it would have been a lot shorter if I had taken more notes.

You can find the [Ruby](https://github.com/philosodad/ruby-client) or [Elixir](https://github.com/philosodad/bitpay-elixir) code on GitHub.
