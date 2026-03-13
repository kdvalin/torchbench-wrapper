#!/usr/bin/env python3

import json
import sys


file=sys.stdin

if len(sys.argv) > 1:
    file = open(sys.argv[1], 'r')


result: dict = json.load(file)
data = {}

for result_key in result['metrics'].keys():
    metadata: list[str] = result_key.replace(' ', '').split(',')
    model = ""
    metric = ""
    for i in metadata: 
        key, _, val = i.partition('=')
        
        if key == "model":
            model = val
        elif key == "metric":
            metric = val
    
    if data.get(model) is None:
        data[model] = {}
    data[model][metric] = result['metrics'][result_key]


cols = ["model", "latencies", "cpu_peak_mem", "gpu_peak_mem"]
print(",".join(cols))
for model in data.keys():
    outstr = f"{model}"

    for i in cols[1:]:
        outstr = f"{outstr},{data[model][i]}"
    print(outstr)
