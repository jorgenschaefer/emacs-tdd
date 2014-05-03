A simple global minor mode for Emacs. It runs `recompile` after saving
a buffer, and indicates success or failure in the mode line. The idea
is to use `M-x compile` to run tests, and use this mode for
test-driven development.

- Write a test and save the file
- Watch the test fail as the status line indicator turns red
- Write code and save the file until the status line turns green
- Repeat
