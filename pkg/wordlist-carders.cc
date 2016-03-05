[mirrors]
http://downloads.skullsecurity.org/passwords/$wordlist.txt.bz2

[vars]
filesize=8936
sha512=ddbb883d861dc6698c83192f971f6925ffffde636446c117abb2c628ae04a150f38a33e5bcf63eff35ab5699e1e85d3710a01069bd6f04976e59a163962a7ea7
wordlist=carders.cc

[build]
dest="$butch_install_dir""$butch_prefix"/share/wordlists
mkdir -p "$dest"
bzcat "$C"/"$BUTCH_TARBALL" > "$dest"/"$wordlist".txt
