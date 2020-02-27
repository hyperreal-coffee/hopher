# Hopher: Haskell Gopher Protocol Client

[Gopher protocol](https://en.wikipedia.org/wiki/Gopher_%28protocol%29) client
written in Haskell, implemented according to [RFC
1436](https://tools.ietf.org/html/rfc1436) and
[Gopher+](https://gopher.floodgap.com/gopher/gw?a=gopher%3A%2F%2Fgopher.floodgap.com%2F0%2Fgopher%2Ftech%2Fgopherplus.txt)
technical/protocoal specifications.

## Alpha

This is a project in alpha. It is not fully functional. It is currently a demo.
This is a project that is helping me learn a few things, namely Haskell, but I
intend to make this a really good Gopher client. I got the idea to make a
Gopher client because the default `gopher` client in Ubuntu was lacking and I
wanted to provide fixes and improvements.

## Try it out!

Compile it with `stack build` and then try it out with
`stack exec hopher -- sdf.org 70 phlogs`.

Controls:

  * Next menu item is `j`
  * Previous menu item is `k`
  * Scroll left is the left arrow and `h`
  * Scroll right is the right arrow and `l`
  * Quit is `q`
  * Page down and page up keys scrolls page up and down
  * Arrow up scrolls up
  * Arrow down scrolls down
  * `home` scrolls to beginning of the page
  * `end` scrolls to beginning of the page
