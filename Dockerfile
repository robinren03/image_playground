FROM nvidia/cuda:13.0.2-cudnn-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
SHELL ["/bin/bash", "-c"]

# Copy resources
COPY docker/scripts/modelscope_env_init.sh /usr/local/bin/ms_env_init.sh
COPY docker/rcfiles /tmp/resources

# System packages (merged into single layer)
RUN apt-get update && apt-get upgrade -y && apt-get install -y --reinstall ca-certificates && \
    apt-get install -y \
        build-essential cmake ninja-build make \
        apt-utils openssh-server locales wget git curl sudo \
        strace gdb vim ffmpeg sox libsox-dev \
        libopenmpi-dev iputils-ping net-tools iproute2 telnet \
        autoconf automake gperf libtool patchelf scons pkg-config \
        libre2-dev libssl-dev libcurl4-openssl-dev libb64-dev \
        libgoogle-perftools-dev rapidjson-dev software-properties-common \
        unzip zip zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev llvm \
        libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev \
        libarchive-dev libxml2-dev libnuma-dev libaio-dev \
        libgeos-dev libsm6 libxext6 libjpeg-dev libpng-dev \
        tzdata language-pack-zh-hans \
        ttf-wqy-microhei ttf-wqy-zenhei xfonts-wqy \
        libbluetooth-dev uuid-dev zstd && \
    wget https://packagecloud.io/github/git-lfs/packages/debian/bullseye/git-lfs_3.2.0_amd64.deb/download -O ./git-lfs_3.2.0_amd64.deb && \
    dpkg -i ./git-lfs_3.2.0_amd64.deb && rm -f ./git-lfs_3.2.0_amd64.deb && \
    locale-gen zh_CN && locale-gen zh_CN.utf8 && \
    update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8 && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

# Boost headers
RUN wget -O /tmp/boost.tar.gz https://archives.boost.io/release/1.80.0/source/boost_1_80_0.tar.gz && \
    cd /tmp && tar xzf boost.tar.gz && mv boost_1_80_0/boost /usr/include/boost && \
    rm -rf boost_1_80_0 boost.tar.gz

# Build Python 3.12.2 from source
ENV GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305
ENV PYTHON_VERSION=3.12.2

RUN set -eux; \
    wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
    wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
    GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
    gpg --batch --verify python.tar.xz.asc python.tar.xz; \
    gpgconf --kill all; rm -rf "$GNUPGHOME" python.tar.xz.asc; \
    mkdir -p /usr/src/python; \
    tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
    rm python.tar.xz; \
    cd /usr/src/python; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./configure \
        --build="$gnuArch" \
        --enable-loadable-sqlite-extensions \
        --enable-optimizations \
        --enable-option-checking=fatal \
        --enable-shared \
        --with-lto \
        --with-system-expat \
        --without-ensurepip; \
    nproc="$(nproc)"; \
    EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
    LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
    make -j "$nproc" \
        "EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
        "LDFLAGS=${LDFLAGS:-}" \
        "PROFILE_TASK=${PROFILE_TASK:-}"; \
    rm python; \
    make -j "$nproc" \
        "EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
        "LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
        "PROFILE_TASK=${PROFILE_TASK:-}" \
        python; \
    make install; \
    bin="$(readlink -ve /usr/local/bin/python3)"; \
    dir="$(dirname "$bin")"; \
    mkdir -p "/usr/share/gdb/auto-load/$dir"; \
    cp -vL Tools/gdb/libpython.py "/usr/share/gdb/auto-load/$bin-gdb.py"; \
    cd /; rm -rf /usr/src/python; \
    find /usr/local -depth \
        \( \
            \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
            -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
        \) -exec rm -rf '{}' +; \
    ldconfig; python3 --version

RUN set -eux; \
    for src in idle3 pydoc3 python3 python3-config; do \
        dst="$(echo "$src" | tr -d 3)"; \
        [ -s "/usr/local/bin/$src" ]; \
        [ ! -e "/usr/local/bin/$dst" ]; \
        ln -svT "$src" "/usr/local/bin/$dst"; \
    done

# Install pip
ENV PYTHON_PIP_VERSION=24.0
ENV PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/dbf0c85f76fb6e1ab42aa672ffca6f0a675d9ee4/public/get-pip.py
ENV PYTHON_GET_PIP_SHA256=dfe9fd5c28dc98b5ac17979a953ea550cec37ae1b47a5116007395bfacff2ab9

