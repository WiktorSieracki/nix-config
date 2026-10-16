
# Nix

- **Installing packages** - I use nix to manage my developement environment. If you need to install some package search for it using `nix search <package>` and run it using `nix run <package>` or `nix-shell -p <package>`. I like using cli tools if i can do something with agent.
- **Persistent environments** - If you need something to be persistent, you can add `flake.nix` to the project while also adding `nix develop` to the project. This will allow you to have a reproducible development environment for your project.

# T3code

- **Using t3code tools** - When using t3code you should prefer to use tools that are available in t3code environment like web preview or device preview, for more information about t3code you can check out the [source code](https://github.com/pingdotgg/t3code).

# Programming

- **Language** - Always type code in english, comments, prs, commit messages
- **Divide and conquer** - I really like divide and conquer, so I try to break down problems into smaller pieces and solve them one by one testing each small change.
- **Testing** - I also like to write tests for my code, even if it's just a small script. It helps me catch bugs early and makes me feel more confident about my code.
- **Definition of done** - We should always specify what "done" means for a task and set up a way to measure progress.
- **Worktrees** - I like utilizing worktrees when its implemented in a smart way not taking too much disk space or copying too much data.
- **Implementing changes** - If you can easily implement a change, do it and show me the proof of doneness
- **Using subagents** - For subagent use the latest models in 3 different price ranges (for example opus, sonnet, haiku), look for them in the web to have the most up to date information
