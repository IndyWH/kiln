# Secrets

Owner, 17 Nov 2026, after a forum reply pointed out that everything Claude reads goes to Anthropic: Claude may not read or change the owner's secrets. Two layers, both installed by the owner with `sudo sidekick/install.sh`:

1. **Kiln's rules hook** (`sidekick/kiln_rules.py`, `SECRET_PATHS`): refuses Bash commands, file edits and the read tools (Read, Grep, Glob) that name a secret; wildcards and braces that reach one; whole-folder readers and copiers (grep -r, rg, tar, cp -r, rsync, find -exec) given a parent of one; relative names after a cd it cannot follow; and programs that hand secrets out without a path (gh auth token, secret-tool, pass, gpg --export-secret-keys, git credential fill, snapper diff).
2. **Claude Code's own deny rules** (`sidekick/secrets-settings.json`, installed as `60-kiln-secrets.json` in the machine-wide settings folder): Read and Edit denied for the same list, built from `SECRET_PATHS`. Claude Code applies them to its file tools and to file commands it recognises in Bash; nothing in user or project settings can override them.

The list: ssh and gpg keys, the keyring and its backup in ~/.cache/kiln-keyring-backup, password store, .netrc, git credentials, .pki, cloud and kube configs, gh's token, the browser profiles (Chrome, Chromium, Brave, Firefox), Claude Desktop's data, Claude Code's own credentials and ~/.claude.json, shell histories, and /home/.snapshots (every home snapshot holds copies).

## What it is not

A fence against accidents and the obvious ways, not a wall. Claude runs as the owner and has sudo, so a script that builds a path itself, or a program not on the list, can still reach a secret. The machine rules say never to try. Claude Code's sandbox would make it a wall for shell commands, but it also stops sudo, so it stays off. The real protection for keys is a passphrase on them, and tokens kept in the locked keyring.

Known gaps, after two reviews (17 Nov 2026): a folder held in a variable (`grep -r x $d`), `env -C` or `sudo -D` to change folder, a cd inside a subshell or one that fails, and programs not on the lists. The rule is in the machine rules so that the model does not go looking for these.

Also on the list, by the owner's choice: the system's own secrets, which sudo reaches (password hashes in /etc/shadow and /etc/gshadow, Wi-Fi passwords in /etc/NetworkManager/system-connections, this machine's ssh host keys in /etc/ssh, and /root). Cost: no whole-folder search of /etc in one go; search the folder inside it. A new browser, password manager or token file later must be added to `SECRET_PATHS` by hand; `secrets-settings.json` is rebuilt from it and a test checks the two match.

The sentry (a script, not Claude) reads one DNS setting from the Firefox and Chrome profiles; its report reaches Claude at session start. A sentry finding about ~/.ssh/authorized_keys is now the owner's to look into: Claude cannot open the file.

## Costs

- Any command text that names these places is refused, including a commit message or a heredoc. Write such text with the Write tool and commit with `git commit -F`.
- Keyring, browser-profile and Claude Desktop settings work is now the owner's, by hand.
- Also refused: wildcards over a parent of a secret (`ls ~/*`, `ls ~/.config/*`), anything naming /home/.snapshots (use `snapper -c home list`), `snapper -c home diff` (status still works), `printenv`, bare `env`, `history`, whole-system `find / ... -exec`, and a `find` over the home folder in any command that also uses `$( )`. After a `cd` the hook cannot follow, a word that is exactly gh, chromium, google-chrome, mozilla, Claude or config.json.
- The hook now also runs before every read. If it breaks (it fails closed), Claude cannot even read until it is fixed.
- `restore` to a snapshot from before the install removes all of this; run the installer again afterwards.

## Back out, by hand

    sudo rm /etc/claude-code/managed-settings.d/60-kiln-secrets.json

then check out the commit before this change in ~/Projects/kiln and run `sudo sidekick/install.sh` again. The repo is the record; `git log -- lessons/secrets.md` finds the commit.

## Checking it works

After installing: `/status` should name the machine-wide settings file as a source, and `/permissions` list the deny rules. The owner puts a small text file with a made-up word in one secret folder; then Claude is asked to read it by an @-mention (tests the deny rules alone), to `grep -r` the word from the home folder (tests the hook), and a helper agent to search the home folder. All three must be refused. Then the file is deleted. If the account ever gets settings from claude.ai's console, those win and the machine-wide files are skipped: check `/status` again then.
