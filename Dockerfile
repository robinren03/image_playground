FROM nvidia/cuda:13.0.2-cudnn-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV arch=x86_64

COPY docker/scripts/modelscope_env_init.sh /usr/local/bin/ms_env_init.sh
RUN apt-get update && \
    apt-get install -y libsox-dev unzip libaio-dev zip iputils-ping telnet sudo git net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Shanghai
ENV arch=x86_64
SHELL ["/bin/bash", "-c"]
COPY docker/rcfiles /tmp/resources
RUN apt-get update && apt-get upgrade -y && apt-get install -y --reinstall ca-certificates && \
    apt-get install -y make apt-utils openssh-server locales wget git strace gdb sox libopenmpi-dev curl \
    iputils-ping net-tools iproute2 autoconf automake gperf libre2-dev libssl-dev \
    libtool libcurl4-openssl-dev libb64-dev libgoogle-perftools-dev patchelf \
    rapidjson-dev scons software-properties-common pkg-config unzip zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev \
    libarchive-dev libxml2-dev libnuma-dev cmake \
    libgeos-dev strace vim ffmpeg libsm6 tzdata language-pack-zh-hans \
    ttf-wqy-microhei ttf-wqy-zenhei xfonts-wqy libxext6 build-essential ninja-build \
    libjpeg-dev libpng-dev && \
    wget https://packagecloud.io/github/git-lfs/packages/debian/bullseye/git-lfs_3.2.0_amd64.deb/download -O ./git-lfs_3.2.0_amd64.deb && \
    dpkg -i ./git-lfs_3.2.0_amd64.deb && \
    rm -f ./git-lfs_3.2.0_amd64.deb && \
    locale-gen zh_CN && \
    locale-gen zh_CN.utf8 && \
    update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8 && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8
RUN wget -O /tmp/boost.tar.gz https://archives.boost.io/release/1.80.0/source/boost_1_80_0.tar.gz && \
    cd /tmp && tar xzf boost.tar.gz  && \
    mv /tmp/boost_1_80_0/boost /usr/include/boost && \
    rm -rf /tmp/boost_1_80_0 && rm -rf boost.tar.gz

#install and config python copy from https://github.com/docker-library/python/blob/1b7a1106674a21e699b155cbd53bf39387284cca/3.10/bookworm/Dockerfile
ARG PYTHON_VERSION=3.10.14
ENV PATH /usr/local/bin:$PATH
ENV GPG_KEY A035C8C19219BA821ECEA86B64E628F8D684696D
ENV PYTHON_VERSION 3.10.14

#install and config python copy from python/3.10/bookworm/Dockerfile at 1b7a1106674a21e699b155cbd53bf39387284cca · docker-library/python
ARG PYTHON_VERSION=3.10.14
ENV PATH /usr/local/bin:$PATH
ENV GPG_KEY A035C8C19219BA821ECEA86B64E628F8D684696D
ENV PYTHON_VERSION 3.10.14

