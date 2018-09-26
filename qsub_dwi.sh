#!/bin/sh

# This is a BIAC template script for jobs on the cluster
# You have to provide the Experiment on command line  
# when you submit the job the cluster.
#
# >  qsub -v EXPERIMENT=Dummy.01  script.sh args
#
# There are 2 USER sections 
#  1. USER DIRECTIVE: If you want mail notifications when
#     your job is completed or fails you need to set the 
#     correct email address.
#		   
#  2. USER SCRIPT: Add the user script in this section.
#     Within this section you can access your experiment 
#     folder using $EXPERIMENT. All paths are relative to this variable
#     eg: $EXPERIMENT/Data $EXPERIMENT/Analysis	
#     By default all terminal output is routed to the " Analysis "
#     folder under the Experiment directory i.e. $EXPERIMENT/Analysis
#     To change this path, set the OUTDIR variable in this section
#     to another location under your experiment folder
#     eg: OUTDIR=$EXPERIMENT/Analysis/GridOut 	
#     By default on successful completion the job will return 0
#     If you need to set another return code, set the RETURNCODE
#     variable in this section. To avoid conflict with system return 
#     codes, set a RETURNCODE higher than 100.
#     eg: RETURNCODE=110
#     Arguments to the USER SCRIPT are accessible in the usual fashion
#     eg:  $1 $2 $3
# The remaining sections are setup related and don't require
# modifications for most scripts. They are critical for access
# to your data  	 

# --- BEGIN GLOBAL DIRECTIVE -- 
#$ -S /bin/sh
#$ -o $HOME/$JOB_NAME.$JOB_ID.out
#$ -e $HOME/$JOB_NAME.$JOB_ID.out
# -- END GLOBAL DIRECTIVE -- 

# -- BEGIN PRE-USER --
#Name of experiment whose data you want to access 
EXPERIMENT=${EXPERIMENT:?"Experiment not provided"}

source /etc/biac_sge.sh

EXPERIMENT=`findexp $EXPERIMENT`
EXPERIMENT=${EXPERIMENT:?"Returned NULL Experiment"}

if [ $EXPERIMENT = "ERROR" ]
then
	exit 32
else                                                                                                                                                                                                                                                                                                                                                                                                      
#Timestamp
echo "----JOB [$JOB_NAME.$JOB_ID] START [`date`] on HOST [$HOSTNAME]----" 
# -- END PRE-USER --
# **********************************************************

# -- BEGIN USER DIRECTIVE --
# Send notifications to the following address
#$ -M swd4@duke.edu

# -- END USER DIRECTIVE --

# -- BEGIN USER SCRIPT --
# User script goes here


# to prevent tmp folder from being saved to home
cd /mnt/BIAC/munin3.dhe.duke.edu/Simon/Bilateral.01/Analysis

SUBJ=$1
SUBJ2=$2
RUN=$3
RUN2=$4
T1RUN=$5

echo $SUBJ >> qsubBilat.txt

OUTPUT=${EXPERIMENT}/Data/Preprocessing/${SUBJ2}
mkdir -p ${OUTPUT}
MAINOUTPUT=${EXPERIMENT}/Data


# code as 1 to turn ON section, code as 0 to turn OFF
MERGE=1
DENOISE=1
PREPROC=1
SNR=1
MEASURES=1
FTTGEN=1
ACTSEEDING=1
ROIS=1
ACTCONNECTOME=1
SIFTACTCONNECTOME=1
CLEANUP=0


# prefix key:

# m = merged
# b = skull-stripped via bet
# d = denoised via dwidenoise
# e = eddy-corrected via dwipreprocess
# k = add initial mask via bet 
# c = bias-corrected via dwibiascorrect

# n = noise output from dwidenoise
# f = first step in calculating mean bvalues
# mbv = mean bvalue calculated from fsl

# c = bias-corrected via dwibiascorrect
# out_sfwm = Output single-fibre WM response text file
# out_gm = Output GM response text file
# out_csf = Output CSF response text file
# 5TT1 = 1st img in 5TT file


