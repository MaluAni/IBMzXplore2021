#!/bin/env bash
#create variables from setup file
datasetloc=`head -1 $1 | tr '[:upper:]' '[:lower:]' | cut -d '=' -f 2`
filespath=`head -2 $1 | tail -1 | cut -d '=' -f 2`
schema=`head -3 $1 | tail -1 | cut -d '=' -f 2`
locurl=`head -4 $1 | tail -1 | cut -d '=' -f 2`
outputmember=`head -5 $1 | tail -1 | cut -d '=' -f 2`
reportloc=`head -6 $1 | tail -1 | cut -d '=' -f 2`
#create work dir and copy files needed
mkdir ~/"$reportloc"
cp ~/Report.md ~/"$reportloc"
mkdir ~/drop6
mkdir -p ~/drop6/work
DIRECTORY=~/drop6
WORKDIRECTORY="$DIRECTORY"/work
echo "connect to 204.90.115.200:5040/DALLASC user ZUSER using ********;" | tee "$WORKDIRECTORY"/temp.sql
echo "connect to 204.90.115.200:5040/DALLASC user ZUSER using ********;" | tee "$WORKDIRECTORY"/tempq.sql
echo "connect to 204.90.115.200:5040/DALLASC user ZUSER using ********;" | tee "$WORKDIRECTORY"/tempc.sql
scp -r "//'$datasetloc'" $DIRECTORY
# get initial data split into header and rest
for file in "$DIRECTORY"/part*; do
    sed -n '1,1p' "$file" >> "$WORKDIRECTORY"/d1header.txt
    done
for file in "$DIRECTORY"/part*; do
    sed -n '2,$p' "$file" >> "$WORKDIRECTORY"/d1output.txt
    done
#assign field len from header to vars
line=`head -1 "$WORKDIRECTORY"/d1header.txt`
partlenhex="$(echo $line | cut -d'|' -f2)"
vendorlenhex="$(echo $line | cut -d'|' -f4)"
yearlenhex="$(echo $line | cut -d'|' -f6)"
orgidlenhex="$(echo $line | cut -d'|' -f8)"
datelenhex="$(echo $line | cut -d'|' -f10)"
taglenhex="$(echo $line | cut -d'|' -f12)"
# convert from hex to dec
partlendec=$((0x${partlenhex}))
vendorlendec=$((0x${vendorlenhex}))
yearlendec=$((0x${yearlenhex}))
orgidlendec=$((0x${orgidlenhex}))
datelendec=$((0x${datelenhex}))
taglendec=$((0x${taglenhex}))

# extract available vendors
grep -E -v ".{$partlendec}303030.{6}" "$WORKDIRECTORY"/d1output.txt | cut -d ':' -f 2 >> "$WORKDIRECTORY"/possvendors.txt
cut -c43-48 "$WORKDIRECTORY"/possvendors.txt | sed 's/../& /g' | sed 's/30/0/;s/31/1/;s/32/2/;s/33/3/;s/34/4/;s/35/5/;s/36/6/;s/37/7/;s/38/8/;s/39/9/;' | sed 's/31/1/;s/32/2/;s/33/3/;s/34/4/;s/35/5/;s/36/6/;s/37/7/;s/38/8/;s/39/9/;' | sed 's/ //g' | sed -e 's/^/000/' >> "$WORKDIRECTORY"/possvendorscodes.txt

# extract eng encrypted eng codes from USS
for line in $(cat "$WORKDIRECTORY"/possvendorscodes.txt)
    do
    ls -a "$filespath"/vendors/"$line"/agents/."$line" | cut -d'.' -f 2 | sed 1,2d >> "$WORKDIRECTORY"/engcodes.txt
    done
