#!/bin/bash
#SBATCH --job-name	ReadIndex
#SBATCH --time		0-01:30:00
#SBATCH --mem		4G
#SBATCH --cpus-per-task	1
#SBATCH --error		slurm/RI_%j.out
#SBATCH --output	slurm/RI_%j.out

echo "$(date) on $(hostname)"

if [ -e $EXEDIR/baserefs.sh ]
then
	source $EXEDIR/baserefs.sh
else
	(echo "WARN: Executing without baserefs.sh" 1>&2)
fi

function usage {
echo -e "\
*******************************************
* This script will index a given BAM file *
*******************************************
*
* usage: $0 options:
*
*********************************
*
* Required:
*   -i [FILE]      Input file. Can be specified multiple times.
* Optional:
*   -o [FILE]      Output file.
*
*********************************"
}

while getopts "i:o:" OPTION
do
	FILE=
	case $OPTION in
		i)
			if [ ! -f ${OPTARG} ]; then
				echo "FAIL: Input file $OPTARG does not exist!"
				exit 1
			fi
			if [[ " ${FILE_LIST[@]} " =~ " ${OPTARG} " ]]
			then
				(echo "FAIL: Input file $OPTARG already added. Perhaps you want Read 2?" 1>&2)
				exit 1
			fi
			export INPUT=${OPTARG}
			(echo "INFO: input files \"$INPUT\"" 1>&2)
			;;
		o)
			export OUTPUT=${OPTARG}
			(echo "INFO: output file \"$OUTPUT\"" 1>&2)
			;;
		?)
			echo "FAIL: $0 ${OPTION} ${OPTARG} is not valid!"
			usage
			exit 1
			;;
	esac
done

if [ "$INPUT" == "" ]
then
	(echo "FAIL: Missing required parameter!" 1>&2)
	usage
	exit 1
fi

if [ "$OUTPUT" == "" ]
then
	OUTPUT=echo -ne "${INPUT%.bam}.bai"
	(echo "INFO: Output file \"$OUTPUT\"" 1>&2)
fi

IDN=$(echo $SLURM_JOB_NAME | cut -d'_' -f2)

HEADER="RI"

(echo "$HEADER: ${INPUT} -> ${OUTPUT}" 1>&2)

# Make sure input and target folders exists and that output file does not!
if ! inFile;  then exit $EXIT_IO; fi
if ! outDirs; then exit $EXIT_IO; fi
if ! outFile; then exit $EXIT_IO; fi

module purge
module load SAMtools

CMD="srun $(which samtools) index ${INPUT} ${JOB_TEMP_DIR}/${OUTPUT}"
echo "$HEADER: ${CMD}" | tee -a commands.txt

JOBSTEP=0

scontrol update jobid=${SLURM_JOB_ID} name=${IDN}_Indexing_Reads

if ! ${CMD}; then
	cmdFailed $?
	exit ${JOBSTEP}${EXIT_PR}
fi

# Move output to final location
if ! finalOut; then exit $EXIT_MV; fi

touch ${OUTPUT}.done

#if ! . ${SLSBIN}/transfer.sl ${IDN} ${OUTPUT}; then
#	echo "$HEADER: Transfer index failed!"
#	exit $EXIT_TF
#fi