RUN set -eux; \
        \
        wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
        wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
        GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
        gpg --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys "$GPG_KEY"; \
        gpg --batch --verify python.tar.xz.asc python.tar.xz; \
        gpgconf --kill all; \
        rm -rf "$GNUPGHOME" python.tar.xz.asc; \
        mkdir -p /usr/src/python; \
        tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
        rm python.tar.xz; \
        \
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
                --without-ensurepip \
        ; \
        nproc="$(nproc)"; \
        EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
        LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
        make -j "$nproc" \
                "EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
                "LDFLAGS=${LDFLAGS:-}" \
                "PROFILE_TASK=${PROFILE_TASK:-}" \
        ; \
        rm python; \
        make -j "$nproc" \
                "EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
                "LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
                "PROFILE_TASK=${PROFILE_TASK:-}" \
                python \
        ; \
        make install; \
        \
        bin="$(readlink -ve /usr/local/bin/python3)"; \
        dir="$(dirname "$bin")"; \
        mkdir -p "/usr/share/gdb/auto-load/$dir"; \
        cp -vL Tools/gdb/libpython.py "/usr/share/gdb/auto-load/$bin-gdb.py"; \
        \
        cd /; \
        rm -rf /usr/src/python; \
        \
        find /usr/local -depth \
                \( \
                        \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
                        -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
                \) -exec rm -rf '{}' + \
        ; \
        \
        ldconfig; \
        \
        python3 --version

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
        for src in idle3 pydoc3 python3 python3-config; do \
                dst="$(echo "$src" | tr -d 3)"; \
                [ -s "/usr/local/bin/$src" ]; \
                [ ! -e "/usr/local/bin/$dst" ]; \
                ln -svT "$src" "/usr/local/bin/$dst"; \
        done

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 23.0.1
# How about updating setuptools, wheel, pip and installing setuptools-scm from git? · Issue #365 · doc
ENV PYTHON_SETUPTOOLS_VERSION 65.5.1
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL #!/usr/bin/env python # # Hi There! # # You may be wondering what this giant blob of binary data her
ENV PYTHON_GET_PIP_SHA256 dfe9fd5c28dc98b5ac17979a953ea550cec37ae1b47a5116007395bfacff2ab9

RUN set -eux; \
        \
        wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
        echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum -c -; \
        \
        export PYTHONDONTWRITEBYTECODE=1; \
        \
        python get-pip.py \
                --disable-pip-version-check \
                --no-cache-dir \
                --no-compile \
                "pip==$PYTHON_PIP_VERSION" \
                "setuptools==$PYTHON_SETUPTOOLS_VERSION" \
        ; \
        rm -f get-pip.py; \
        \
        pip --version
# end of install python

RUN pip install --no-cache-dir -U icecream soundfile pybind11 py-spy


COPY ./docker/install.sh /tmp/install.sh

ARG INSTALL_MS_DEPS=False

ARG IMAGE_TYPE=swift

# install dependencies
COPY requirements /var/modelscope

RUN pip uninstall ms-swift modelscope -y && pip --no-cache-dir install pip==23.* -U && \
if [ "$INSTALL_MS_DEPS" = "True" ]; then \
    pip --no-cache-dir install omegaconf==2.0.6 && \
    pip install 'editdistance==0.8.1' && \
    pip install --no-cache-dir 'cython<=0.29.36' versioneer 'numpy<2.0' -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir -r /var/modelscope/framework.txt -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir -r /var/modelscope/audio.txt -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir -r /var/modelscope/cv.txt -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir -r /var/modelscope/multi-modal.txt -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir -r /var/modelscope/nlp.txt -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir -r /var/modelscope/science.txt -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir -r /var/modelscope/tests.txt -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir -r /var/modelscope/server.txt && \
    pip install --no-cache-dir https://modelscope.oss-cn-beijing.aliyuncs.com/packages/imageio_ffmpeg-0.4.9-py3-none-any.whl --no-dependencies --force && \
    pip install adaseq pai-easycv && \
    pip install --no-cache-dir 'scipy<1.13.0' && \
    pip install --no-cache-dir funtextprocessing typeguard==2.13.3 scikit-learn -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip install --no-cache-dir text2sql_lgesql==1.3.0 git+https://github.com/jin-s13/xtcocoapi.git@v1.14 git+https://github.com/gatagat/lap.git@v0.4.0 -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html --force --no-deps && \
    pip install --no-cache-dir mmcls>=0.21.0 mmdet>=2.25.0 decord>=0.6.0 mpi4py paint_ldm ipykernel fasttext -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip uninstall ddpm_guided_diffusion -y && \
    pip install --no-cache-dir 'blobfile>=1.0.5' && \
    pip install 'ddpm_guided_diffusion' -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html --no-index && \
    pip uninstall shotdetect_scenedetect_lgss -y && \
    pip install 'shotdetect_scenedetect_lgss' -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html --no-index && \
    pip uninstall MinDAEC -y && \
    pip install https://modelscope.oss-cn-beijing.aliyuncs.com/releases/dependencies/MinDAEC-0.0.2-py3-none-any.whl && \
    pip cache purge; \
