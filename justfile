# Workshop track helpers. Run from anywhere in the repo.
# Requires the Instruqt CLI: https://docs.instruqt.com
# Authenticate once with `instruqt auth login` before any push.

# Default recipe.
default: push

# First-time push: instruqt/track.yml's `id:` is currently "". The CLI
# will create the track on Instruqt under the slug
# `introduction-to-temporal-nexus`, then write the assigned id back into
# track.yml. Commit that change so subsequent pushes update the same
# track instead of creating a new one.
#
# If the first push fails with a slug-already-exists error, the slug is
# taken in your team. Pick a new one in track.yml (e.g.
# `introduction-to-temporal-nexus-test`) and run `just push` again.
#
# Push the Instruqt track. Reads instruqt/track.yml.
push:
    cd instruqt && instruqt track push

# First-push helper. Reminds you to commit the id Instruqt writes back.
init:
    cd instruqt && instruqt track push
    @echo ""
    @echo "If this was the first push, instruqt/track.yml now has an"
    @echo "assigned 'id:'. Commit it:"
    @echo "    git add instruqt/track.yml"
    @echo "    git commit -S -m 'Pin Instruqt track id'"

# Pull the track from Instruqt into the local instruqt/ directory.
pull:
    cd instruqt && instruqt track pull

# Validate the track locally without pushing.
validate:
    cd instruqt && instruqt track validate

# Show the diff between local track and what is on Instruqt.
diff:
    cd instruqt && instruqt track diff
