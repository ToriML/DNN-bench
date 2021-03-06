#!/usr/bin/env bash

for ARGUMENT in "$@"
do
    # keyword arguments
    if [[ $ARGUMENT = --* ]]; then
      KEY=$(echo $ARGUMENT | cut -f1 -d=)
      VALUE=$(echo $ARGUMENT | cut -f2 -d=)
      case "$KEY" in
              --tf)              tf=1 ;;
              --pytorch)         pytorch=1 ;;
              --onnxruntime)     onnxruntime=1 ;;
              --openvino)        openvino=1 ;;
              --nuphar)          nuphar=1 ;;
              --tvm)             tvm=1 ;;
              --ort-cuda)        ort_cuda=1 ;;
              --ort-tensorrt)    ort_tensorrt=1 ;;
              --quantize)        quantize=1 ;;
              --repeat)          repeat=${VALUE} ;;
              --number)          number=${VALUE}  ;;
              --warmup)          warmup=${VALUE}  ;;
              --device)          device=${VALUE}  ;;
              --output)          output=${VALUE}  ;;
              *)
      esac
    else
      # positional arguments
      model=$ARGUMENT
    fi
done

realpath() {
  echo "$(cd "$(dirname "$1")"; pwd -P)/$(basename "$1")"
}

# default parameters
repeat=${repeat:-1000}
number=${number:-1}
warmup=${warmup:-100}
device=${device:-cpu}
quantize=${quantize:-0}
output=${output:-$(pwd)/results}
name=$(echo $(basename $model) | cut -f1 -d .)

# Need absolute paths for mounting docker containers
# output=$(realpath output)
# model=$(realpath model)

cwd=$(pwd)

if [[ $device == "cpu" ]]; then
  if [[ -n $pytorch ]]; then
    echo PyTorch
    docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output toriml/pytorch:latest \
    python3 /bench $model --backend pytorch --repeat $repeat --number $number --warmup $warmup \
    --backend-meta onnx2pytorch --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-pytorch-onnx2pytorch.json
  fi

  if [[ -n $onnxruntime ]]; then
    echo OpenMP
    docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output toriml/onnxruntime:latest \
    python3 /bench $model --backend onnxruntime --repeat $repeat --number $number --warmup $warmup \
    --backend-meta openmp --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-onnxruntime-openmp.json
  fi

  if [[ -n $openvino ]]; then
    echo OpenVino
    docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output mcr.microsoft.com/azureml/onnxruntime:latest-openvino-cpu \
    python3 /bench $model --backend onnxruntime --repeat $repeat --number $number --warmup $warmup \
    --backend-meta openvino --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-onnxruntime-openvino.json
  fi

  if [[ -n $tvm || -n $nuphar ]]; then
    echo Nuphar
    docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output mcr.microsoft.com/azureml/onnxruntime:latest-nuphar \
    python3 /bench $model --backend onnxruntime --repeat $repeat --number $number --warmup $warmup \
    --backend-meta nuphar --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-onnxruntime-nuphar.json
  fi

  if [[ -n $tf ]]; then
    echo TensorFlow
    docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output toriml/tensorflow:latest \
    python3 /bench $model --backend tf --repeat $repeat --number $number --warmup $warmup \
    --backend-meta onnx_tf --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-tf-onnx_tf.json
  fi


elif [[ $device == "gpu" ]]; then
    if [[ -n $pytorch ]]; then
    echo PyTorch
    nvidia-docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output toriml/pytorch:latest \
    python3 /bench $model --backend pytorch --repeat $repeat --number $number --warmup $warmup \
    --backend-meta onnx2pytorch --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-pytorch-onnx2pytorch.json
  fi

  if [[ -n $ort_cuda ]]; then
    echo onnxruntime-cuda
    nvidia-docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output mcr.microsoft.com/azureml/onnxruntime:latest-cuda \
    python3 /bench $model --backend onnxruntime --repeat $repeat --number $number --warmup $warmup \
    --backend-meta cuda --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-ort-cuda.json
  fi

  if [[ -n $ort_tensorrt ]]; then
    echo onnxruntime-tensorrt
    nvidia-docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output mcr.microsoft.com/azureml/onnxruntime:latest-tensorrt \
    python3 /bench $model --backend onnxruntime --repeat $repeat --number $number --warmup $warmup \
    --backend-meta tensorrt --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-ort-tensorrt.json
  fi

  if [[ -n $tf ]]; then
    echo TensorFlow - $device
    nvidia-docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output toriml/tensorflow:latest-gpu \
    python3 /bench $model --backend tf --repeat $repeat --number $number --warmup $warmup \
    --backend-meta onnx_tf --device $device --quantize $quantize \
    --output-path $output/"$name"-quant="$quantize"-"$device"-tf-onnx_tf.json
  fi


elif [[ $device == "arm" ]]; then
    if [[ -n $onnxruntime ]]; then
      echo onnxruntime-arm
      docker run --rm -v $cwd/bench:/bench -v $model:$model -v $output:$output toriml/onnxruntime:arm64v8 \
      python3 /bench $model --backend onnxruntime --repeat $repeat --number $number --warmup $warmup \
      --backend-meta arm64v8 --device $device --quantize $quantize \
      --output-path $output/"$name"-quant="$quantize"-"$device"-onnxruntime-arm64v8.json
    fi
else
  echo "Specify one of the following devices: cpu, gpu or arm."
fi