if [ $MERGE = 1 ]; then
	# resample the BIAC DTI image to match the dimensions under which it was encoded 
	mri_convert -rt cubic -vs 1.8 1.8 1.8 ${EXPERIMENT}/Data/Anat/${SUBJ}/bia5_${SUBJ2}_${RUN}.nii.gz ${OUTPUT}/resampled_${SUBJ2}_${RUN}.nii.gz
	mri_convert -rt cubic -vs 1.8 1.8 1.8 ${EXPERIMENT}/Data/Anat/${SUBJ}/bia5_${SUBJ2}_${RUN2}.nii.gz ${OUTPUT}/resampled_${SUBJ2}_${RUN2}.nii.gz

	# extract the bvecs/bvals 
	extractdiffdirs --fsl ${EXPERIMENT}/Data/Anat/${SUBJ}/bia5_${SUBJ2}_${RUN}.bxh ${OUTPUT}/bia5_${SUBJ2}_${RUN}_bvecs ${OUTPUT}/bia5_${SUBJ2}_${RUN}_bvals
	extractdiffdirs --fsl ${EXPERIMENT}/Data/Anat/${SUBJ}/bia5_${SUBJ2}_${RUN2}.bxh ${OUTPUT}/bia5_${SUBJ2}_${RUN2}_bvecs ${OUTPUT}/bia5_${SUBJ2}_${RUN2}_bvals

	# merge the bvec and bval files
	paste -d"\t" ${OUTPUT}/bia5_${SUBJ2}_${RUN}_bvecs ${OUTPUT}/bia5_${SUBJ2}_${RUN2}_bvecs > ${OUTPUT}/bia5_${SUBJ2}_bvecs
	paste -d"\t" ${OUTPUT}/bia5_${SUBJ2}_${RUN}_bvals ${OUTPUT}/bia5_${SUBJ2}_${RUN2}_bvals > ${OUTPUT}/bia5_${SUBJ2}_bvals

	# merge two imaging files
	fslmerge -t ${OUTPUT}/m${SUBJ2}_dwi.nii.gz ${OUTPUT}/resampled_${SUBJ2}_${RUN}.nii.gz ${OUTPUT}/resampled_${SUBJ2}_${RUN2}.nii.gz
else
	echo "Skipped 1MERGE"
fi


if [ $DENOISE = 1 ]; then
	# slight skullstrip prior to denoising for speed
	bet ${OUTPUT}/m${SUBJ2}_dwi.nii.gz ${OUTPUT}/bm${SUBJ2}_dwi.nii.gz -f 0.1 -F

	# denoise dwi
	dwidenoise ${OUTPUT}/bm${SUBJ2}_dwi.nii.gz ${OUTPUT}/dbm${SUBJ2}_dwi.nii.gz -noise ${OUTPUT}/n${SUBJ2}_dwi.nii.gz -force 
else
	echo "Skipped 2DENOISE"
fi


if [ $SNR = 1 ]; then
	# first step in calculating mean b values to get SNR
	fslroi ${OUTPUT}/m${SUBJ2}_dwi.nii.gz ${OUTPUT}/fdb${SUBJ2}_dwi.nii.gz 1 136

	# calculate mean b values to get SNR
	fslmaths -dt input ${OUTPUT}/fdb${SUBJ2}_dwi.nii.gz -Tmean ${OUTPUT}/mbv${SUBJ2}_dwi.nii.gz -odt input

	# calculate SNR
	fslmaths -dt input ${OUTPUT}/mbv${SUBJ2}_dwi.nii.gz -div ${OUTPUT}/n${SUBJ2}_dwi.nii.gz ${OUTPUT}/SNR${SUBJ2}

	rm -f ${OUTPUT}/fdb${SUBJ2}_dwi.nii.gz
	rm -f ${OUTPUT}/mbv${SUBJ2}_dwi.nii.gz
else 
	echo "Skipped 3SNR"
fi


if [ $PREPROC = 1 ]; then
	# dwipreprocess -- eddy field correction
	dwipreproc ${OUTPUT}/dbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/edbm${SUBJ2}_dwi.nii.gz -rpe_none -pe_dir AP -fslgrad ${OUTPUT}/bia5_${SUBJ2}_bvecs ${OUTPUT}/bia5_${SUBJ2}_bvals -export_grad_fsl ${OUTPUT}/e${SUBJ2}_bvecs ${OUTPUT}/e${SUBJ2}_bvals  -force -tempdir /mnt/BIAC/munin3.dhe.duke.edu/Simon/Bilateral.01/Analysis

	# create an initial mask via bet
	bet ${OUTPUT}/edbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/kedbm${SUBJ2}_dwi.nii.gz -f 0.2 -F -m

	# bias-field correction
	dwibiascorrect -ants -mask ${OUTPUT}/kedbm${SUBJ2}_dwi_mask.nii.gz ${OUTPUT}/kedbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/ckedbm${SUBJ2}_dwi.nii.gz -fslgrad ${OUTPUT}/e${SUBJ2}_bvecs ${OUTPUT}/e${SUBJ2}_bvals  -force

	# create a better mask with the bias-corrected info
	dwi2mask ${OUTPUT}/ckedbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/ckedbm${SUBJ2}_dwi_mask.nii.gz -fslgrad ${OUTPUT}/e${SUBJ2}_bvecs ${OUTPUT}/e${SUBJ2}_bvals -force 
else
	echo "Skipped 4PREPROC"
fi
			

