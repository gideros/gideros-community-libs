while read repo
do
  directory=`basename $repo | sed s/\.git$//`
  (cat .gitmodules | grep $repo && (cd vendor/$directory && git pull origin master)) ||
    git submodule add $repo vendor/$directory
done < libraries.txt
