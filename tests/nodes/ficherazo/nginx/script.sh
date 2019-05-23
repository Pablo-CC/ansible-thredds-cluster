#!/bin/bash

fecha="11/14/2018"
hora_inicio="13:44"
hora_final="13:57"
title=nginx_16GB
metrics=('bytes_in' 'bytes_out' 'pkts_in' 'pkts_out' 'cpu_idle' 'cpu_system' 'cpu_user' 'cpu_wio' 'mem_buffers' 'mem_cached' 'mem_free')
regexp="wn019|wn020|wn021|wn022"
nodes="wn019.macc.unican.es|meteo,wn020.macc.unican.es|meteo,wn021.macc.unican.es|meteo,wn022.macc.unican.es|meteo"

for metric in "${metrics[@]}"
do
  wget "meteo.unican.es/ganglia/graph.php?r=hour&z=xlarge&title=$metric&mreg[]=^$metric$&hreg[]=$regexp&aggregate=1&hl=$nodes&cs=$fecha+$hora_inicio+&ce=$fecha+$hora_final&csv=1" -O $metric.csv
  wget "meteo.unican.es/ganglia/graph.php?r=hour&z=xlarge&title=$metric&mreg[]=^$metric$&hreg[]=$regexp&aggregate=1&hl=$nodes&cs=$fecha+$hora_inicio+&ce=$fecha+$hora_final" -O $metric.png
done
