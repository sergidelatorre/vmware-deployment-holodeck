cd C:\Users\Administrator\Documents\vmware-deployment-holodeck\vmware-deployment-holodeck
git stash save "Saving my work"
git fetch origin
git reset --hard origin/main
git stash pop # Reapply stashed changes (if needed)
