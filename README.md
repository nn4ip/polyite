# Polyite: Iterative Schedule Optimization for Parallelization in the Polyhedron Model

> Note for Docker: to use numactl, use `docker run --privileged` to give sufficient privileges for set_mempolicy and setting membind.

## Description
  Polyite is a tool that iteratively optimizes the schedule of a program that is
  representable in the [Polyhedron Model](http://polyhedral.info) in order to
  exploit the computing capacity of a given multi-core hardware.

  The exploration of the schedule search space can be done either at random or
  in a guided fashion using a genetic algorithm.

  We describe the approach in detail in our TACO'2017 article [Iterative
  Schedule Optimization for Parallelization in the Polyhedron
  Model](https://stganser.bitbucket.io/taco2017/).

## Legal
  Polyite is released under MIT license.

  Polyite depends on LLVM, Clang, Polly, isl, libbarvinok and Armin Größlinger's
  implementation of Chernikova's algorithm. LLVM, Clang and Polly are released
  under the LLVM Release License or derivates of it. isl and Chernikova are
  released under MIT license. libbarvinok is GPL licensed.

## Installation and Setup
  The following installation steps have been tested on Ubuntu 18.04.

  We start from the bottom up with the dependences of Polyite and install
  everything inside the same directory, which could be your IDE's workspace.

  We explain how to get Polyite running for the benchmarks from the [Polybench
  4.1](http://web.cse.ohio-state.edu/~pouchet.2/software/polybench/) benchmark
  suite.

### Begin

  The following are some environments variables that are needed both at compile-time and run-time. You may need to add them to somewhere like `~/.bashrc` to make them available across sessions - which is required for the measurement and preparation scripts to run correctly. Otherwise you'll need to modify the corresponding variables in `measure_polybench.sh`, `polybench_scripts/*`.

  ```bash
  export BASE_DIR=$PWD
  export POLYITE_ROOT=${BASE_DIR}/polyite
  export LLVM_ROOT=${BASE_DIR}/llvm_root
  export LLVM381=${BASE_DIR}/llvm-3.8.1
  export ISL_INSTALL=${BASE_DIR}/isl/install
  export ISL_UTILS_ROOT=${POLYITE_ROOT}/scala-isl-utils
  export BARVINOK_INSTALL=${BASE_DIR}/barvinok/install
  export BARVINOK_BINARY_ROOT=${BASE_DIR}/barvinok_binary
  export CHERNIKOVA_ROOT=${POLYITE_ROOT}/chernikova

  export LD_LIBRARY_PATH=${BARVINOK_INSTALL}/lib:${LD_LIBRARY_PATH}
  ```

  ```bash
  cd ${BASE_DIR}
  git clone https://github.com/stganser/polyite.git
  ```

### Polly/LLVM
  Polyite uses an extended version of Polly (we provide a version of 3.9.1 and
  the older version of January, 2016 that we refer to in our publications) that
  is capable of importing schedule trees from our extended JSCOP format and
  further transforming the imported schedules, for instance by tiling them.
  Therefore, you must clone LLVM, Clang and Polly from our specially provided
  repositories.

  1. Create a root directory for LLVM
  ```bash
  mkdir llvm_root
  ```

  2. Clone LLVM
  ```bash
  cd ${LLVM_ROOT}
  git clone https://github.com/stganser/llvm.git
  ```

  3. Get Clang
  ``` bash
  cd ${LLVM_ROOT}/llvm/tools
  git clone https://github.com/stganser/clang.git
  ```

  4. Get Polly
  ```bash
  cd ${LLVM_ROOT}/llvm/tools
  git clone https://github.com/stganser/polly.git
  ```

  5. Create a build directory for LLVM and build it using cmake

  It is best to use a GCC with version before 7, otherwise there may be compilation errors like "undeclared std::function". On Ubuntu 18.04, you can install by running `sudo apt install gcc-6 g++-6`.

  ```bash
  mkdir ${LLVM_ROOT}/llvm_build
  mkdir ${LLVM_ROOT}/install
  cd ${LLVM_ROOT}/llvm_build
  export CC=gcc-6
  export CXX=g++-6
  cmake ${LLVM_ROOT}/llvm -DCMAKE_INSTALL_PREFIX=${LLVM_ROOT}/install
  make
  make install
  ```
  

### LLVM 3.8 for Building isl
  You may need to use LLVM 3.8 for building this version of isl.

  ```bash
  cd ${BASE_DIR}
  wget https://releases.llvm.org/3.8.1/llvm-3.8.1.src.tar.xz
  tar -xf llvm-3.8.1.src.tar.xz
  rm llvm-3.8.1.src.tar.xz
  mv llvm-3.8.1.src $LLVM381
  cd $LLVM381/tools
  wget https://releases.llvm.org/3.8.1/cfe-3.8.1.src.tar.xz
  tar -xf cfe-3.8.1.src.tar.xz
  rm cfe-3.8.1.src.tar.xz
  mv cfe-3.8.1.src clang
  cd ..
  mkdir build install
  cd build
  cmake -G Ninja -DCMAKE_INSTALL_PREFIX="${LLVM381}/install" ..
  cmake --build . --target install
  cmake --build . --target clean
  ```

### isl Scala Bindings
  1. Make sure you have libgmp and libclang (version 3.8) (both including headers) installed on your system, as well as libtool.

  2. Get JDK 8
  ```bash
  sudo apt install openjdk-8-jdk
  ```
  You may need to manually select Java 8 as default if you have other versions installed.
  ```bash
  sudo update-alternatives --config java
  ```

  2. Get Scala 2.11.6
  ```bash
  cd ${BASE_DIR}
  wget https://downloads.lightbend.com/scala/2.11.6/scala-2.11.6.tgz
  tar -xzf scala-2.11.6.tgz && rm scala-2.11.6.tgz
  export SCALAC=${BASE_DIR}/scala-2.11.6/bin/scalac
  ```

  3. Get and build isl
  ```bash
  cd ${BASE_DIR}
  git clone https://github.com/stganser/isl.git
  cd isl
  mkdir install
  ./autogen.sh
  ./configure --prefix=${ISL_INSTALL} --with-jni-include=/usr/lib/jvm/java-1.8.0-openjdk-amd64/include/ --with-clang-prefix="${LLVM381}/install/"
  make install
  ```

  4. Generate the bindings
  ```bash
  cd ${BASE_DIR}/isl/interface
  make isl-scala.jar
  cp -r java/gen src
  cp scala/src/isl/Conversions.scala src/isl
  zip -r isl-scala.jar src
  ```
  The last three steps include the source code of the bindings into the
  generated library.

### Wrapper for the isl Scala Bindings
  This subproject makes the isl Scala bindings accessible to Polyite.

  1. Clone the repository:
  ```bash
  cd ${POLYITE_ROOT}
  git clone https://github.com/stganser/scala-isl-utils.git
  cd ${ISL_UTILS_ROOT}
  mkdir lib
  cp ${BASE_DIR}/isl/interface/isl-scala.jar lib
  cp ${ISL_INSTALL}/lib/libisl*so* lib
  ```

### Barvinok Library
  libbarvinok provides an implementation of Barvinok's counting algorithm, which
  can be used to determine a polyhedron's volume. Since we do not have Scala
  bindings for libbarvinok, Polyite calls a small C-binary when it needs to
  determine a polyhedron's volume.

  1. Install barvinok
  ```bash
  cd ${BASE_DIR}
  git clone http://repo.or.cz/barvinok.git
  cd barvinok
  git checkout barvinok-0.39
  git submodule init && git submodule update
  wget https://libntl.org/ntl-10.5.0.tar.gz
  tar -xzf ntl-10.5.0.tar.gz && rm ntl-10.5.0.tar.gz
  cd ntl-10.5.0 && mkdir install
  cd src
  ./configure NTL_GMP_LIP=on PREFIX=${BASE_DIR}/barvinok/ntl-10.5.0/install GMP_PREFIX=/usr/lib/x86_64-linux-gnu SHARED=on
  make
  make install

  cd ${BASE_DIR}/barvinok
  mkdir install
  sh autogen.sh
  ./configure --prefix=${BARVINOK_INSTALL} --with-ntl-prefix=${BASE_DIR}/barvinok/ntl-10.5.0/install --with-gmp-prefix=/usr/lib/x86_64-linux-gnu --enable-shared-barvinok
  make
  make install
  ```

  2. Build the binary wrapper
  ```bash
  cd ${BASE_DIR}
  git clone https://github.com/stganser/barvinok_binary.git
  cd barvinok_binary
  clang -std=c99 -I${BARVINOK_INSTALL}/include -L${BARVINOK_INSTALL}/lib count_integer_points.c -lbarvinok -lisl -o count_integer_points
  export BARVINOK_BINARY_ROOT=${BASE_DIR}/barvinok_binary
  ```


### Chernikova
  This Scala library provides an implementation of Chernikova's algorithm to
  switch between the constraints representation and the generator representation
  of polyhedra.

  ```bash
  cd ${POLYITE_ROOT}
  git clone https://github.com/stganser/chernikova.git
  ```

### OpenMPI
  Build OpenMPI with Java interface.
  ```bash
  cd ${BASE_DIR}
  wget -O - https://download.open-mpi.org/release/open-mpi/v2.1/openmpi-2.1.1.tar.gz | tar -xz
  cd openmpi-2.1.1
  mkdir install
  ./configure --prefix=${BASE_DIR}/openmpi-2.1.1/install --enable-mpi-java
  make all
  make install
  mkdir -p ${BASE_DIR}/polyite/lib
  cp ${BASE_DIR}/openmpi-2.1.1/install/lib/mpi.jar ${BASE_DIR}/polyite/lib/
  ```

### Compile Scala package

  1. Reorganize directory structure for sbt
  ```bash
  cd ${ISL_UTILS_ROOT}
  mkdir -p src/main/scala
  mv src/isl/ src/main/scala/
  cd ${CHERNIKOVA_ROOT}
  mkdir -p src/main/scala
  mv src/org/ src/main/scala/
  ```

  2. Install sbt and compile
  ```bash
  echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
  echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | sudo tee /etc/apt/sources.list.d/sbt_old.list
  curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo -H gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import
  sudo chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg
  sudo apt update
  sudo apt install sbt
  ```

  ```bash
  cd ${POLYITE_ROOT}
  cp docker/lib/* lib/
  sbt package
  ```


### Polyite
  The following steps describe how to put everything
  together to run benchmarks from Polybench 4.1.

  0. Some prerequisites to install:
  ```bash
  sudo apt install numactl libz-dev libpapi-dev
  ```

  1. To use Polyite, one must execute one of the following scripts, depending on
    the desired execution mode. The scripts assume that you have OpenJDK 8
    installed in `/usr/lib/jvm/java-1.8.0-openjdk-amd64/` (the default location
    on Debian based systems).
    * `run_genetic_opt` to execute the genetic algorithm
    * `run_rand_exploration` to execute random exploration
    * `run_rand_exploration_letsee` to execute random exploration using the
    search space construction described in Pouchet et al., PLDI'08.

    The script `print_scop_size` extracts several SCoP metrics during benchmark
    preparation.

    In each of the scripts, set
    * `ISL_UTILS_LOC` to the value of `${ISL_UTILS_ROOT}`
    * `POLYITE_LOC` to the value of `${POLYITE_ROOT}`
    * `CHERNIKOVA_LOC` to the value of `${CHERNIKOVA_ROOT}`

  2. To compile and execute a schedule in order to determine its profitability,
    Polyite starts the script `measure_polybench.bash`. At the top of script,
    set `POLLY_INSTALL_DIR` to the value of `${LLVM_ROOT}/llvm_build`.

  3. The scripts in `${POLYITE_ROOT}/polybench_scripts/` are used to prepare
    Polybench 4.1 benchmarks for optimization with Polyite. They generate
    prepared LLVM-IR code, execute baseline measurements, compute reference
    output and generate configuration files for random exploration or
    optimization with the genetic algorithm.
    * In `measureBaseline.bash` set `POLLY_INSTALL_DIR` to the value of
      `${LLVM_ROOT}/llvm_build`.
    * In `prepare_benchmarks.bash` set `POLLY_INSTALL_DIR` to the value of
      `${LLVM_ROOT}/llvm_build` and `POLYITE_LOC` to the value of
      `{POLYITE_ROOT}`. This script can later be called to prepare a list of
      Polybench 4.1 benchmarks. You may want to adapt the values of the default
      configuration files that the script generates for each benchmark. Compile
      `${POLYITE_ROOT}/config_help.tex` to get a documentation of Polyite's   
      configuration options.
    * The file `polly_configurations.txt` contains a list of Polly configurations
    that `prepare_benchmarks.bash` considers during the baseline measurements.

    Install `libpapi` version 5.4.3.

  4. Download [Polybench 4.1](https://sourceforge.net/projects/polybench/files/polybench-c-4.1.tar.gz/download) and unpack the archive to `${POLYITE_ROOT}/polybench-c-4.1`.

  ```bash
  cd ${POLYITE_ROOT}
  cat docker/polybench-c-4.1.tar.gz | tar -xz
  ```

  5. Create symbolic links in `polybench-c-4.1`:
  ```bash
  cd ${POLYITE_ROOT}/polybench-c-4.1
  ln -s ../polybench_scripts/baselineCollectData.bash baselineCollectData.bash
  ln -s ../polybench_scripts/polly_configurations.txt polly_configurations.txt
  ln -s ../polybench_scripts/benchmarks.txt benchmarks.txt
  ln -s ../polybench_scripts/collectAllBaselineResults.bash collectAllBaselineResults.bash
  ln -s ../polybench_scripts/generateRefOut.bash generateRefOut.bash
  ln -s ../polybench_scripts/measureBaseline.bash measureBaseline.bash
  ln -s ../polybench_scripts/prepare_benchmarks.bash prepare_benchmarks.bash
  ```

## Usage
  Most tools that are part of Polyite will print a help message if invoked without command line parameters.

  To prepare benchmark gemm perform the following steps:
  ```bash
  cd ${POLYITE_ROOT}/polybench-c-4.1
  ./prepare_benchmarks.bash true false false gemm
  ```
  This creates the directory `polybench-c-4.1/gemm` with the following content:
  ```
  config_ga_gemm_kernel_gemm_%entry.split---%for.end40.properties
  config_rand_gemm_kernel_gemm_%entry.split---%for.end40.properties
  gemm.c
  gemm.h
  kernel_gemm___%entry.split---%for.end40.jscop
  polybench.c
  polybench.h
  ref_output
  ```
  There are

  * configuration files for random exploration and optimization with the genetic algorithm. To understand and modify these, compile and read `${POLYITE_ROOT}/config_help.tex`.
  * All source files that are required to compile the benchmark.
  * A JSCOP file that contains the model of the SCoP to optimize.
  * A file containing reference output that was produced by a binary compiled
    with -O0.


  To change the code regions to optimize (Polyite can optimize one SCoP at a
  time) or change data set sizes, edit the file
  `polybench-c-4.1/benchmarks.txt`.

  Now, you can run schedule optimization with the genetic algorithm:
  ```bash
  cd ${POLYITE_ROOT}
  ./run_genetic_opt polybench-c-4.1/gemm/kernel_gemm___%entry.split---%for.end40.jscop polybench-c-4.1/gemm/config_ga_gemm_kernel_gemm_%entry.split---%for.end40.properties
  ```
  Depending on your configuration, this produces one JSON file per generation of
  the genetic algorithm, one CSV file and a directory containing one JSCOP file
  per schedule for manual application of the generated schedules. The JSON files
  contain all attributes of the generated schedules and can be read by Polyite,
  for instance, in order to restart an interrupted run of the genetic algorithm
  or to generate further generations.

  Analogously, random exploration can be run, using

  ```bash
  cd ${POLYITE_ROOT}
  ./run_rand_exploration polybench-c-4.1/gemm/kernel_gemm___%entry.split---%for.end40.jscop polybench-c-4.1/gemm/config_rand_gemm_kernel_gemm_%entry.split---%for.end40.properties
  ```

  To use SLURM for the evaluation of your schedules, put something like the following into your configuration file:
  ```bash
  numMeasurementThreads=42
  measurementCommand=srun -Aduckdonald -pthebigcluster --constraint=fastest_cpu_available_plx --mem=32768 --exclusive -t31 -n1 ${POLYITE_ROOT}/measure_polybench.bash
  ```
  It is important to use `srun`, since Polyite must be able into interactively
  communicate with the benchmarking script via STDIN and STDOUT. Polyite can
  pass a given [numactl](https://github.com/numactl/numactl) configuration to
  the benchmarking script.

### Strip Mining (aka Pre-Vectorization)
In the evaluation of our papers about Polyite, pre-vectorization by Polly was
disabled (`-polly-vectorizer=none`). At least in Polly 3.8/3.9 Polyite will
break Polly's schedule tree optimization, as the pre-vectorizer operates on any
schedule tree band node that has a coincident member. Yet, Polly seems to
expect that coincident members occur only in band nodes whose iteration domain
contains a single statement. We provide the configuration option `expectPrevectorization` which, if set to `true`, will cause Polyite to process
schedule trees that will not break Polly's pre-vectorizer. This feature is experimental and is only meant as a basic support for pre-vectorization with
Polly. It is unclear, whether Polyite is suitable for a schedule search space
exploration with pre-vectorization enabled in its current state.

Suggestions for improvements are welcome :-)

### Schedule Classification
  Polyite has the ability to learn performance models from the results of
  previous iterative optimization runs. It can use these models to speed up
  iterative optimization process by using a classifier that can identify likely
  unprofitable schedules. To learn the classifier, Polyite relies on Python 3.5
  and [scikit-learn](http://scikit-learn.org/stable/) version 0.19.2. Follow
  their instructions for the installation of scikit-learn and its dependencies
  via `pip`.

  We provide tools for the generation of training data for the classifier. The
  data must originate from runs of Polyites random exploration or genetic
  algorithm during which benchmarking had been used to assess schedules fitness.

  The tool `merge_populations` can be used to merge sets of schedules and
  their evaluation results. These could for instance be the populations of a run
  of the genetic algorithm. Polyite writes each of these to a separate file. Merging schedules into a single file that belong to different SCoPs is impossible. `merge_populations` as the following command line interface:

  ```bash
  ./merge_populations <JSCOP file> <output JSON file> <output CSV file> <num. execution time measurements> <population files>
  ```
  1. A JSCOP file that represents the SCoP
  2. The output JSON file that will contain the merged set of schedules.
  3. A CSV file in Polyite's output CSV format that contains isl union map
    representations of the schedules in the merged set of schedules together
    with the results from benchmarking the schedules.
  4. The number of execution time measurements per schedule during the
      generating of the input data.
  5. The JSON files containing the input data.


  The tool `fitness_calculator` labels schedules and calculates their feature
  vectors. It has the following command line ínterface:
  ```bash
  ./fitness_calculator <JSCOP file> <configuration file> <input CSV file> <output CSV file>
  ```
  1. A JSCOP file that models the SCoP to which the schedules in the input CSV
  file corresponds.
  2. A CSV file contain the schedules to be labeled together with their measured execution times.
  3. The output CSV file that Polyite will use to train its classifier.

  Polyite can train its classifier using training data from multiple CSV files.
  Read the documentation of Polyite's configuration options for details.
<hr />
&copy; 2017-2019, Stefan Ganser
