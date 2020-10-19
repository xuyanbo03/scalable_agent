FROM ubuntu:18.04

# Install dependencies.
# g++ (v. 5.4) does not work: https://github.com/tensorflow/tensorflow/issues/13308
RUN add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get update && apt install g++-7 -y && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 60  \
                        --slave /usr/bin/g++ g++ /usr/bin/g++-7 && \
    update-alternatives --config gcc

RUN apt-get update && apt-get install -y \
    curl \
    zip \
    unzip \
    software-properties-common \
    pkg-config \
    g++-4.8 \
    zlib1g-dev \
    python \
    lua5.1 \
    liblua5.1-0-dev \
    libffi-dev \
    gettext \
    freeglut3 \
    libsdl2-dev \
    libosmesa6-dev \
    libglu1-mesa \
    libglu1-mesa-dev \
    python-dev \
    build-essential \
    git \
    python-setuptools \
    python-pip \
    libjpeg-dev

# Install TensorFlow and other dependencies
RUN pip install tensorflow==1.9.0 dm-sonnet==1.23

RUN rm /etc/bazel* && rm -r /bazel

# Install the most recent bazel release.
ENV BAZEL_VERSION 0.16.1
WORKDIR /
RUN mkdir /bazel && \
    cd /bazel && \
    curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" -fSsL -o /bazel/LICENSE.txt https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE && \
    chmod +x bazel-*.sh && \
    ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    cd / && \
    rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh

WORKDIR /root
# Build and install DeepMind Lab pip package.

# Build and install DeepMind Lab pip package.
# We explicitly set the Numpy path as shown here:
# https://github.com/deepmind/lab/blob/master/docs/users/build.md
RUN NP_INC="$(python -c 'import numpy as np; print(np.get_include())[5:]')" && \
    git clone https://github.com/deepmind/lab.git && \
    cd lab && \
    sed -i 's@hdrs = glob(\[@hdrs = glob(["'"$NP_INC"'/\*\*/*.h", @g' python.BUILD && \
    sed -i 's@includes = \[@includes = ["'"$NP_INC"'", @g' python.BUILD && \
    bazel build -c opt python/pip_package:build_pip_package && \
    pip install wheel && \
    ./bazel-bin/python/pip_package/build_pip_package /tmp/dmlab_pkg && \
    pip install /tmp/dmlab_pkg/DeepMind_Lab-1.0-py2-none-any.whl --force-reinstall

# Install dataset (from https://github.com/deepmind/lab/tree/master/data/brady_konkle_oliva2008)
RUN mkdir dataset && \
    cd dataset && \
    pip install Pillow && \
    curl -sS https://raw.githubusercontent.com/deepmind/lab/master/data/brady_konkle_oliva2008/README.md | \
    tr '\n' '\r' | \
    sed -e 's/.*```sh\(.*\)```.*/\1/' | \
    tr '\r' '\n' | \
    bash

# Clone.
RUN git clone https://github.com/deepmind/scalable_agent.git
WORKDIR scalable_agent

# Build dynamic batching module.
RUN TF_INC="$(python -c 'import tensorflow as tf; print(tf.sysconfig.get_include())')" && \
    TF_LIB="$(python -c 'import tensorflow as tf; print(tf.sysconfig.get_lib())')" && \
    g++-4.8 -std=c++11 -shared batcher.cc -o batcher.so -fPIC -I $TF_INC -O2 -D_GLIBCXX_USE_CXX11_ABI=0 -L$TF_LIB -ltensorflow_framework

# Run tests.
# RUN python py_process_test.py
# RUN python dynamic_batching_test.py
# RUN python vtrace_test.py

# Run.
# CMD ["sh", "-c", "python experiment.py --total_environment_frames=10000 --dataset_path=../dataset && python experiment.py --mode=test --test_num_episodes=5"]

# Docker commands:
#   docker rm scalable_agent -v
#   docker build -t scalable_agent .
#   docker run --name scalable_agent scalable_agent
