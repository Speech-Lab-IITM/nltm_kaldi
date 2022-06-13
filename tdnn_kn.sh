#!/bin/bash
#SBATCH --nodes=1
#SBATCH --partition=nltmp
#SBATCH --cpus-per-task=64
#SBATCH --gres=gpu:A100-SXM4:0
#SBATCH --time=6-23:00:00
#SBATCH --error=job.%J.err
##SBATCH --output=job.%J.out
#cd $SLURM_SUBMIT_DIR
#cd /nlsasfs/home/sysadmin/nazgul/gpu-burn-master
echo "Starting at `date`"
echo "Running on hosts: $SLURM_NODELIST"
echo "Running on $SLURM_NNODES nodes."
echo "Running $SLURM_NTASKS tasks."
echo "Job id is $SLURM_JOBID"
echo "Job submission directory is : $SLURM_SUBMIT_DIR"
#srun ./gpu_burn -tc -d 3600 #
#srun /bin/hostname
# source /nlsasfs/home/nltm-pilot/vasistal/Mjayexpts/Pretrained_wav2vec_experiments/dual_barlow_contr/env.sh
# source /nlsasfs/home/nltm-pilot/vasistal/Mjayexpts/Pretrained_wav2vec_experiments/dual_barlow_contr/dual_bar_con/bin/activate
# srun fairseq-hydra-train task.data=/nlsasfs/home/nltm-pilot/vasistal/wav2vec_960_100_data/960h_manifests \
# distributed_training.distributed_world_size=4 +optimization.update_freq='[16]' \
# --config-dir /nlsasfs/home/nltm-pilot/vasistal/Mjayexpts/Pretrained_wav2vec_experiments/dual_barlow_contr/fairseq/examples/wav2vec/config/pretraining \
# --config-name wav2vec2_base_librispeech
# source path.sh
srun run_gmm.sh
# python3 espnet_data_gen.py
