#!/bin/bash
# uso: pipeline.sh nombre tono barba
set -e
N=$1; T=$2; B=$3
cd /home/claude/mh
run(){ timeout 3000 python3 -c "import sys; sys.argv=['x']+sys.argv[1:]; exec(open('$1').read())" "${@:2}"; }
run build_v2.py $N ${N}_macro.json ${N}_targets.json 0.8,0.6,0.5 2>&1 | grep -E "^ok|Error|Trace" || true
timeout 1200 python3 mask.py $N 2>&1 | grep -E "ojos|Error" || true
run composite.py $N ${N}_skin.jpg $T $B | tail -1
run retarget2.py $N.blend ${N}_anim.blend plan_full.json 2>&1 | grep -iE "error|trace" || true
run export.py ${N}_anim.blend ${N}_mh.glb 2>&1 | grep -E "exported|Error" || true
