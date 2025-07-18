# Go to the repo folder
cd ~/devtools/n8n-server

# Discard all local changes and match the remote branch
git fetch origin
git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)