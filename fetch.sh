while read line
do
  name=`echo "$line" | cut -f 1 -d " "`
  url=`echo "$line" | cut -f 2 -d " "`
  echo ">>> Fetching $name"
  curl -L "$url" > "vendor/`basename $url`"
done < libraries.txt