# decrypt eng codes
sed 's/j/ /g;s/@/-/g;s/z/K/g;s/y/L/g;s/x/M/g;s/w/N/g;s/v/O/g;s/u/P/g;s/t/Q/g;s/s/R/g;s/0/A/g;s/9/B/g;s/8/C/g;s/7/D/g;s/6/E/g;s/5/F/g;s/4/G/g;s/3/H/g;s/2/I/g;' "$WORKDIRECTORY"/engcodes.txt >> "$WORKDIRECTORY"/engcodestemp.txt
sed 's/r/S/g;s/q/T/g;s/p/U/g;s/o/V/g;s/n/W/g;s/m/X/g;s/l/Y/g;s/k/Z/g;s/1/J/g;' "$WORKDIRECTORY"/engcodestemp.txt >> "$WORKDIRECTORY"/engcodesdec.txt
sed 's/QUEBEC/Q/g;s/ALFA/A/g;s/BRAVO/B/g;s/CHARLIE/C/g;s/DELTA/D/g;s/ECHO/E/g;s/FOXTROT/F/g;s/GOLF/G/g;s/HOTEL/H/g;s/INDIA/I/g;s/JULIETT/J/g;s/KILO/K/g;s/LIMA/L/g;' "$WORKDIRECTORY"/engcodesdec.txt >> "$WORKDIRECTORY"/engcodesdec1.txt
sed 's/MIKE/M/g;s/NOVEMBER/N/g;s/OSCAR/O/g;s/PAPA/P/g;s/ROMEO/R/g;s/SIERRA/S/g;s/TANGO/T/g;s/UNIFORM/U/g;s/VICTOR/V/g;s/WHISKEY/W/g;s/X-RAY/X/g;s/YANKEE/Y/g;s/ZULU/Z/g;' "$WORKDIRECTORY"/engcodesdec1.txt >> "$WORKDIRECTORY"/engcodesdec2.txt
sed 's/ //g' "$WORKDIRECTORY"/engcodesdec2.txt >> "$WORKDIRECTORY"/engcodestemp1.txt
sed 's,.*\(.\{8\}\)$,\1,' "$WORKDIRECTORY"/engcodestemp1.txt >> "$WORKDIRECTORY"/engcodesdec3.txt

 #get locator password from db2 and decrypt locator codes
echo "select REMARKS from sysibm.syscolumns where tbcreator = '$schema' and tbname = 'LOCATORS';" >> "$WORKDIRECTORY"/tempc.sql
java com.ibm.db2.clp.db2 -tvxf "$WORKDIRECTORY"/tempc.sql -z "$WORKDIRECTORY"/locatorspass.txt 

PASSDIR="$WORKDIRECTORY"/locatorspass.txt
passcode=`head -11 $PASSDIR | tail -1 | cut -d" " -f 3`
echo "SELECT DECRYPT_CHAR(LCODE, '$passcode') FROM $schema.LOCATORS;" >> "$WORKDIRECTORY"/temp.sql
java com.ibm.db2.clp.db2 -tvf "$WORKDIRECTORY"/temp.sql >> "$WORKDIRECTORY"/locatornames.txt

tail -n +11 "$WORKDIRECTORY"/locatornames.txt >> "$WORKDIRECTORY"/lcodestemp.txt
sed '$d' "$WORKDIRECTORY"/lcodestemp.txt >> "$WORKDIRECTORY"/lcodestemp1.txt
sed '$d' "$WORKDIRECTORY"/lcodestemp1.txt >> "$WORKDIRECTORY"/lcodestemp2.txt
sed 's/ *$//g' "$WORKDIRECTORY"/lcodestemp2.txt >> "$WORKDIRECTORY"/lcodestemp3.txt
sed 's/ /%20/g' "$WORKDIRECTORY"/lcodestemp3.txt >> "$WORKDIRECTORY"/lcodes.txt


engineers="$WORKDIRECTORY"/lcodes.txt
# get host and port for addresses coords and version
python -c '
import urllib.request, json
f=open("'$WORKDIRECTORY'/data4.html", "a")
url = "'$locurl'"
response = urllib.request.urlopen(url)
data = response.read()    
f.write(data.decode())    
            '
            
startURL=`grep "data-z" "$WORKDIRECTORY"/data4.html | cut -d" " -f 3 | sed -e 's/'\''//g' | sort -t= -k1 | cut -d"=" -f2 | paste -d ":" - - | paste -d "" - - | sed 's/t:/t/g'`

python -c '
import urllib.request, json
f=open("'$WORKDIRECTORY'/data5.html", "a")
url = "'$startURL'"
response = urllib.request.urlopen(url)
data = json.loads(response.read())
f.seek(0)
json.dump(data, f, indent=2)    
           '

grep -e "host" -e "port" -e "path" "$WORKDIRECTORY"/data5.html | sed 's/\"//g' | cut -d":" -f 2 | paste -d":" - - - | sed -e 's/,: /:/g;s/:\//\//g' | cut -d"{" -f 1 | sed 's/ //g' >> "$WORKDIRECTORY"/URLstemp.txt
URLadd=`head -1  "$WORKDIRECTORY"/URLstemp.txt`
URLcoords=`head -2 "$WORKDIRECTORY"/URLstemp.txt | tail -1`
versionURL=`head -3 "$WORKDIRECTORY"/URLstemp.txt | tail -1`