if [ $MEASURES = 1 ]; then
	# create tensor, create FA/RD/AD
	dwi2tensor -mask ${OUTPUT}/ckedbm${SUBJ2}_dwi_mask.nii.gz ${OUTPUT}/ckedbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/ckedbm${SUBJ2}_dwi_tensor.nii.gz -fslgrad ${OUTPUT}/e${SUBJ2}_bvecs ${OUTPUT}/e${SUBJ2}_bvals  -force 
	tensor2metric ${OUTPUT}/ckedbm${SUBJ2}_dwi_tensor.nii.gz -fa ${OUTPUT}/ckedbm${SUBJ2}_dwi_FA.nii.gz -rd ${OUTPUT}/ckedbm${SUBJ2}_dwi_RD.nii.gz -ad ${OUTPUT}/ckedbm${SUBJ2}_dwi_AD.nii.gz -force

	# get the response function
	dwi2response tournier ${OUTPUT}/ckedbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/${SUBJ2}_dwi_out.txt -fslgrad ${OUTPUT}/e${SUBJ2}_bvecs ${OUTPUT}/e${SUBJ2}_bvals -force
	# response function for wm/gm/csf
	dwi2response dhollander ${OUTPUT}/ckedbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/${SUBJ2}_dwi_sfwm.txt ${OUTPUT}/${SUBJ2}_dwi_gm.txt ${OUTPUT}/${SUBJ2}_dwi_csf.txt -fslgrad ${OUTPUT}/e${SUBJ2}_bvecs ${OUTPUT}/e${SUBJ2}_bvals -force

	# acquiring FOD
	dwi2fod csd ${OUTPUT}/ckedbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/${SUBJ2}_dwi_out.txt ${OUTPUT}/${SUBJ2}_dwi_FOD.nii.gz -mask ${OUTPUT}/ckedbm${SUBJ2}_dwi_mask.nii.gz -fslgrad ${OUTPUT}/e${SUBJ2}_bvecs ${OUTPUT}/e${SUBJ2}_bvals -force
else
	echo "Skipped 5MEASURES"
fi


if [ $FTTGEN = 1 ]; then
	# CREATING 5TT FOR USE OF ACT IN tckgen & SIFT
	# run 5ttgen fsl on the raw T1 (NOT SKULLSTRIPPED) using the -nocrop option to keep the dimensions from the input raw T1 on the output 5ttgen image.
	flirt -in {EXPERIMENT}/Data/Anat/${SUBJ}/bia5_${SUBJ2}_${T1RUN}.nii.gz -ref ${OUTPUT}/${SUBJ2}_dwi_b0.nii.gz -out ${OUTPUT}/${SUBJ2}_anat -omat ${OUTPUT}/${SUBJ2}_anat.mat -bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6  -interp trilinear
	5ttgen fsl ${OUTPUT}/${SUBJ2}_anat.nii.gz ${OUTPUT}/tt_${SUBJ2}.mif -nocrop -force
	5tt2gmwmi ${OUTPUT}/tt_${SUBJ2}.mif ${OUTPUT}/tt_${SUBJ2}_GMWMI.mif
else
	echo "Skipped 6FTTGEN"
fi

																																													  
if [ $ACTSEEDING = 1 ]; then
	# seeding done at random within a mask image
	tckgen ${OUTPUT}/${SUBJ2}_dwi_FOD.nii.gz -seed_image ${OUTPUT}/ckedbm${SUBJ2}_dwi_mask.nii.gz  ${OUTPUT}/${SUBJ2}_dwi_seed_image_ACT.tck -select 10M -maxlength 250 -fslgrad ${OUTPUT}/e${SUBJ2}_bvecs ${OUTPUT}/e${SUBJ2}_bvals -act ${OUTPUT}/tt_${SUBJ2}.mif -seed_gmwmi ${OUTPUT}/tt_${SUBJ2}_GMWMI.mif -force
	tcksift ${OUTPUT}/${SUBJ2}_dwi_seed_image_ACT.tck ${OUTPUT}/${SUBJ2}_dwi_FOD.nii.gz ${OUTPUT}/${SUBJ2}_dwi_SIFT_ACT.tck -fd_scale_gm -act ${OUTPUT}/${SUBJ2}_5tt.mif -term_number 1M -force 
else
	echo "Skipped 7ACTSEEDING"
fi


