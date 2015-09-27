i=0;

# Force la régénération des graphiques de data/.
# Évite de se retrouver avec un graphique vide à cause d'une coupure brutale.
shopt -s nullglob
for f in data/*.csv; do
    file=$(echo $f | rev | cut -c 5- | rev)
    gnuplot -e "set terminal svg size 1000,500;set output '$file.svg'; set datafile separator ';';set xdata time;set timefmt '%d/%m/%Y %H:%M:%S';set ylabel 'Température';set xlabel 'Temps';set grid;set style line 101 lc rgb '#808080' lt 1 lw 1;set border 3 front ls 101;set tics nomirror out scale 0.75;set key left top;set samples 500;set style line 11 lt 1 lw 1.5 lc rgb '#0072bd';set style line 16 lt 1 lw 1.5 lc rgb '#4dbeee'; plot '$f' using 1:2 with lines linestyle 11 title 'Sonde haut' smooth sbezier, '$f' using 1:3 with lines linestyle 16 title 'Sonde bas' smooth sbezier";
done;

# Copie du contenu des fichiers précédents
cp data.csv data/data.csv.bak 2> /dev/null
cp data.svg data/data.svg.bak 2> /dev/null

# Suppression des liens symbolique
rm -f data.csv 2> /dev/null
rm -f data.svg 2> /dev/null
date=$(date +%Y%m%d%H%M%S)

# Initialisation des fichiers
touch data/data_$date.csv
touch data/data_$date.svg

# Création des liens symboliques fichier horodaté <- input du webservice
ln -s data/data_$date.csv data.csv
ln -s data/data_$date.svg data.svg

# Écoute de modifications du snapshot de la webcam

prev1=-1
prev2=-1
while inotifywait -e close_write output1.jpg; do
    # crop + seuil n/b + fond noir pour l'étirement + étirement | nb digits variable, input fond noir texte blanc | parser que les nbs
    data1=$(convert output1.jpg -crop 165x63+345+185 -threshold 97% -background black -shear -9,0 - | ./ssocr-2.16.3/ssocr -d -1 -b black -f white - | grep -Eo "[0-9]+")
    data2=$(convert output1.jpg -crop 169x58+743+323 -threshold 97% -background black -shear -9,0 - | ./ssocr-2.16.3/ssocr -d -1 -b black -f white - | grep -Eo "[0-9]+")
    # conditionnelle vérifiant le bon format
    echo $data1";"$data2 | grep -E "^[0-9]+;[0-9]+$" > /dev/null
    if [ $? -eq 0 ]; then
	      # si la différence entre les deux sondes est trop grande, on drop l'input
	      diff1=$(echo "$prev1 - $data1" | bc -l | sed 's/-//')
	      diff2=$(echo "$prev2 - $data2" | bc -l | sed 's/-//')
	      if [ $(($prev1+$prev2)) -eq -2 ] || ([ $diff1 -le 3 ] && [ $diff2 -le 3 ]); then
	          line=$(date "+%d/%m/%Y %H:%M:%S")";$data1;$data2"
	          cp output1.jpg data/$data1.$data2.jpg

	          # enregistrement csv
	          echo $line >> data.csv

	          # enregistrement svg toutes les 5 inputs
	          echo $i;
	          if [ $i -eq 0 ]; then
		            gnuplot -e "set terminal svg size 1000,500;set output 'data.svg'; set datafile separator ';';set xdata time;set timefmt '%d/%m/%Y %H:%M:%S';set ylabel 'Température';set xlabel 'Temps';set grid;set style line 101 lc rgb '#808080' lt 1 lw 1;set border 3 front ls 101;set tics nomirror out scale 0.75;set key left top;set samples 500;set style line 11 lt 1 lw 1.5 lc rgb '#0072bd';set style line 16 lt 1 lw 1.5 lc rgb '#4dbeee'; plot 'data.csv' using 1:2 with lines linestyle 11 title 'Sonde haut' smooth sbezier, 'data.csv' using 1:3 with lines linestyle 16 title 'Sonde bas' smooth sbezier"
		            ((i++));
	          else
		            if [ $i -eq 5 ]; then
		                i=0;
		            else
		                ((i++));
		            fi;
	          fi;
	          prev1=$data1
	          prev2=$data2
	      fi;
    fi;
done;
