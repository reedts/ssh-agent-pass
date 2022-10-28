# ssh-agent-pass
A zinit plugin extending OMZ's ssh-agent to unlock ssh keys with pass.

## Synopsis
Working with many ssh-keys for different devices on a regular basis can be quite tedious - that's what `ssh-agent` is for.

While OMZ's ssh-agent plugin automatically starts the agent as well as load selected identities, loading keys
that are secured by a passphrase will require the user to input the passphrase manually.

Given an identity `id_X` to add to the agent, `ssh-agent-pass` will check if it can find a corresponding `pass` entry
`ssh/<YOUR_HOSTNAME>/id_X`. If found it is used to automatically unlock the key and add it to the agent.

This is currently completely tailored to the way I myself organise the my ssh-keys/pass entries.
If I have time, I might add more customisability to this system.

Contributions are welcome!

## Settings

**IMPORTANT: put these settings _before_ the line that loads the plugin**

Any options adopted from OMZ's ssh-agent plugin work the same as before. Their `zstyle` context
is changed to `:plugin:zinit:ssh-agent-pass` to match the new plugin name.

### `add-all`

To automatically **add all identities** in your `$HOME/.ssh` folder beginning with the prefix `id_` add the following
to your zshrc file:

```zsh
zstyle :plugin:zinit::ssh-agent-pass add-all yes
```

### `agent-forwarding`

To enable **agent forwarding support** add the following to your zshrc file:

```zsh
zstyle :plugin:zinit:ssh-agent-pass agent-forwarding yes
```

### `helper`

To set an **external helper** to ask for the passwords and possibly store
them in the system keychain use the `helper` style. For example:

```zsh
zstyle :plugin:zinit:ssh-agent-pass helper ksshaskpass
```

### `identities`

To **load multiple identities** use the `identities` style (**this has no effect
if the `lazy` setting is enabled**). For example:

```zsh
zstyle :plugin:zinit:ssh-agent-pass identities id_rsa id_rsa2 id_github
```

**NOTE:** the identities may be an absolute path if they are somewhere other than
`~/.ssh`. For example:

```zsh
zstyle :plugin:zinit:ssh-agent-pass identities ~/.config/ssh/id_rsa ~/.config/ssh/id_rsa2 ~/.config/ssh/id_github
# which can be simplified to
zstyle :plugin:zinit:ssh-agent-pass identities ~/.config/ssh/{id_rsa,id_rsa2,id_github}
```

### `lazy`

To **NOT load any identities on start** use the `lazy` setting. This is particularly
useful when combined with the `AddKeysToAgent` setting (available since OpenSSH 7.2),
since it allows to enter the password only on first use. _NOTE: you can know your
OpenSSH version with `ssh -V`._

```zsh
zstyle :plugin:zinit:ssh-agent-pass lazy yes
```

You can enable `AddKeysToAgent` by passing `-o AddKeysToAgent=yes` to the `ssh` command,
or by adding `AddKeysToAgent yes` to your `~/.ssh/config` file [1].
See the [OpenSSH 7.2 Release Notes](http://www.openssh.com/txt/release-7.2).

### `lifetime`

To **set the maximum lifetime of the identities**, use the `lifetime` style.
The lifetime may be specified in seconds or as described in sshd_config(5)
(see _TIME FORMATS_). If left unspecified, the default lifetime is forever.

```zsh
zstyle :plugin:zinit:ssh-agent-pass lifetime 4h
```

### `pass`

To customise the pass location/command use:

```zsh
zstyle :plugin:zinit:ssh-agent-pass pass /path/to/pass
```

### `quiet`

To silence the plugin, use the following setting:

```zsh
zstyle :plugin:zinit:ssh-agent-pass quiet yes
```

### `ssh-add-args`

To **pass arguments to the `ssh-add` command** that adds the identities on startup,
use the `ssh-add-args` setting. You can pass multiple arguments separated by spaces:

```zsh
zstyle :plugin:zinit:ssh-agent-pass ssh-add-args -K -c -a /run/user/1000/ssh-auth
```

These will then be passed the the `ssh-add` call as if written directly. The example
above will turn into:

```zsh
ssh-add -K -c -a /run/user/1000/ssh-auth <identities>
```

For valid `ssh-add` arguments run `ssh-add --help` or `man ssh-add`.

## Credits
Based on [OMZ's ssh-agent plugin](https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/ssh-agent/README.md) which in turn relies
on code from [Joseph M. Reagle](https://www.cygwin.com/ml/cygwin/2001-06/msg00537.html).
