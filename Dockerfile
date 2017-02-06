FROM centos

# ryan.smith.p@gmail.com
MAINTAINER Ryan Smith

# ---------------------------------
# 1. Install prerequisites
# ---------------------------------

# SpeedSeq prerequisites
RUN yum -y update && \
    yum -y install \
        make \
        automake \
        cmake \
        gcc \
        gcc-c++ \
        git \
        ncurses-devel \
        zlib-devel \
        file

# Get Python 2.7 and modules
RUN yum install -y \
    lapack \
    lapack-devel \
    blas \
    blas-devel

RUN curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" && \
    python get-pip.py && \
    pip install \
        pysam \
        numpy \
        scipy

# CNVnator prerequisites
RUN yum -y install \
    libX11-devel \
    libXpm-devel \
    libXft-devel \
    libXext-devel

# Get ROOT, compile, source the ROOT config and add ROOT source to ~/.bashrc
RUN cd /tmp/ && \
    curl -OL https://root.cern.ch/download/root_v5.34.20.source.tar.gz && \
    tar -xvf root_v5.34.20.source.tar.gz && \
    cd root && \
    ./configure && \
    make && \
    cd .. && \
    mv root /usr/local && \
    rm -rf root_v5.34.20.source.tar.gz

# ---------------------------------
# 2. Install SpeedSeq core components
# ---------------------------------

# Get SpeedSeq
RUN mkdir ~/code && \
    cd ~/code && \
    git clone --recursive https://github.com/cc2qe/speedseq.git && \
    cd speedseq && \
    make

# ---------------------------------
# 3. Install VEP
# ---------------------------------

# Get required perl modules
RUN yum -y install \
    "perl(Archive::Extract)" \
    "perl(CGI)" \
    "perl(DBI)" \
    "perl(Time::HiRes)" \
    "perl(Archive::Tar)" \
    "perl(Archive::Zip)"

# Download and install VEP, 
# and copy executables to SpeedSeq directory
RUN cd ~ && \
    curl -OL https://github.com/Ensembl/ensembl-tools/archive/release/76.zip && \
    unzip 76.zip && \
    perl ensembl-tools-release-76/scripts/variant_effect_predictor/INSTALL.pl -c ~/code/speedseq/annotations/vep_cache -a ac -s homo_sapiens -y GRCh37 && \
    cp ensembl-tools-release-76/scripts/variant_effect_predictor/variant_effect_predictor.pl ~/code/speedseq/bin/. && \
    mv Bio ~/code/speedseq/bin/. && \
    rm -rf 76.zip ensembl-tools-release-76

# ---------------------------------
# 4. Prepare reference genome files
# ---------------------------------

# Get human reference GRCh37
# and make the CNVnator chroms
RUN mkdir -p ~/genomes && \
    cd ~/genomes && \
    curl -OL ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gz && \
    curl -OL ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.fai && \
    gunzip human_g1k_v37.fasta.gz && \
    bwa index ~/genomes/human_g1k_v37.fasta && \
    mkdir -p ~/code/speedseq/annotations/cnvnator_chroms && \
    cd ~/code/speedseq/annotations/cnvnator_chroms && \
    cat ~/genomes/human_g1k_v37.fasta | awk 'BEGIN { CHROM="" } { if ($1~"^>") CHROM=substr($1,2); print $0 > CHROM".fa" }'

# ---------------------------------
# 5. Install GEMINI
# ---------------------------------
RUN curl -OL https://raw.github.com/arq5x/gemini/master/gemini/scripts/gemini_install.py && \
    python gemini_install.py /usr/local /usr/local/share/gemini && \
    echo -e "export PATH=\$PATH:/usr/local/gemini/bin" >> ~/.bashrc && \
    source ~/.bashrc

ADD entry.sh /opt/bin

ENTRYPOINT ["/opt/bin/entry.sh"]

