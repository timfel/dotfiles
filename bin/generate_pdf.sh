sleep 10
/usr/bin/import -window root "screen_0.jpg"
for i in `seq -w 1 $1`; do
    xdotool key space 
    sleep 3
    /usr/bin/import -window root "screen_${i}.jpg"
done
convert "screen_*.jpg" presentation_to_pdf.pdf
rm screen_*.jpg

