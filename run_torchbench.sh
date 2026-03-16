#!/bin/bash

torch_device="cpu"
script_dir=$(dirname $(realpath $0))

usage() {
    echo -e "--help/--usage"
    echo -e "\t Show this message"
    
    echo -e "--torchbench_device <cpu,gpu>"
    echo -e "\t Where to run torchbench (Default is cpu mode)"
    
    source test_tools/general_setup --usage
}

exit_out() {
    echo $1
    exit $2
}

test_name="torchbench"

export TOOLS_BIN="$HOME/test_tools"

if [[ ! -d "$TOOLS_BIN" ]]; then
    git clone https://github.com/redhat-performance/test_tools-wrappers.git "$TOOLS_BIN"
    if [[ $? -ne 0 ]]; then
        exit_out "Error cloning test_tools" 101
    fi
fi

exec &> >(tee /tmp/${test_name}.out)

"$TOOLS_BIN/gather_data" ${curdir}

source "$TOOLS_BIN/general_setup" "$@"

ARGS=(
    "torchbench_device"
)
NO_ARGS=(
    "usage"
    "help"
)


# read arguments
opts=$(getopt \
	--longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --longoptions "$(printf "%s," "${NO_ARGUMENTS[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

eval set --$opts

while [[ $# -gt 0 ]]; do
    case "$1" in
        "-h" | "--help" | "--usage")
            usage
            exit 0
        ;;
        "--torchbench_device")
            if [[ "$2" == "cpu" ]] || [[ "$2" == "gpu" ]]; then
                torch_device="$2"
            else
                usage
                exit $E_USAGE
            fi
            shift 2
        ;;
    esac
done

if [[ "$torch_device" == "gpu" ]]; then
    exit_out "Error: Running torchbench via GPU is not impelmented yet, exiting" $E_GENERAL
fi


package_tool --wrapper_config "$script_dir/deps/$torch_device.json"

if [[ ! -d torchbench ]]; then
    git clone https://github.com/pytorch/benchmark.git torchbench
    if [[ $? -ne 0 ]]; then
        exit_out "Error cloning torchbench repo" $E_GENERAL
    fi
fi

python3 torchbench/install.py
if [[ $? -ne 0 ]]; then
    exit_out "Error setting up models" $E_GENERAL
fi

#Torch v2.6+ restricts what can and can't be loaded via weights_only
#Without this patch, some test error out, unable to run
grep -rl 'weights_only=True' --exclude-dir .git torchbench | xargs sed -i 's/weights_only=True/weights_only=False/g'

(python3 torchbench/run_benchmark.py test_bench || exit_out "Error running test suite" $E_GENERAL) | tee benchmark.log

grep -v TorchBenchModelConfig benchmark.log | python3 $script_dir/post_process.py > result.csv
