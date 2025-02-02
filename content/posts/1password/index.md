---
title: "Why I'm now using 1Password"
date: "2022-06-22"
author: "Mark"
tags: ["1Password", "secrets"]
keywords: ["1Password", "secrets"]
description: "Ravings about 1Password"
draft: false

---

# Howdy 👋

I recently purchased an _idevice_. "Fantastic", I hear you say, but what's that
got to do with the title of this post?

For years I've been an ardent [KeePassXC](https://keepassxc.org) user, syncing
database files between devices using [Syncthing](https://syncthing.net) or
similar self hosted tools and annoying everyone with the warm glow of smug self
reliance. Sadly, Idevices don't like that kind of thing. It's iCloud or the
highway for syncing files. Not wanting to iCloud all the things I decided to
check out the big bad world of cloud hosted secrets management.

> Spoiler, I put nearly all my secrets in the cloud ☁️

While searching online itI discovered there are two big players worth looking
at, 1Password and bitwarden. Bitwarden scored points for self hoåsting and
1Password came with a glowing review from my mate.

# Picking 1Password

I decided to give 1Password some money based on the following features:

* Everything their side is encrypted, with keys supplied by the client
* Great reputation across the industry
* CLI tools for accessing secrets
* RBAC and granular sharing capabilities
* Applications for every operating system I use
* Browser extensions for firefox and chrome
* Easy export capability

I started testing the water, moving a few things from KeePassXC into 1Password.

A few days later I threw down money for a 1Password subscription.

Here's why:

### SSH Key Management 🔑

> This one is a bit of a game changer... This has changed my workflows. I no
> longer have keys per device. Instead, keys exist per service and _context_.

1Password has an [SSH Agent built
in](https://developer.1Password.com/docs/ssh/get-started) and can manage SSH
keys. The docs are easy to use and clear.

#### Making SSH key management usable

Use the `nightly` version of the 1Password application. If you don't sessions
won't persist and you will be requested for auth on each connection. Not cool if
your Terraform or Ansible are using SSH.

Set SSH_AUTH_SOCK variable in your rc file or similar:

```bash
# without SSH_AUTH_SOCK being set you won't be able to list keys using ssh-add -l
# Note the path is for MacOS only
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1Password/t/agent.sock
```

### Secrets Automation 🤖

Taking 1Password a step towards [Hashicorp Vault](https://www.vaultproject.io), 
[ secrets automation](https://developer.1Password.com/docs/connect/) gives your
infra the ability to consume a private REST API.

### Fastmail Integration 📧

1Password has [worked with fastmail](https://1Password.com/fastmail/) to create
automatic unique email addresses per account.

This is pretty cool!

### CLI Config File Rendering 🏗️

I mostly use [direnv](https://direnv.net) and the [1Password CLI
tool](https://1Password.com/downloads/command-line/), however, it's nice to have
[config
rendering](https://developer.1Password.com/docs/cli/secrets-config-files)
available.

```bash
database:
    host: http://localhost
    port: 5432
    username: op://prod/mysql/username
    password: op://prod/mysql/password
```

### Item Templates 🍪

If you need to create custom templates for new entries in your vault [1Password
has you covered](https://developer.1Password.com/docs/cli/item-template-json).

## Travel Mode

[Travel Mode](https://support.1Password.com/travel-mode/) makes certain vaults
unavailable when you are travelling. Won't protect you from Mossad, but will
give you piece of mind in normal travel situations...

![obligatory xkcd](https://imgs.xkcd.com/comics/security.png)

## Summary

Two months using this service and I keep finding useful features. It's well
worth the money!