# get eng address code
while IFS= read -r line
    do
        python -c '
import urllib.request, json
f=open("'$WORKDIRECTORY'/data1.json", "a")
file = open("'$engineers'", "r")
url = "http://"+"'$URLadd'"+"'$line'"
try:
    response = urllib.request.urlopen(url)
    data = json.loads(response.read())
    f.seek(0)
    json.dump(data, f, indent=2)    
except:
    print("Error addresses")            '   
    done < $engineers 

sed 's/[\{\}]//g' "$WORKDIRECTORY"/data1.json >> "$WORKDIRECTORY"/temp.txt 
cut -d"," -f 2 "$WORKDIRECTORY"/temp.txt >> "$WORKDIRECTORY"/temp1.txt
cut -d":" -f 2  "$WORKDIRECTORY"/temp1.txt >> "$WORKDIRECTORY"/temp2.txt
sed '/^[[:space:]]*$/d' "$WORKDIRECTORY"/temp2.txt >> "$WORKDIRECTORY"/temp3.txt
sed 's/\"//g' "$WORKDIRECTORY"/temp3.txt >> "$WORKDIRECTORY"/temp4.txt
sed 's/ //g' "$WORKDIRECTORY"/temp4.txt >> "$WORKDIRECTORY"/addresses.txt

# get eng coords
addresses="$WORKDIRECTORY"/addresses.txt
while IFS= read -r line
    do
        python -c '
import urllib.request, json
f=open("'$WORKDIRECTORY'/data2.json", "a")
file = open("'$addresses'", "r")
url = "http://"+"'$URLcoords'"+"'$line'"
try:
    response = urllib.request.urlopen(url)
    data = json.loads(response.read())
    f.seek(0)
    json.dump(data, f, indent=2)    
except:
    print("Error coords")    
            '   
    done < $addresses 

sed 's/[\{\}]//g' "$WORKDIRECTORY"/data2.json >> "$WORKDIRECTORY"/tempj.txt 
sed '/^[[:space:]]*$/d' "$WORKDIRECTORY"/tempj.txt >> "$WORKDIRECTORY"/tempj1.txt
sed 's/\"//g' "$WORKDIRECTORY"/tempj1.txt >> "$WORKDIRECTORY"/tempj2.txt
sed 's/ //g' "$WORKDIRECTORY"/tempj2.txt >> "$WORKDIRECTORY"/tempj3.txt
cut -d":" -f 2 "$WORKDIRECTORY"/tempj3.txt | paste -d " " - - - >> "$WORKDIRECTORY"/coords.txt
# get eng id names and decrypted codes as table and add quotes and commas
echo "SELECT $schema.ENGINEERS.EID, $schema.ENGINEERS.ENAME, DECRYPT_CHAR($schema.LOCATORS.LCODE, '$passcode') FROM $schema.ENGINEERS INNER JOIN $schema.LOCATORS ON $schema.ENGINEERS.EID = $schema.LOCATORS.EID ORDER BY $schema.ENGINEERS.EID;" >> "$WORKDIRECTORY"/tempq.sql
java com.ibm.db2.clp.db2 -tvf "$WORKDIRECTORY"/tempq.sql >> "$WORKDIRECTORY"/concat.txt

tail -n +11 "$WORKDIRECTORY"/concat.txt >> "$WORKDIRECTORY"/tempe.txt
sed '$d' "$WORKDIRECTORY"/tempe.txt >> "$WORKDIRECTORY"/tempe1.txt
sed '$d' "$WORKDIRECTORY"/tempe1.txt >> "$WORKDIRECTORY"/tempe2.txt
sed 's/ *$//g' "$WORKDIRECTORY"/tempe2.txt >> "$WORKDIRECTORY"/eng.txt

paste -d',' "$WORKDIRECTORY"/eng.txt "$WORKDIRECTORY"/coords.txt >> "$WORKDIRECTORY"/final.txt

