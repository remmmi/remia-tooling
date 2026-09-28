---
name: simple
description: >
  Replay the last explanation in a concrete register when the user did not
  understand it. Triggers on /simple and on any sign of confusion: "I don't get it",
  "I didn't understand", "what is X", "explain again", "what are you talking about",
  "so what?", "in plain words", "I'm lost", "say that again". NEVER add detail:
  change the register.
---

<!-- PROFILE:START — filled at install time (see INSTALL.md), with the user's consent -->
## User profile

- **Level**: _(not set)_
- **Terms to define upfront**: _(none)_
- **Project stack**: _(not set)_
- **Their layers, in their words**: _(not set)_
<!-- PROFILE:END -->

> If the profile is still "not set", first **offer** to fill it (procedure: `INSTALL.md`, next to
> this file), then apply the protocol. Never write it without the user's consent.

The profile sets the register: level and terms to define → what gets explained upfront;
stack → where the "real named case" comes from; layers → the vocabulary of step 4.

The user did not understand the previous message. The fault lies with the explanation, not
with their reading. The default reply — repeating it with more detail, more rigour, more
length — **makes things worse**.

## The one rule

> Do not re-explain. **Re-anchor.**

An explanation that did not land will not land by adding words. It lands by changing the
entry point. **A long missed explanation is replayed shorter; a short, dense one in
6 short sentences and 110 words at most.** The 4 steps below often take one sentence each.

## 4-step protocol

**1. The verdict first, in one short sentence, unconditional.**
What the user needs to know or do. Not the mechanism. Not the nuance. No parentheses or
definitions in that sentence: they come after.
"Nothing to do on your side, it's fixed." / "Checkout has been broken since Tuesday."
If there is no firm verdict, say so: "I can't decide yet — here is why."

**2. A real, named case.**
Not a generic example, not a metaphor. A real object from the project with its identifier,
a record with its date, a URL they can open. What the screen shows before, what it shows
after. A metaphor **complements** a technical name, it never **replaces** it.

**3. The mechanism, starting from what the end user sees.**
Never from an internal variable name. `MAX_RETRY_SENTINEL` is not an entry point;
"the customer will never see this error message" is.

**4. Vocabulary matched to their layers.**
Use the layers from the profile (otherwise spot the ones they think in: e.g. code, template,
database, translation, configuration, server) and say which one this happens in, in their
words. "It's in the code — not the template, not the database, not the translation."

## Example

**Before (missed)**: "The opcode cache wasn't invalidated after the deploy, so the FPM worker
kept serving stale bytecode; reloading the master purges the shared segment."

**After (re-anchored)**: "One command and it's fixed: `sudo systemctl reload php-fpm`.
What you saw: the `/cart` page still showed the old button although the file was changed.
Why: the server keeps an in-memory copy of the PHP files to go faster (the "cache"); the
command empties that copy. It's on the server side — not the code, not the database."

Verdict first, a real object (`/cart`, the button), the mechanism seen from the screen, one
technical term defined in the same sentence, the layer named. Three lines instead of a wall.

## Forbidden during /simple

- Making it longer. If the first version was 20 lines, the second is 8. If it was one or two
  dense sentences, the second is **6 short sentences, 110 words at most** — remove jargon, don't add
  sections. No headings, no cascade of bold.
- A term left undefined at first use, even an "obvious" one (`override`, `cache`, `seeder`, `hook`).
- An acronym or project-internal name without its role (script, file, bare identifier).
- A decorative box, ASCII diagram, or table that adds nothing a sentence wouldn't.
- "As I said", "actually", "to be precise" — markers of re-explaining, not re-anchoring.

## Check before sending

Four questions, all "yes":

1. Are the first two sentences enough to know what to do?
2. Is every technical term defined at first use, in that same sentence?
3. Is there at least one real named object (identifier, file, URL, date) they can go look at?
4. Is the length right (shorter than the original if it was long, otherwise 6 sentences
   and 110 words at most)? If not, cut:
   the details first, never the verdict or the real object.

## If it misses twice

Do not try a third wording. **Ask**: "Tell me where it loses you — the word, the sentence,
or the why?" A precise question costs less than a third wall of text.

## After each /simple: learn (always with consent)

1. **Log** — append a line to `journal.md`, next to this file (create it if needed):
   `YYYY-MM-DD · what lost them (term, sentence or "the why") · layer`.
   Never secrets, customer data or people's names. The log stays on the machine.
2. **Growing profile** — if a specific term lost them, offer in one line:
   "Shall I add *X* to the terms I define upfront?" On yes, add it to the Profile block,
   "Terms to define upfront" line.
3. **Recurrence** — if the same term appears 3 times or more in the log, flag it:
   "*X* keeps losing you — add it to the project glossary?" (writing only what the user accepts).
