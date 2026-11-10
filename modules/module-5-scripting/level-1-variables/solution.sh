#!/bin/bash
# Reference solution: overwrite greet.sh with a heredoc, as a player would.
cat > greet.sh <<'END'
#!/bin/bash
# greet.sh NAME - say hello to the new team member
name="${1:-stranger}"
echo "Hello, $name!"
END