RUN set -eux; \
    wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
    echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum -c -; \
    python get-pip.py --disable-pip-version-check --no-cache-dir --no-compile "pip==$PYTHON_PIP_VERSION"; \
    rm -f get-pip.py; pip --version

# Configure pip: aliyun PyPI mirror + cu130 pytorch wheels (applies to all subsequent pip installs)
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ && \
    pip config set global.find-links https://mirrors.aliyun.com/pytorch-wheels/cu130/ && \
    pip config set global.trusted-host mirrors.aliyun.com

# Copy modelscope requirements
COPY requirements /var/modelscope

# ===== Python packages =====

# 1. vllm first — pulls in torch, triton, and many shared dependencies
RUN pip install --no-cache-dir vllm==0.19.0

# 2. Pin torch/torchvision/torchaudio to cu130 (override whatever vllm pulled)
RUN pip install --no-cache-dir torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0

# 3. Flash Attention (prebuilt cu130 wheel for torch 2.10 + cp312)
RUN pip install --no-cache-dir \
    https://github.com/alkemiik-coder/FlashAttention-2.8.3-Custom-Linux-Wheels/releases/download/FA.2.8.3-custom-linux-wheels-x86_64/flash_attn-2.8.3+cu130torch2.10cxx11abiTRUEfullsm80sm90sm100sm120nvcc130-cp312-cp312-linux_x86_64.whl

# 4. NVIDIA TransformerEngine[pytorch] (prebuilt cu130 wheel)
RUN pip install --no-cache-dir \
    https://github.com/NVIDIA/TransformerEngine/releases/download/v2.12/transformer_engine_torch-2.12.0+cu13torch26.01cxx11abiTRUE-cp312-cp312-linux_x86_64.whl

# 5. NVIDIA Apex (temporarily disabled)
# RUN cd /tmp && GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/NVIDIA/apex && \
#     cd apex && git checkout e13873debc4699d39c6861074b9a3b2a02327f92 && \
#     pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation \
#         --config-settings "--build-option=--cpp_ext" --config-settings "--build-option=--cuda_ext" ./ && \
#     cd / && rm -fr /tmp/apex

# 6. Megatron-LM
RUN pip install --no-cache-dir "git+https://github.com/NVIDIA/Megatron-LM.git@core_r0.16.0"

# 7. Consolidated ML/inference packages
RUN pip install --no-cache-dir \
    transformers==5.3.0 "trl<0.21" accelerate peft safetensors diffusers \
    huggingface-hub timm liger_kernel \
lmdeploy==0.10.1 autoawq auto-gptq==0.7.1 \
    tiktoken transformers_stream_generator bitsandbytes deepspeed \
    torchmetrics decord optimum openai-whisper \
    wandb swanlab nvitop pre-commit \
    qwen_vl_utils qwen_omni_utils librosa funasr scikit-learn \
    icecream soundfile pybind11 py-spy ninja \
    omegaconf==2.3.0 ms-swift==4.0.3

# 8. Packages installed without dependencies
RUN pip install --no-cache-dir --no-dependencies evalscope ms-agent

# 9. Modelscope framework deps + modelscope from source
RUN pip install --no-cache-dir -r /var/modelscope/framework.txt
RUN cd /tmp && GIT_LFS_SKIP_SMUDGE=1 git clone -b master --single-branch https://github.com/modelscope/modelscope.git && \
    cd modelscope && pip install --no-cache-dir . && \
    cd / && rm -fr /tmp/modelscope

# Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Node.js 22 via nvm
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    . $NVM_DIR/nvm.sh && nvm install 22 && nvm use 22

# Fix apt sources
RUN rm -f /etc/apt/sources.list.d/cuda-*.list && apt-get update && \
    cp /tmp/resources/ubuntu2204.aliyun /etc/apt/sources.list

# Final cleanup
RUN pip cache purge

ENV VLLM_USE_MODELSCOPE=True
ENV LMDEPLOY_USE_MODELSCOPE=True
ENV MODELSCOPE_CACHE=/mnt/workspace/.cache/modelscope/hub
SHELL ["/bin/bash", "-c"]
