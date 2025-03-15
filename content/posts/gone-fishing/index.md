---
date: '2025-03-14T21:40:30Z'
draft: false
title: Gone FISHing
author: "Mark"
tags: ["fish", "zsh", "bash", "shell"]
keywords: ["fish", "zsh", "bash", "shell"]
description: "Replacing ZSH with FISH"
summary: "Replacing ZSH with FISH"
---

Let's set the scene. You get to work, coffee in hand.
Bright eyed and bushy tailed. For once you are keen to
get stuck in, after all, that `YAML` isn't going to munge itself.
And then, it happens. The pain. You create a new terminal
pane or a `tmux` split and wait. And wait. For the purposes of this story, anywhere
between six and twelve seconds. Every. Single. Time. You. Split. Time stops. You can feel the energy leaving your body. Where
once there was glorious synergy between man and computer, now there is *rage*.

> TLDR; ZSH why u so slow

☝️I am aware that the TLDR came after the intro. It's
*that kind* of post.

After tolerating this for at least 30 seconds I became a very unwilling explorer of a hellscape
of zsh profiling tools, plugin management frameworks and the like. Truly, this is a cursed timeline.

> This is a blameless post, but I do wish to make it clear that culprit was found to be antigen,
the `ancien` zsh plugin manager.

My plugins:
```zsh
antigen bundle git
antigen bundle fzf
antigen bundle pyenv
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle direnv
antigen bundle autojump
antigen bundle zsh-users/zsh-autosuggestions
```

Being a massive sucker for a sunk cost I then invested several irrecovable minutes of
my life looking at other zsh plugin managers before realising
that I hated what I'd become and should just sack off all this
complicated zsh plugin malarky.

> Except, some of that malarky is actually super useful

Saner heads prevailed and I decided to take a step back. What did I actually
need from my shell?

* Gets out of my way
* Gets out of my way
* Does not take between six and twelve seconds to start
* Sane user experience defaults
* Reads my mind[^1]

[^1]: some good autocomplete and suggestion tooling *might* suffice in lieu of mind reading

Fortified with my list and a burning desire to not do any real work I headed off to investigate
my options...

## Chapter Two: :fish:

Turns out that there are plenty of other shells out there - some really cool, new (to me), hip things like [OIL](https://oils.pub/cross-ref.html#OSH)
or [nushell](https://www.nushell.sh); however, I landed straight away on [Fish](https://fishshell.com).


### Getting Started

On :apple: devices with homebrew installing fish is simple:
`brew install fish`

Changing the default shell is also a breeze:

```bash
# find out where your fish lives
which fish
/opt/homebrew/bin/fish

#TODO: write a joke about fishy hermit crabs
chsh -s /opt/homebrew/bin/fish
```

#### Configuring

Fish has some interesting features, one of which is that it supports interactively updating Fish's config.

For instance; adding homebrew installed applications to the user's path:

```bash
# run me for profit
fish_add_path /opt/homebrew/bin
```

Fish config on a mac lives in `~/.config/fish/` by default. It supports `conf.d` for breaking apart or
organising larger configurations

#### Aliases and Env variables

Setting environment variables is simple; as before this may be done
interactively or in your fish configuration files. 

Here's an example of adding the `SSH_AUTH_SOCK` env var for the 1password ssh agent:

```fish
set -x SSH_AUTH_SOCK ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

Aliases are similarly simple:

```fish
# You didn't think we'd do a whole blog post
# without mentioning Kubernetes, did you?
alias k='kubectl'
```

### Deep Sea Fishing

So it's safe to say that Fish became a usable Shell quite quickly
for me. However, I've used BASH for over twenty years. I'm institutionalised.

Here's a few helpers to make life a bit more bareable.

#### !!

```fish
➜  cat functions/last_history_item.fish
#!/usr/bin/env fish

function last_history_item
    echo $history[1]
end
```
This can be called like so:

```fish
abbr -a !! --position anywhere --function last_history_item
```

Note that this is using a new feature, `abbr`. Sadly not a nordic pop band;
abbrieviations are a way to have fish replace words with other words.

> Hey, that sounds like aliases

You'd be right, but there are some differences. `abbr` shows the **full** command in your history,
which is super handy and abbreviations are not expanded in scripts.

Here's an `abbr` for moving up two parent directories:

```fish
abbr -a ... --position command --function parent_of_parent
```

and the corresponding function:

```fish
#!/usr/bin/env fish

function last_history_item
    echo $history[1]
end

```

Note that these helper functions live in their own files:

```fish
➜  pwd
/Users/msh/.config/fish

➜  tree .
.
├── completions
│   ├── docker.fish -> /Applications/OrbStack.app/Contents/MacOS/../Resources/completions/docker.fish
│   ├── kubectl.fish -> /Applications/OrbStack.app/Contents/MacOS/../Resources/completions/kubectl.fish
│   └── tenv.fish
├── conf.d
│   ├── completions.fish
│   └── rustup.fish
├── config.fish
├── fish_variables
└── functions
    ├── last_history_item.fish
    ├── parent_of_parent.fish
    └── theme_gruvbox.fish

4 directories, 10 files
```

 ## Chapter Three: Supplementing Fish

I'll maybe break these down in later posts; but to complete the setup I used the following:

zsh autojump replaced with [zoxide](https://github.com/ajeetdsouza/zoxide).

fzf with shell history replaced with [atuin](https://github.com/atuinsh/atuin).

[starship](https://starship.rs) for the prompt.

[uv](https://docs.astral.sh/uv/reference/cli/) to replace pyenv.
