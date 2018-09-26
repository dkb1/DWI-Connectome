EXPERIMENT=Bilateral.01



SUBJ=("20180906_23614")
SUBJ2=("23614")
RUNTYPE=("2")


for k in 0;
do
	declare SUBJ=${SUBJ[$k]}
	declare SUBJ2=${SUBJ2[$k]}
	declare type2=${RUNTYPE[$k]}

	case $type2 in
		1) 
			RUNS=("004" "005" "006");;
		2) 
			RUNS=("005" "006" "007")
	esac


	echo $SUBJ
	echo $SUBJ2

	declare RUN=${RUNS[0]}
	declare RUN2=${RUNS[1]}
	declare T1RUN=${RUNS[2]}

	echo $RUN
	echo $RUN2
	echo $T1RUN
		

	qsub -v EXPERIMENT=$EXPERIMENT qsub_Bilateral_dwi.sh ${SUBJ} ${SUBJ2} ${RUN} ${RUN2} ${T1RUN}

done

	
	