sed '$!s/$/,/' "$WORKDIRECTORY"/final.txt >> "$WORKDIRECTORY"/tempfinal.txt
awk '{ print $1 }' "$WORKDIRECTORY"/tempfinal.txt >> "$WORKDIRECTORY"/tempfinal1.txt
awk '{ print $2 }' "$WORKDIRECTORY"/tempfinal.txt >> "$WORKDIRECTORY"/tempfinal2.txt
sed 's/^/\"/g;s/$/\"/g' "$WORKDIRECTORY"/tempfinal2.txt >> "$WORKDIRECTORY"/tempfinal2one.txt
awk -F',' '{ print $2 }' "$WORKDIRECTORY"/tempfinal.txt >> "$WORKDIRECTORY"/tempfinal3.txt
awk -F',' '{ print $3 }' "$WORKDIRECTORY"/tempfinal.txt >> "$WORKDIRECTORY"/tempfinal4.txt
awk -F',' '{ print $4 }' "$WORKDIRECTORY"/tempfinal.txt >> "$WORKDIRECTORY"/tempfinal5.txt
awk -F',' '{ print $1 }' "$WORKDIRECTORY"/tempfinal.txt >> "$WORKDIRECTORY"/tempfinal6.txt
awk '{ print $3" "$4" "$5 }' "$WORKDIRECTORY"/tempfinal6.txt >> "$WORKDIRECTORY"/tempfinal7.txt
sed 's/^/\"/g;s/$/\"/g' "$WORKDIRECTORY"/tempfinal7.txt >> "$WORKDIRECTORY"/tempfinal8.txt
sed 's/ \"/\"/g' "$WORKDIRECTORY"/tempfinal8.txt >> "$WORKDIRECTORY"/tempfinal9.txt
paste -d"," "$WORKDIRECTORY"/tempfinal1.txt "$WORKDIRECTORY"/tempfinal2one.txt "$WORKDIRECTORY"/tempfinal9.txt "$WORKDIRECTORY"/tempfinal4.txt "$WORKDIRECTORY"/tempfinal5.txt >> "$WORKDIRECTORY"/submitwithoutheadfoot.txt
sort -t, -k2 "$WORKDIRECTORY"/submitwithoutheadfoot.txt >> "$WORKDIRECTORY"/submitwithoutheadfootsorted.txt
# find boundbox and add to data
sort -nrk1 "$WORKDIRECTORY"/tempfinal4.txt | head -1 >> "$WORKDIRECTORY"/boundbox.txt
sort -nk1 "$WORKDIRECTORY"/tempfinal5.txt | head -1 | sed 's/ /, /' >> "$WORKDIRECTORY"/boundbox.txt
sort -nk1 "$WORKDIRECTORY"/tempfinal4.txt | head -1 >> "$WORKDIRECTORY"/boundbox.txt
sort -nrk1 "$WORKDIRECTORY"/tempfinal5.txt | head -1 | sed 's/ /, /' >> "$WORKDIRECTORY"/boundbox.txt
awk '$1=$1' RS= "$WORKDIRECTORY"/boundbox.txt | sed 's/ , /, /g' >> "$WORKDIRECTORY"/boundboxline.txt

cat "$WORKDIRECTORY"/boundboxline.txt "$WORKDIRECTORY"/submitwithoutheadfootsorted.txt >> "$WORKDIRECTORY"/finalwoversion.txt
echo "Report.md" >> "$WORKDIRECTORY"/finalwoversion.txt
# get version and add to data
python -c '
import urllib.request, json
f=open("'$WORKDIRECTORY'/data3.html", "a")
url = "http://"+"'$versionURL'"
response = urllib.request.urlopen(url)
data = response.read()    
f.write(data.decode())    
            '
sed 's/<dt>//g' "$WORKDIRECTORY"/data3.html >> "$WORKDIRECTORY"/vertemp.txt
sed 's/<dd>//g' "$WORKDIRECTORY"/vertemp.txt >> "$WORKDIRECTORY"/vertemp1.txt
sed 's/<\/dd>//g' "$WORKDIRECTORY"/vertemp1.txt >> "$WORKDIRECTORY"/vertemp2.txt
sed 's/<\/dt>//g' "$WORKDIRECTORY"/vertemp2.txt >> "$WORKDIRECTORY"/vertemp3.txt
host=`head -10 "$WORKDIRECTORY"/vertemp3.txt | tail -1 | sed 's/ //g'`
platform=`head -6 "$WORKDIRECTORY"/vertemp3.txt | tail -1 | sed 's/ //g'`
os=`head -8 "$WORKDIRECTORY"/vertemp3.txt | tail -1 | sed 's/ //g'`
echo "host:"$host" platform:"$platform" os:"$os >> "$WORKDIRECTORY"/contestfinal.txt
cat "$WORKDIRECTORY"/contestfinal.txt "$WORKDIRECTORY"/finalwoversion.txt >> "$WORKDIRECTORY"/submitcontest.txt

zowe zos-files upload ftds "$WORKDIRECTORY/submitcontest.txt" "ZUSER.$outputmember"
#get relevant engineers and modify output file (the 9 relevant vendors don't have USS folders!!)

#delete resources
rm -r $DIRECTORY
