FROM ubuntu:16.04
SHELL ["/bin/bash", "-c"]

ARG ARG_BASE_DIR=/root/polyite-project \
    DEBIAN_FRONTEND=noninteractive \
    NCORES=8

ENV BASE_DIR=${ARG_BASE_DIR}
ENV	LLVM_ROOT=${BASE_DIR}/llvm_root \
    ISL_INSTALL=${BASE_DIR}/isl/install \
    ISL_UTILS_ROOT=${BASE_DIR}/scala-isl-utils \
    BARVINOK_INSTALL=${BASE_DIR}/barvinok/install \
    BARVINOK_BINARY_ROOT=${BASE_DIR}/barvinok_binary \
    CHERNIKOVA_ROOT=${BASE_DIR}/chernikova \
    POLYITE_ROOT=${BASE_DIR}/polyite

# for barvinok shared libs
ENV LD_LIBRARY_PATH=${BARVINOK_INSTALL}/lib

RUN	apt update \
    && apt install -y git cmake python clang libclang-dev llvm \
    default-jdk autoconf libtool libgmp-dev libz-dev zip g++ wget libpapi-dev \
    && git config --global url."https://github.com.cnpmjs.org/".insteadOf "https://github.com/"

RUN mkdir ${BASE_DIR} \
    && cd $BASE_DIR \
    && git clone https://github.com/nn4ip/polyite.git \
    && mkdir ${LLVM_ROOT} libs \
    && cd ${LLVM_ROOT} \
    && git clone https://github.com/stganser/llvm.git \
    && cd ${LLVM_ROOT}/llvm/tools \
    && git clone https://github.com/stganser/clang.git \
    && git clone https://github.com/stganser/polly.git \
    && mkdir ${LLVM_ROOT}/llvm_build ${LLVM_ROOT}/install \
    && cd ${LLVM_ROOT}/llvm_build \
    && cmake ${LLVM_ROOT}/llvm -DCMAKE_INSTALL_PREFIX=${LLVM_ROOT}/install \
    && make -j${NCORES} \
    && make install \
    && make clean

RUN cd $BASE_DIR \
    && git clone https://github.com/stganser/isl.git \
    && cd isl \
    && mkdir $ISL_INSTALL \
    && ./autogen.sh \
    && ./configure --prefix=$ISL_INSTALL --with-jni-include=/usr/lib/jvm/default-java/include/ --with-clang=system \
    && make install -j${NCORES} \
    && cd ${BASE_DIR}/isl/interface \
    && make isl-scala.jar \
    && cp -r java/gen src \
    && cp scala/src/isl/Conversions.scala src/isl \
    && zip -r isl-scala.jar src \
    && cd $BASE_DIR \
    && git clone https://github.com/stganser/scala-isl-utils.git \
    && cd ${BASE_DIR}/scala-isl-utils \
    && mkdir libs \
    && cp ${BASE_DIR}/isl/interface/isl-scala.jar libs \
    && cp ${ISL_INSTALL}/lib/libisl*so* libs

COPY libs/* ${POLYITE_ROOT}/libs/
COPY *.tar.gz ${BASE_DIR}/

RUN cd ${BASE_DIR} \
    && tar -xzf ntl-10.5.0.tar.gz && rm ntl-10.5.0.tar.gz \
    && cd ntl-10.5.0 && mkdir install \
    && cd src \
    && ./configure NTL_GMP_LIP=on PREFIX=${BASE_DIR}/ntl-10.5.0/install GMP_PREFIX=/usr/lib/x86_64-linux-gnu SHARED=on \
    && make -j${NCORES} \
    && make install \
    && cd $BASE_DIR \
    && git clone http://repo.or.cz/barvinok.git \
    && cd ${BASE_DIR}/barvinok && mkdir install \
    && git checkout barvinok-0.39 \
    && git submodule init && git submodule update \
    && sh autogen.sh \
    && ./configure --prefix=$BARVINOK_INSTALL --with-ntl-prefix=${BASE_DIR}/ntl-10.5.0/install --with-gmp-prefix=/usr/lib/x86_64-linux-gnu --enable-shared-barvinok \
    && make -j${NCORES} && make install \
    && cd $BASE_DIR \
    && git clone https://github.com/stganser/barvinok_binary.git \
    && cd barvinok_binary \
    && clang -std=c99 -I${BARVINOK_INSTALL}/include -L${BARVINOK_INSTALL}/lib count_integer_points.c -lbarvinok -lisl -o count_integer_points \
    && cd $BASE_DIR \
    && git clone https://github.com/stganser/chernikova.git

RUN cd $BASE_DIR && tar -xzf openmpi-2.1.1.tar.gz && rm openmpi-2.1.1.tar.gz \
    && cd openmpi-2.1.1 && mkdir install \
    && ./configure --prefix=${BASE_DIR}/openmpi-2.1.1/install --enable-mpi-java \
    && make all -j${NCORES} \
    && make install \
    && cp ${BASE_DIR}/openmpi-2.1.1/install/lib/mpi.jar ${POLYITE_ROOT}/libs/

RUN apt install -y apt-transport-https curl sudo \
    && echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list \
    && echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | sudo tee /etc/apt/sources.list.d/sbt_old.list \
    && curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo -H gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import \
    && sudo chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg \
    && apt update \
    && apt install sbt

RUN cd ${BASE_DIR} \
    && tar -xzf polybench-c-4.1.tar.gz && mv polybench-c-4.1 ${POLYITE_ROOT}/ \
    && rm polybench-c-4.1.tar.gz \
    && cd ${POLYITE_ROOT}/polybench-c-4.1 \
    && ln -s ../polybench_scripts/baselineCollectData.bash baselineCollectData.bash \
    && ln -s ../polybench_scripts/polly_configurations.txt polly_configurations.txt \
    && ln -s ../polybench_scripts/benchmarks.txt benchmarks.txt \
    && ln -s ../polybench_scripts/collectAllBaselineResults.bash collectAllBaselineResults.bash \
    && ln -s ../polybench_scripts/generateRefOut.bash generateRefOut.bash \
    && ln -s ../polybench_scripts/measureBaseline.bash measureBaseline.bash \
    && ln -s ../polybench_scripts/prepare_benchmarks.bash prepare_benchmarks.bash