#!/bin/bash
# Checks that OPENROUTER_API_KEY is available, without printing it.
# Exit 0 = ready (in the environment, or exported in a shell profile). Exit 1 = the user must add it.
if [ -n "$OPENROUTER_API_KEY" ]; then
  echo "OK: OPENROUTER_API_KEY is set in the environment"
  exit 0
fi
for f in ~/.zshrc ~/.zprofile ~/.bashrc ~/.bash_profile; do
  if grep -qE '^[[:space:]]*export[[:space:]]+OPENROUTER_API_KEY=.{8,}' "$f" 2>/dev/null; then
    echo "OK: OPENROUTER_API_KEY is exported in $f (open a new terminal, or run: source $f)"
    exit 0
  fi
done
echo "MISSING: OPENROUTER_API_KEY is not set"
echo "Ask the user to add this line to ~/.zshrc, then open a new terminal:"
echo "  export OPENROUTER_API_KEY='<their-openrouter-key>'"
exit 1