if [ $ROIS = 1 ]; then
	# generate the b0 
	fslroi ${OUTPUT}/ckedbm${SUBJ2}_dwi.nii.gz ${OUTPUT}/${SUBJ2}_dwi_b0.nii.gz 0 1
	bet ${OUTPUT}/${SUBJ2}_dwi_b0.nii.gz ${OUTPUT}/${SUBJ2}_dwi_b0.nii.gz -f 0.1

	# registration: MNI to native space
	flirt -in /usr/local/packages/fsl-5.0.6/data/standard/MNI152_T1_2mm_brain -ref ${OUTPUT}/${SUBJ2}_dwi_b0.nii.gz -out ${OUTPUT}/${SUBJ2}_dwi_MNI_to_native -omat ${OUTPUT}/${SUBJ2}_dwi_MNI_to_native.mat -bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp nearestneighbour
	flirt -in ${EXPERIMENT}/Scripts/HOAsp.nii -ref ${OUTPUT}/${SUBJ2}_dwi_b0.nii.gz -out ${OUTPUT}/${SUBJ2}_dwi_HOAsp -applyxfm -init ${OUTPUT}/${SUBJ2}_dwi_MNI_to_native.mat -bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp nearestneighbour
	# flirt -in ${EXPERIMENT}/Scripts/HOA100_LR.nii.gz -ref ${OUTPUT}/${SUBJ2}_dwi_b0.nii.gz -out ${OUTPUT}/${SUBJ2}_b0_HOA100_LR -applyxfm -init ${OUTPUT}/${SUBJ2}_dwi_MNI_to_native.mat -bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp nearestneighbour
else
	echo "Skipped 8ROIS"
fi 


if [ $ACTCONNECTOME =  1 ]; then 
	# tcksample used to get values of associated image (in this case, FA) along tracks
	tcksample ${OUTPUT}/${SUBJ2}_dwi_seed_image_ACT.tck ${OUTPUT}/ckedbm${SUBJ2}_dwi_FA.nii.gz ${OUTPUT}/${SUBJ2}_dwi_FA_mean_tracks.csv -stat_tck mean
	tck2connectome ${OUTPUT}/${SUBJ2}_dwi_seed_image_ACT.tck ${OUTPUT}/${SUBJ2}_dwi_HOAsp.nii.gz ${OUTPUT}/${SUBJ2}_STRconnectome_SIFT.csv  -force 
	tck2connectome ${OUTPUT}/${SUBJ2}_dwi_seed_image_ACT.tck ${OUTPUT}/${SUBJ2}_dwi_HOAsp.nii.gz ${OUTPUT}/${SUBJ2}_FAconnectome_SIFT.csv -scale_file ${OUTPUT}/${SUBJ2}_dwi_FA_mean_tracks.csv -stat_edge mean
else
	echo "Skipped 9ACTCONNECTOME"
fi


if [ $SIFTACTCONNECTOME =  1 ]; then 
	tcksample ${OUTPUT}/${SUBJ2}_dwi_SIFT_ACT.tck ${OUTPUT}/ckedbm${SUBJ2}_dwi_FA.nii.gz ${OUTPUT}/${SUBJ2}_dwi_SIFT_ACT_FA_mean_tracks.csv -stat_tck mean
	tck2connectome ${OUTPUT}/${SUBJ2}_dwi_SIFT_ACT.tck ${OUTPUT}/${SUBJ2}_dwi_HOAsp.nii.gz ${OUTPUT}/${SUBJ2}_STRconnectome_SIFT.csv  -force 
	tck2connectome ${OUTPUT}/${SUBJ2}_dwi_SIFT_ACT.tck ${OUTPUT}/${SUBJ2}_dwi_HOAsp.nii.gz ${OUTPUT}/${SUBJ2}_FAconnectome_SIFT.csv -scale_file ${OUTPUT}/${SUBJ2}_dwi_SIFT_ACT_FA_mean_tracks.csv -stat_edge mean
else
	echo "Skipped 10SIFTACTCONNECTOME"
fi


if [ $CLEANUP = 1 ]; then
	rm -f ${OUTPUT}/bm${SUBJ2}_dwi.nii.gz
	rm -f ${OUTPUT}/dbm${SUBJ2}_dwi.nii.gz
	rm -f ${OUTPUT}/edbm${SUBJ2}_dwi.nii.gz
	rm -f ${OUTPUT}/kedbm${SUBJ2}_dwi.nii.gz
	rm -f ${OUTPUT}/kedbm${SUBJ2}_dwi_mask.nii.gz

else 
	echo "Skipped 11CLEANUP"
fi

 
OUTDIR=${EXPERIMENT}/Data/Preprocessing/Logs
mkdir -p $OUTDIR

# -- END USER SCRIPT -- #

# **********************************************************hands-on
# -- BEGIN POST-USER -- 
echo "----JOB [$JOB_NAME.$JOB_ID] STOP [`date`]----" 
#OUTDIR=${OUTDIR:-$EXPERIMENT/Analysis} 
mv $HOME/$JOB_NAME.$JOB_ID.out $OUTDIR/$JOB_NAME.$JOB_ID.out	 
RETURNCODE=${RETURNCODE:-0}
exit $RETURNCODE
fi
# -- END POST USER-- 
