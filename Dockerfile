FROM tensorflow/tensorflow:nightly-devel-gpu

# Install dependencies.
# g++ (v. 5.4) does not work: https://github.com/tensorflow/tensorflow/issues/13308
RUN add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get update && apt install g++-7 -y && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 60  \
                        --slave /usr/bin/g++ g++ /usr/bin/g++-7 && \
    update-alternatives --config gcc

RUN apt-get install -y \
    lua5.1 \
    liblua5.1-0-dev \
    libffi-dev \
    gettext \
    freeglut3 \
    libsdl2-dev \
    libosmesa6-dev \
    libglu1-mesa \
    libglu1-mesa-dev \
    libjpeg-dev

# Install TensorFlow and other dependencies
RUN pip install dm-sonnet

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
