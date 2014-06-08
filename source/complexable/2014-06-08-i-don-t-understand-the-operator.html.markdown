---
title: I don't understand the |> operator
date: 2014-06-08 10:48 -04:00
tags:
---

I'm a little confused by the Elixir pipe operator. 

This works as expected:

    :::elixir
    'woRd' |>
    to_string |>
    String.downcase |>
    to_char_list |>
    Enum.sort

This returns 'dorw', which is what I expect.

This does not work as expected:

    :::elixir
    to_string 'woRd' |>
    String.downcase |>
    to_char_list |>
    Enum.sort

Which returns

    :::iex
    ** (FunctionClauseError) no function clause 
       matching in String.Unicode.do_downcase/1
        (elixir) unicode/unicode.ex:49: 
          String.Unicode.do_downcase('woRd')
        (elixir) unicode/unicode.ex:46: 
          String.Unicode.downcase/1

Shouldn't `to_string 'word'` return the same thing as `'word' |> to_string`?