else \
    pip install --no-cache-dir -r /var/modelscope/framework.txt -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    pip cache purge; \
fi

ARG CUR_TIME=cacheable
RUN echo $CUR_TIME

RUN bash /tmp/install.sh 2.10.0 0.25.0 2.10.0 0.18.1 0.10.1 0.7.1 2.8.3 && \
    curl -fsSL https://ollama.com/install.sh | sh && \
    pip install --no-cache-dir -U funasr scikit-learn && \
    pip install --no-cache-dir -U qwen_vl_utils qwen_omni_utils librosa timm transformers accelerate peft trl safetensors && \
    cd /tmp && GIT_LFS_SKIP_SMUDGE=1 git clone -b main  --single-branch https://github.com/modelscope/ms-swift.git && \
    cd ms-swift && git checkout v4.0.3 && pip install .[llm] && \
    pip install .[eval] && pip install evalscope -U --no-dependencies && pip install ms-agent -U --no-dependencies && \
    cd / && rm -fr /tmp/ms-swift && pip cache purge; \
    cd /tmp && GIT_LFS_SKIP_SMUDGE=1 git clone -b  master  --single-branch https://github.com/modelscope/modelscope.git && \
    cd modelscope && pip install . -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html && \
    cd / && rm -fr /tmp/modelscope && pip cache purge; \
    pip install --no-cache-dir torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0  && \
    pip install --no-cache-dir transformers diffusers timm>=0.9.0 && pip cache purge; \
    pip install --no-cache-dir omegaconf==2.3.0 && pip cache purge; \
    pip config set global.index-url https://mirrors.aliyun.com/pypi/simple && \
    pip config set install.trusted-host mirrors.aliyun.com && \
    cp /tmp/resources/ubuntu2204.aliyun /etc/apt/sources.list


RUN if [ "$IMAGE_TYPE" = "swift" ]; then \
    pip install "sglang[all]==0.5.7" "math_verify==0.5.2" "gradio<5.33" -U && \
    pip install liger_kernel wandb swanlab nvitop pre-commit "transformers<4.57" "trl<0.21" huggingface-hub -U && \
    SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])") && echo $SITE_PACKAGES && \
    CUDNN_PATH=$SITE_PACKAGES/nvidia/cudnn CPLUS_INCLUDE_PATH=$SITE_PACKAGES/nvidia/cudnn/include \
    pip install --no-build-isolation transformer_engine[pytorch]; \
    cd /tmp && GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/NVIDIA/apex && \
    cd apex && git checkout e13873debc4699d39c6861074b9a3b2a02327f92 && pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation --config-settings "--build-option=--cpp_ext" --config-settings "--build-option=--cuda_ext" ./ && \
    cd / && rm -fr /tmp/apex && pip cache purge; \
    pip install git+https://github.com/NVIDIA/Megatron-LM.git@core_r0.16.0; \
elif [ "$IMAGE_TYPE" = "llm" ]; then \
    pip install --no-cache-dir huggingface-hub transformers peft diffusers -U; \
    pip uninstall autoawq -y; \
else \
    pip install "transformers<4.56" "tokenizers<0.22" "trl<0.23" "diffusers<0.35" --no-dependencies; \
fi

# install nvm and set node version to 18
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install 22 && \
    nvm use 22

RUN rm -f /etc/apt/sources.list.d/cuda-*.list && apt-get update
RUN pip install transformers==5.3.0
RUN pip install qwen_vl_utils
RUN pip install ninja`
RUN pip install flash-attn --no-build-isolation
RUN pip install "git+https://github.com/NVIDIA/TransformerEngine.git@v2.12" --no-build-isolation --force-reinstall --no-deps

ENV VLLM_USE_MODELSCOPE=True
ENV LMDEPLOY_USE_MODELSCOPE=True
ENV MODELSCOPE_CACHE=/mnt/workspace/.cache/modelscope/hub
SHELL ["/bin/bash", "-c"]