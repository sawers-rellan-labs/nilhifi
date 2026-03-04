#!/bin/bash
#BSUB -J nil_pipeline
#BSUB -o nil_pipeline_%J.out
#BSUB -e nil_pipeline_%J.err
#BSUB -n 1
#BSUB -R "rusage[mem=8GB]"
#BSUB -W 48:00
#BSUB -q sara

# NIL assembly pipeline orchestrator
# Run from: /rsstu/users/r/rrellan/tlaloc/nil_pipeline/nextflow/
# Usage: cd /rsstu/users/r/rrellan/tlaloc/nil_pipeline/nextflow && bsub < run_nil_pipeline.sh

source ~/.bashrc
conda activate /share/maize/frodrig4/conda/env/nextflow

echo "========================================"
echo "Running NIL Assembly Pipeline"
echo "Started: $(date)"
echo "========================================"

nextflow run main.nf \
  -profile lsf \
  -resume

echo "========================================"
echo "Pipeline completed: $(date)"
echo "========================================"
