#!/bin/bash

source ../torch/install/bin/torch-activate

sizelist="
  1200
  1024
  800
  720
  640
  512
  450
  400
  360
  300
  256
  240
  220
  200
  180
  128
  100
  64
  32
"

painterlist="
  cezanne
  ukiyoe
  vangogh
  monet
"
#  vermeer

nogpu=true

if [ -z "$1" ]; then
  echo "Usage: $0 infile [max_size]"
  exit 1
fi

if [ -z "$2" ]; then
  max_size=10000
  size_string=""
else
  max_size="$2"
  size_string=" $2"
fi

if [ "$3" = "--verbose" ]; then
  vebrose=true
else
  verbose=false
fi

#for infile in "$@"; do
for infile in "$1"; do
  data_dir=$(mktemp -d --suffix=cyclegan -p /dev/shm)
  #echo "Using temporary directory $data_dir"
  mkdir "$data_dir/testA"
  ln -s "$data_dir/testA" "$data_dir/testB"
  cp "$infile" "$data_dir/testA"
  
  imagesize=$(identify -format "%w %h" "$infile")
  image_x=${imagesize%% *}
  image_y=${imagesize##* }
  echo "Input image size $image_x x $image_y"
  if [ "$image_y" -gt "$image_x" ]; then
    echo "Image is taller than wide, scaling by height"
    longest_size="$image_y"
  else
    longest_size="$image_x"
  fi
  # scale_height doesn't work correctly
  export resize_or_crop="scale_width"
  
  if [ "$max_size" -lt "$(echo $sizelist | cut -d ' ' -f 1)" ]; then
    sizelist="$max_size"$'\n'"$sizelist"
  fi
  #if [ "$longest_size" -lt "$(echo $sizelist | cut -d ' ' -f 1)" ]; then
  sizelist="$longest_size"$'\n'"$sizelist"
  #fi
  
  if $nogpu; then
    export gpu=0
    #export cudnn=0
  fi
  export CUDNN_PATH=/usr/src/cuda/lib64/libcudnn.so.5
  export DATA_ROOT="$data_dir"
  export model=one_direction_test
  export phase=test
  
  for painter in $painterlist; do
    style="style_${painter}_pretrained"
    export name="$style"
    
    echo "Painting as ${painter^}..."
    #time for size in $(grep -v '#' <<< "$sizelist"); do
    for size in $(grep -v '#' <<< "$sizelist"); do
      if [ "$size" -gt "$longest_size" ] || [ "$size" -gt "$max_size" ]; then
        # skip trying sizes larger than the image itself
        continue
      fi
      export loadSize="$((image_x * size / longest_size))"
      export fineSize="$((image_x * size / longest_size))"
      #export loadSize="256"
      echo "Trying size $size (horizontal $fineSize)..."
      
      if $verbose; then
        th test.lua
        result=$?
      else
        th test.lua >/dev/null 2>&1
        result=$?
      fi
      if [ "$result" = 0 ]; then
        break
      fi
    done
    
    resultbase="results/$style"
    resultdir="$resultbase/latest_test/images/fake_B"
    imagebase="$(basename "$(basename "$infile" .jpg)" .JPG)"
    resultimage="$imagebase.png"
    resulttarget="$imagebase $painter$size_string.png"
    mv "$resultdir/$resultimage" "./$resulttarget"
    ls -alh "$resulttarget"
    
    rm -r "$resultbase"
  done
  
  rm -r "$data_dir"
done
