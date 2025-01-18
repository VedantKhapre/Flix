#!/bin/sh

query=$(echo "$1" | sed 's/ /+/g')
query=$(printf '%s' "$*" | tr ' ' '+' )
echo "Searching for $query"

movie=$(curl -s "https://1337x.pics/xsearch?q=$query&sort=seeders" | grep -Eo "torrent\/[0-9]{7}\/[a-zA-Z0-9?-]*" | head -n 1)
echo "Movie Found: $movie"

magnet=$(curl -s https://1337x.pics/$movie/ | grep -Po "magnet:\?xt=urn:btih:[a-zA-Z0-9]*")
echo "Links Fetched: $magnet"

peerflix -k $magnet 
