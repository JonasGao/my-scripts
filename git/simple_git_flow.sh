git checkout -b rebasing-develop develop
git rebase master
git checkout master
git merge rebasing-develop
git push
git branch -D rebasing-develop
git checkout staging
git merge master
git push