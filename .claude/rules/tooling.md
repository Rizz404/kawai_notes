# Terminal & Tooling

Shell: **PowerShell only** — never bash or Linux-only commands.
No `&&` chaining, no `rm -rf`, no `ls`, no `export`.

| Task            | Tool                          |
| --------------- | ----------------------------- |
| List files      | `eza`                         |
| Find files      | `fd`                          |
| Search content  | `rg`                          |
| Read files      | `Get-Content`                 |
| Replace text    | `sd`                          |
| JSON processing | `jq`                          |
| Git UI          | `lazygit`, `gh`, `delta`      |
| Navigate        | `z` (zoxide), `fzf`, `yazi`   |
| Monitor         | `btm`, `procs`, `dust`, `duf` |

Never open interactive or pager tools that cannot be closed by the AI:
`bat`, `less`, `neovim`, `micro`, `broot`, `jid`, `glow`, `vi`, `vim`, `nano`, `cat`, `grep`, `find`, `dir`, `findstr`
