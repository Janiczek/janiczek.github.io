# Notes from Elm Camp 2024

[![1](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240618_201509638.jpg)](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240618_201509638.jpg)

I'm writing this on the plane from London to Prague, as we're waiting for delayed takeoff due to thunderstorms over Czech Republic. (EDIT: A day later, I'm now finishing this on my couch back in Ostrava.)

I've spent an amazing week in the English countryside, among roughly 40(?) Elm-minded folks. Many of them are people I interact with almost daily on the Elm Slack or the Incremental Elm Discord, but for many of them this was the first time I could assign a face to a name! Same with my coworkers, John and Wolfgang. This alone made the event very special. Say what you want about online communication tools, in my mind meeting in person will always be vastly superior, at least in the friendship-forming aspect.

The venue and surrounding nature were breathtaking, the food was delicious, the accomodation was comfortable, the travel... we don't speak about the travel.

[![2](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240619_095622515.jpg)](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240619_095622515.jpg)

The venue had a piano, which I appreciated very much. I like being around people without neccessarily having to hold a conversation, and this was one way to do that. Did you know there are a bunch of talented musicians in the Elm community? Mario was my partner in crime in improvising Coldplay stuff by ear, Rupert wowed me with his ability to read sheet music, Georges and Leonardo are awesome singers and I just couldn't stop smiling when everybody joined in. James showed us his compositions, because of course he's composing. Why am I even surprised. Leo showed off a bit of his dancing. Did you know Mark can draw like nobody's business? Shout out also to one moment of kindness in particular: Mario stopping our round robin of who will play the piano next and instead taking the role of a mentor and teaching Janine the "anybody can play the piano: black keys are a pentatonic scale and will sound good together no matter which ones you choose" trick. Made me think about selfishness and unselfishness and actively bringing people into your circle and I appreciate Mario all that more for it.

On the music note, I also had a synthy jam with Georges, but we both kept trying to master our instruments enough to get something nice going on, and didn't succeed on the first try. I'm sure we'll try again one day and sound better :)

[![3](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240619_105619108.jpg)](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240619_105619108.jpg)

We had a bonfire on two occassions, which was very nice. I had some great conversations with Jeroen and Janine about parenthood and the varying social support for parents in different countries. (Also, I've been told the Japanese version of Love Is Blind is just the right amount of bizzare. Might want to check it out.)

Relatedly, I loved the banter from Ryan, the friendly Gleam+Lustre digs between Hayleigh and Jeroen (and Jeroen's dry, on-the-edge humour all around), John's all-around energy and witty remarks, Mario's Evan impressions seconds before Evan comes to the room and Mario is forced to repeat and explain... The mood was electric, everybody is just so smart and friendly, Elm Camp was really something special.

The sessions! Oh the sessions. People pitched in topics they would like to talk about, learn more about, discuss, hack on, get help with, and folks flowed in and out of those sessions as their interest led them. There were some almost keynote-like sessions that basically stole attention from all the other sessions in their timeslot (Evan's and Mario's), but that was very well expected.

[![4](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240619_185508914.jpg)](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240619_185508914.jpg)

I've held a few sessions myself (elm-bend, elm-syntax-type-inference, stealing sourcemaps from Gren, how to combat Html.Lazy brittleness) and I'm blown away by the amount of ideas from everybody and how in some cases it suddenly became very clear which way to go, what needs to be done next, what's the best course of action, to improve the Elm ecosystem, level-up the community and so on.

The below is a little list of exactly that - ideas and tasks I don't want to forget, aimed at nobody in particular, but I would love to take some of these steps and perhaps others would like to as well:

- Html.Lazy brittleness
  - Make a patch to the compiled elm/virtual-dom JS that checks for Elm equality in the unhappy path where the referential-equality JS `===` has already failed. If JS `===` fails and Elm `==` succeeds, this is a wasteful render and we should either send an error to Sentry or wherever, or console.warn, or blink the element that got re-rendered. (See below)
  - Show the viability of Chrome Devtools' "Paint flashing" for debugging Html.Lazy
  - Make a blogpost or a video or Elmcraft digital garden page about how to use and not use Html.Lazy. What breaks it, what is risky, what the compiled JS is for various Elm expressions and declarations, etc. Make the missing piece of docs that should have existed in elm/html. Coordinate with Jeroen, he has a draft blogpost about some of this already.
  - Make an experimental patch to elm/virtual-dom that uses the Gren approach: always use Elm `==` instead of the JS `===`. This makes the optimization worse, but removes the brittleness and all the confusion in heads of Elm devs who outside of Html.Lazy didn't need to think about referential equality and how the Elm compiler compiles various Elm snippets.
  - Possibly coordinate with Simon Lydell on having some of these patches in elm-watch.
- Sourcemaps
  - We've got a green light from Evan on possibly, after a specific compiler optimization is merged, having sourcemap generation in Elm compiler itself
  - Until then, we'll make a standalone tool (probably, rather than extend Lamdera or elm-dev, due to having to touch the AST definitions and not making a clean diff) for generating sourcemaps for an Elm codebase. This can be done (tediously but without much brain activity needed) by applying the patch that added sourcemaps to Gren to an Elm compiler fork.
- elm-test
  - Ed Kelly had a need for keeping the equality failure rendering in elm-test while also having a custom failure message. Right now adding a custom failure message removes the equality one. Let's have both!
- elm-bend
  - I need to continue on translating various Elm AST nodes to Bend. Right now I'm stuck on case..of expressions (the AST.Optimized node is too tailored to JS and not useful to me. I'll need the AST.Canonical one.), but there are a bunch of lower hanging fruits for anybody interested in dipping their toes into Elm compiler development.
- elm-syntax-type-inference
  - Again, case..of is missing, alongside let expressions and then maybe some other stuff. It seems like we're nearing the finish line!
  - But also, from some discussions with Jeroen, Mario and others it seems like maybe elm-review could get the type inference from other sources. The performance of that is unclear so for now we'll keep chugging on with elm-syntax-type-inference.
- elm-grammar
  - Probably could be published.
  - Mark has given me a cool usecase for these dynamic parsers: developing, testing and iterating on your EBNF grammar in a web interface, regex101-style. Might be worth spinning up a quick application hosted on Github Pages or whatever.
- Elm Store pattern
  - A cool experiment would be to show how Elm apps could work with data streaming in from the server via WebSockets. (Outside Lamdera. Lamdera makes it trivial.) Right now frontends usually pretend the data they got from the backend is up-to-date even though it isn't. What would it look like if we had auto-update of the loaded data, or notifying the user about new data available on the server ("this table has new data now, reload by clicking this button")? What kind of backend do you need? GraphQL subscriptions? Some other WebSocket solution? Would be great to see end-to-end.
  - I could have done a better job explaining the Store pattern - better differentiate between the essentials (a record of RemoteData-like API responses, shared between pages) and the rest (Page.Foo.dataDependencies : List DataDependency etc.). Maybe revise the repo or something?

There's probably more and I'm already forgetting stuff. Didn't even mention all the cool stuff that others had in their talks, but I'm also not sure what is sworn by secrecy and what isn't :) All in all I have a great feeling coming home from Elm Camp: there's so much cool stuff happening everywhere. The future is bright, and I can't wait to see it happen.

Thanks to the organizers for making an awesome event and getting the community together. Katja, Mario, Hayleigh, Wolfgang, James, I appreciate you! Thanks to all the Elm people who made it so enjoyable to be there. You're awesome, everybody.

Oh and here's to meeting in a year! Maybe in the Czech Republic this time, wink wink?

[![5](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240619_185811942.jpg)](/assets/images/2024-06-22-notes-from-elm-camp-2024/IMG_20240619_185811942.jpg)
