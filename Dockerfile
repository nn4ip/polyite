FROM ubuntu:16.04

ARG ARG_BASE_DIR=/root/polyite-project \
	DEBIAN_FRONTEND=noninteractive
ENV BASE_DIR=${ARG_BASE_DIR}
ENV	LLVM_ROOT=${BASE_DIR}/llvm_root \
	ISL_INSTALL=${BASE_DIR}/isl/install \
	ISL_UTILS_ROOT=${BASE_DIR}/scala-isl-utils \
	BARVINOK_INSTALL=${BASE_DIR}/barvinok/install \
	BARVINOK_BINARY_ROOT=${BASE_DIR}/barvinok_binary \
	CHERNIKOVA_ROOT=${BASE_DIR}/chernikova \
	POLYITE_ROOT=${BASE_DIR}/polyite
ENV LD_LIBRARY_PATH=${BARVINOK_INSTALL}/lib

SHELL ["/bin/bash", "-c"]
RUN	apt update \
	&& apt install -y git cmake python clang libclang-dev llvm \
	default-jdk autoconf libtool libgmp-dev libz-dev zip g++ \
	wget \
	&& git config --global url."https://hub.fastgit.org/".insteadOf "https://github.com/" \
	&& mkdir ${BASE_DIR} \
	&& cd $BASE_DIR \
	&& git clone https://github.com/nn4ip/polyite.git \
	&& mkdir ${LLVM_ROOT} \
	&& cd ${LLVM_ROOT} \
	&& git clone https://github.com/stganser/llvm.git \
	&& cd ${LLVM_ROOT}/llvm/tools \
	&& git clone https://github.com/stganser/clang.git \
	&& git clone https://github.com/stganser/polly.git \
	&& mkdir ${LLVM_ROOT}/llvm_build \
	&& cd ${LLVM_ROOT}/llvm_build \
	&& cmake ${LLVM_ROOT}/llvm \
	&& make -j32 \
	&& cd $BASE_DIR \
	&& git clone https://github.com/stganser/isl.git \
	&& cd isl \
	&& mkdir $ISL_INSTALL \
	&& ./autogen.sh \
	&& ./configure --prefix=$ISL_INSTALL --with-jni-include=/usr/lib/jvm/default-java/include/ --with-clang=system \
	&& make install -j32 \
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
	&& cp ${ISL_INSTALL}/lib/libisl*so* libs \
	&& cd ${BASE_DIR} \
	&& wget https://libntl.org/ntl-10.5.0.tar.gz \
	&& tar -xzf ntl-10.5.0.tar.gz && rm ntl-10.5.0.tar.gz \
	&& cd ntl-10.5.0 && mkdir install \
	&& cd src \
	&& ./configure NTL_GMP_LIP=on PREFIX=${BASE_DIR}/ntl-10.5.0/install GMP_PREFIX=/usr/lib/x86_64-linux-gnu SHARED=on \
	&& make -j32 \
	&& make install \
	&& cd $BASE_DIR \
	&& git clone http://repo.or.cz/barvinok.git \
	&& cd ${BASE_DIR}/barvinok && mkdir install \
	&& git checkout barvinok-0.39 \
	&& git submodule init && git submodule update \
    && sh autogen.sh \
	&& ./configure --prefix=$BARVINOK_INSTALL --with-ntl-prefix=${BASE_DIR}/ntl-10.5.0/install --with-gmp-prefix=/usr/lib/x86_64-linux-gnu --enable-shared-barvinok \
	&& make -j32 && make install \
	&& cd $BASE_DIR \
	&& git clone https://github.com/stganser/barvinok_binary.git \
	&& cd barvinok_binary \
	&& clang -std=c99 -I${BARVINOK_INSTALL}/include -L${BARVINOK_INSTALL}/lib count_integer_points.c -lbarvinok -lisl -o count_integer_points \
	&& cd $BASE_DIR \
	&& git clone https://github.com/stganser/chernikova.git

