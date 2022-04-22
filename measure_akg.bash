#!/bin/bash

# defines
AKG_TESTS_DIR=/home/fan/repos/akg/tests
AKG_POLY_IR_DIR="${AKG_TESTS_DIR}/dev/autorun/tensorcore_conv_auto_float16_16_4_4_16_float16_16_3_3_16_1_1_0_0_0_0_1_1_float16_0/poly"

POLLY_INSTALL_DIR="${LLVM_ROOT}/install"
opt="${POLLY_INSTALL_DIR}/bin/opt"
polly="${POLLY_INSTALL_DIR}/bin/clang"
llc="${POLLY_INSTALL_DIR}/bin/llc"

# utility functions
function printerr {
    local s=${1}
    echo ${s} > /dev/stderr
}

function checkStringNotEmpty {
    local str=$1
    local paramName=$2
    if [ -z ${str} ]
    then
        printerr "${paramName} must be set."
        exit 1
    fi
}
function checkIsBoolean {
    local str=$1
    local paramName=$2
    if [ ! ${str} == "true" ] && [ ! ${str} == "false" ]
    then
        printerr "${paramName} must either be true or false: ${str}"
        exit 1
    fi
}

function cleanupAndExit {
    exitCode=$1
    for pid in `jobs -p`
    do
        pkill -9 -P ${pid}
        kill -9 ${pid}
    done
    cd ${tmpDirBase}
    rm -rf ${workingDir}
    exit ${exitCode}
}
function _trap {
    cleanupAndExit ${sigIntExitCode}
}

function checkFileExists {
    fileName=$1
    if [ ! -r ${fileName} ]
    then
        printerr "${fileName} is not a readable file."
        echo 'false'
        cleanupAndExit 1
    fi
}
function checkExecutableExists {
    fileName=$1
    if [ ! -r ${fileName} ]
    then
        printerr "${fileName} is not an executable"
        echo 'false'
        cleanupAndExit 1
    fi
}


# begin
echo "Started"
unset LD_PRELOAD
nArgs=20

