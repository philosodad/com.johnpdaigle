---
title: "Code Kata: Erehwonian ATM"
date: 2013-06-14 11:02 -04:00
tags:
---

I developed this kata as a pair programming exercise. It's a thinly veiled version of the Roman Numeral Kata with a couple of wrinkles. I introduced the wrinkles to encourage pairs to come up with a plan of attack, and also to provide a small challenge for programmers familiar with the RNK.

Overview
=========

Your client is a bank which is just starting to do business in the ancient city state of Erehwon. They want you to help them write their ATM software, a task that is complicated by the unusual numbering system that the Erewhonians use. This module should convert a balance in U.S. dollars into the equivalent value in Erewhon's currency and numbering system based on the current exchange rate. 

Erehwonian Numbering
---------------

The Erehwonian numbering system is unusual. They use a set of 7 symbols, A, B, E, F, I, J, and O to represent quantities. 

<table border="1">
  <tr><th>Erehwon</th><th>Decimal</th></tr>
  <tr><td>A</td><td>1</td></tr>
  <tr><td>B</td><td>5</td></tr>
  <tr><td>E</td><td>10</td></tr>
  <tr><td>F</td><td>50</td></tr>
  <tr><td>I</td><td>100</td></tr>
  <tr><td>J</td><td>500</td></tr>
  <tr><td>O</td><td>1000</td></tr>
</table>

The symbols can be combined to represent larger entities. The rules can be interpolated from the next table.

<table border="1">
  <tr><th>Erehwon</th><th>Decimal</th></tr>
  <tr><td>A</td><td>1</td></tr>
  <tr><td>AA</td><td>2</td></tr>
  <tr><td>AAA</td><td>3</td></tr>
  <tr><td>AB</td><td>4</td></tr>
  <tr><td>B</td><td>5</td></tr>
  <tr><td>BA</td><td>6</td></tr>
  <tr><td>BAA</td><td>7</td></tr>
  <tr><td>BAAA</td><td>8</td></tr>
  <tr><td>AE</td><td>9</td></tr>
  <tr><td>E</td><td>10</td></tr>
  <tr><td>EE</td><td>20</td></tr>
  <tr><td>EEE</td><td>30</td></tr>
  <tr><td>EF</td><td>40</td></tr>
  <tr><td>F</td><td>50</td></tr>
  <tr><td>FE</td><td>60</td></tr>
  <tr><td>FEE</td><td>70</td></tr>
  <tr><td>FEEE</td><td>80</td></tr>
  <tr><td>EI</td><td>90</td></tr>
  <tr><td>I</td><td>100</td></tr>
  <tr><td>II</td><td>200</td></tr>
  <tr><td>OOIOFEEAB</td><td>2974</td></tr>
</table>

Numbers are created by concatenation of symbols. So "IJEEEBA" represents 400 (IJ) + 30 (EEE) + 5 (B) + 1 (A), or 436. With the exception of the numbers AB (4), AE (9), EF (40), EI (90), IJ (400) and IO (900), no smaller number can ever precede a larger one. The largest number that it is possible to represent using Erehwon's system is 3999. 

Erehwonian Currency
---------

Erewhon uses 5 denominations of currency, the Bang, the Feng, the Jing, the Pong, and the Tung. 4000 Bang make up 1 Feng, 4000 Feng make 1 Jing, 4000 Jing make one Pong, and 4000 Pong make one Tung. The most common unit of currency is the Bang, and the exchange rate is calculated in terms of Bang to the Dollar. 

Technical Notes
-------------

The GNP of Erewhon is significantly less than 4000 Tung, so bank balances exceeding that value are out of scope. It is also not in scope to worry about negative or zero values, a bank account with a negative or zero balance is considered closed and handled by a different part of the system. Partial Bang should round down, except in the case where that would make the bank account zero. 

The ATM software is written in your language of choice. A separate piece of software is responsible for retrieving the balance from the database and querying the balance calculation module, as well as writing the actual results to the screen. The balance calculation module is provided with two numbers, the balance in dollars and the exchange rate, and should output the balance display string.

Acceptance Criteria
=============

Given an exchange rate of 40 (40 Bang to the Dollar), and a bank account balance of $5,321,236.15
When I check my balance in Erewhon,
The screen should display `EAAA Jing, OIIEAA Feng, OIJEFBA Bang`

Extensions
===========

1. Write a program that allows Erewhonians to enter deposit and withdrawal amounts using local currency that will be translated into dollars, based on the current exchange rate. 
1. The website needs to be extended for the residents of Erehwon as well. Stand up a simple web app that allows users to log in and log out based on pre-assigned usernames and passwords.
1. Given a web app with users/passwords and accounts, extend the app to show the last 10 previous transactions (in local currency/numbering). Provide the data in a form that can be used by the web app, the ATM app, or other future applications (for example, return the transaction data using JSON). 
