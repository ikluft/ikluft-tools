## Shuffle programs

These are multiple programming language implementations of a program to shuffle lines of text from the input to random order in the output. Current implementations are in [C++](c++), [Perl](perl), [Python](python), [Rust](rust) and [Go](go).

This was to support a random drawing at a club meeting. (Not a raffle. Just a random selection.) The premise is that selection of random attendees at a meeting are picked from a list of those who registered in advance. In order to simplify the process of drawing another random name if any selected are not present at the meeting. I suggested making a randomly-shuffled list of registered users and start taking names from the top until an attendee is picked. It's mathematically the same result as doing a random drawing of names until someone present is found, but is much faster and more convenient.

I made multiple language implementations to resolve any concerns about sufficient randomness in each language's libraries. Though this doesn't require cryptographic-quality randomness, it must noticeably shuffle the list.

In a bit of a whimsical tradition which adds some actually unnecessary randomness, I send a number of separate randomly-shuffled lists as attachments in an email to the person who's handling the drawing. They understand ahead of time the instructions to pick a number randomly from 1-n (number of files, one each for programming language implementation) and use the attachment with that number. After the drawing, I tell them which programming language implementation produced the file they used. Yeah, it's just for fun, in a very techie way.  😀