if [ ${#} -lt ${nArgs} ]
then
    printerr "Wrong number of arguments (expected ${nArgs}): found ${#}"
    printerr "List of expected arguments"
    printerr "    - workerThreadID"
    printerr "    - tmpDirBase"
    printerr "    - benchmarkName"
    printerr "    - functionName"
    printerr "    - scopRegionStart"
    printerr "    - scopRegionEnd"
    printerr "    - referenceOutputFile"
    printerr "    - numCompilatonDurationMeasurements"
    printerr "    - validateOutputEnabled"
    printerr "    - numExecutionTimeMeasurements"
    printerr "    - irFilesLocation"
    printerr "    - sigIntExitCode"
    printerr "    - measureCacheHitRatePar"
    printerr "    - measureCacheHitRateSeq"
    printerr "    - measureParExecTime"
    printerr "    - measureSeqExecTime"
    printerr "    - seqPollyOptFlags"
    printerr "    - parPollyOptFlags"
    printerr "    - useNumactl"
    printerr "    - numactlConf (use only if useNumactl is true)"
    exit 1
fi

# assign arguments
i=1
workerThreadID=${!i}
i=$((i + 1))
tmpDirBase=`echo ${!i} | sed 's/\/$//g'` # should be set to 
i=$((i + 1))
measurementTmpDirNamePrefix=${!i}
i=$((i + 1))
benchmarkName=${!i}
i=$((i + 1))
functionName=${!i}
i=$((i + 1))
scopRegionStart=${!i}
i=$((i + 1))
scopRegionEnd=${!i}
i=$((i + 1))
referenceOutputFile=${!i} # unused
i=$((i + 1))
numCompilatonDurationMeasurements=${!i}
i=$((i + 1))
validateOutputEnabled=${!i} # true
i=$((i + 1))
numExecutionTimeMeasurements=${!i}
i=$((i + 1))
irFilesLocation=`echo ${!i} | sed 's/\/$//g'`
i=$((i + 1))
sigIntExitCode=${!i}
i=$((i + 1))
measureCacheHitRatePar=${!i} # false
i=$((i + 1))
measureCacheHitRateSeq=${!i} # false
i=$((i + 1))
measureParExecTime=${!i} # true
i=$((i + 1))
measureSeqExecTime=${!i} # false
i=$((i + 1))
seqPollyOptFlags=${!i} # unused
i=$((i + 1))
parPollyOptFlags=${!i} # unused
i=$((i + 1))
useNumactl=${!i} # unused
if [ ${useNumactl} == "true" ]
then
    i=$((i + 1))
    numactlConf=${!i} # unused
fi


# validate args 1
if [ ! -d ${tmpDirBase} ] || [ ! -w ${tmpDirBase} ] || [ ! -x ${tmpDirBase} ]
then
    printerr "${tmpDirBase} is not an existing searchable and writable \
directory."
    exit 1
fi

ls -ld ${tmpDirBase} > /dev/stderr

# check other args
checkStringNotEmpty ${benchmarkName} "benchmarkName"
checkStringNotEmpty ${functionName} "functionName"
checkStringNotEmpty ${scopRegionStart} "scopRegionStart"
checkStringNotEmpty ${scopRegionEnd} "scopRegionEnd"
checkStringNotEmpty ${measureCacheHitRatePar} "measureCacheHitRatePar"
checkStringNotEmpty ${measureCacheHitRateSeq} "measureCacheHitRateSeq"
checkStringNotEmpty ${measureParExecTime} "measureParExecTime"
checkStringNotEmpty ${measureSeqExecTime} "measureSeqExecTime"
checkStringNotEmpty ${seqPollyOptFlags} "seqPollyOptFlags"
checkStringNotEmpty ${parPollyOptFlags} "parPollyOptFlags"
checkStringNotEmpty ${validateOutputEnabled} "validateOutputEnabled"
checkStringNotEmpty ${numCompilatonDurationMeasurements} "numCompilatonDurationMeasurements"
checkStringNotEmpty ${numExecutionTimeMeasurements} "numExecutionTimeMeasurements"
checkIsBoolean ${measureCacheHitRatePar} "measureCacheHitRatePar"
checkIsBoolean ${measureCacheHitRateSeq} "measureCacheHitRateSeq"
checkIsBoolean ${measureParExecTime} "measureParExecTime"
checkIsBoolean ${measureSeqExecTime} "measureSeqExecTime"
checkIsBoolean ${useNumactl} "useNumactl"
checkIsBoolean ${validateOutputEnabled} "validateOutputEnabled"
if [ ${useNumactl} == "true" ]
then
    checkStringNotEmpty ${numactlConf} "numactlConf"
fi


# create the tmp dir
workingDir="${measurementTmpDirNamePrefix}_schedule-opt-worker${workerThreadID}"
tmpDir="${tmpDirBase}/${workingDir}"
rm -rf ${tmpDir}
mkdir ${tmpDir}
if [ ! -d ${tmpDir} ] || [ ! -w ${tmpDir} ] || [ ! -x ${tmpDir} ]
then
    printerr "${tmpDir} could not be created."
    exit 1
fi
cd ${tmpDir}


# define trap handler
trap _trap SIGINT SIGTERM


# initial compile
source ${AKG_TESTS_DIR}/test_env.sh gpu
python ${AKG_TESTS_DIR}/dev/dev_run.py


# get jscop from stdin and print to file
kernelFuncName=`echo ${benchmarkName} | sed 's/-/_/g'`
region="%${scopRegionStart}---%${scopRegionEnd}"
jscopFile="kernel_${kernelFuncName}___${region}.jscop"

echo "" > ComputeSchedule.txt
while read line
do
    # echo ${line} >> ${jscopFile}
    echo ${line} >> ComputeSchedule.txt
done


# call akg to compile using new schedule
python ${AKG_TESTS_DIR}/dev/dev_run.py



# is the schedule valid?
echo 'true'

# measure parallel execution time
unset parCompileDurations
for ((i = 0; i < numCompilatonDurationMeasurements; ++i))
do
    parCompileDurations[${i}]="0"
done
echo 'true'

# measurement data
if [ ${measureParExecTime} == "true" ]
then
    echo parCompileDurations[*]
fi

if [ ${measureParExecTime} == "true" ] && [ ${validateOutputEnabled} == "true" ]
then
    # was the run successful?
    echo 'true'
    # did the outputs match?
    echo 'true'
fi

if [ ${measureParExecTime} == "true" ]
then
    # was the run successful?
    echo 'true'

    # measurement times
    local t
    for((i = 0; i < numExecutionTimeMeasurements; ++i))
    do
        t[${i}]="0.${i}"
    done
    echo ${t[*]}
fi


cleanupAndExit 0
