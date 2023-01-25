## Shuffle programs

These are multiple programming language implementations of a program to shuffle lines of text from the input to random order in the output. Current implementations are in [C++17](cpp17), [C++20](cpp20), [Perl](perl), [Python](python), [Rust](rust) and [Go](go). In all cases, they take a file name on the command line, read it and output the lines in randomly-shuffled order.

I didn't make a C implementation. The GNU Core Utilities program "shuf" ([docs](https://www.gnu.org/software/coreutils/manual/html_node/shuf-invocation.html)/[source](https://github.com/coreutils/coreutils/blob/master/src/shuf.c)) already does that.

This was to support a random drawing at a club meeting. (Not a raffle. Just a random selection.) The premise is that selection of random attendees at a meeting are picked from a list of those who registered in advance. In order to simplify the process of drawing another random name if any selected are not present at the meeting. I suggested making a randomly-shuffled list of registered users and start taking names from the top until an attendee is picked. It's mathematically the same result as doing a random drawing of names until someone present is found, but is much faster and more convenient.

In a bit of a whimsical tradition which adds some actually unnecessary randomness, I send a number of separate randomly-shuffled lists as attachments to the member who's handling the drawing. They understand ahead of time the instructions to pick a number randomly from 1-n (number of files, one each for programming language implementation) and use the attachment with that number. After the drawing, I tell them which programming language implementation produced the file they used. This process is automated by the [run-shuffle.sh](run-shuffle.sh) script. Yeah, it's just for fun, in a very techie way. 😀

The technical reason behind multiple language implementations is to resolve any concerns about sufficient randomness in each language's libraries. Though this doesn't require cryptographic-quality randomness, it must noticeably shuffle the list. Actually any single implementation is sufficient to make a randomized list. This way, any bias over specific programming language is removed because the implementation is not known even by the person conducting the drawing until they are informed of it after the drawing.

Or you can include the key file when sending the randomized lists if you trust them to actually randomly pick one of the files as agreed. Then they know which is which immediately. It depends if and how much this matters to your group.

Program dependencies:

* general: date dirname expr printf realpath shuf test (all part of GNU coreutils)
* C++: Gnu C++ compiler, Gnu Make
* Go: Go compiler
* Perl: Perl interpreter
* Python: Python interpreter
* Rust: Rust compiler, cargo
