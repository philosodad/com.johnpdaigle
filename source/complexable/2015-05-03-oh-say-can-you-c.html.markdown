---
title: Oh say can you C?
date: 2015-05-03 11:42 EDT
tags:
---

I've spent the last week working in C, which is a little like spending a week in 1997, and a little like being lost in the wilderness with half of a map and a slightly dysfunctional compass.

Don't get me wrong, I realize that this is not the fault of the language, exactly. It's really more because I'm not used to having to think about memory. I don't, in general, have to think about stack variables or heap variables, because the languages I use deal with that stuff for me. Even Go, which is a compiled language that operates at a fairly low level, deals with memory for you. 

C expects more out of you. In C, no one can hear you scream, because you passed a pointer instead of a pointer to a pointer and now your data is lost in the darkness of the heap. C is hard.

A couple of weeks ago, I worked on an Objective-C implementation of the same basic software, which is essentially a wrapper around OpenSSL. OpenSSL has its own issues, of course. For one thing, it's implemented in C, and for another, it's been under development for about 16 years. But we did manage to get the thing working in Objective-C, and we turned our attention to Perl.

Perl does not have what I would consider to be a working ecdsa library, so we could either implement one, which sounds like a lot of work to me, or implement a C version of the key utilities and wrap it up in SWIG, which should have been a lot less work. After all, we had just written a nice Objective-C wrapper around OpenSSL, which means that all of the necessary functions were there to be reused, just without the conversion to and from Objective-C structures like NSString or NSData. 

Easy, peasy, lemon-squeazy.

Possibly this laissez-faire attitude offended the software gods, because this has been a week of much learning. I've learned why you should pass pointers to pointers instead of pointers, I've fought with three IDEs before running screaming to the command line. I've tried and failed to implement testing frameworks. I have been tested as a developer and C isn't done with me yet.

I hate you, C. I hate you so much.

But at least you aren't Java.
