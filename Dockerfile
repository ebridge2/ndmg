FROM neurodata/fsl_1604:0.0.1
MAINTAINER Eric Bridgeford <ericwb95@gmail.com>

#--------Environment Variables-----------------------------------------------#
ENV NDMG_URL https://github.com/neurodata/ndmg.git
ENV ATLASES http://openconnecto.me/mrdata/share/eric_atlases/eric_atlases.zip
ENV AFNI_URL https://files.osf.io/v1/resources/fvuh8/providers/osfstorage/5a0dd9a7b83f69027512a12b
ENV LIBXP_URL http://mirrors.kernel.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_amd64.deb 
ENV LIBPNG_URL http://mirrors.kernel.org/debian/pool/main/libp/libpng/libpng12-0_1.2.49-1%2Bdeb7u2_amd64.deb

#--------Initial Configuration-----------------------------------------------#
# download/install basic dependencies, and set up python
RUN apt-get update
RUN apt-get install -y zip unzip vim git python-dev curl libglu1
RUN echo "ln -s /usr/lib/x86_64-linux-gnu/libgsl.so /usr/lib/libgsl.so.0" >> ~/.bashrc

RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py

RUN apt-get update

RUN \
    apt-get install -y git libpng-dev libfreetype6-dev pkg-config \
    zlib1g-dev g++ vim r-base-core libgsl-dev


#---------AFNI INSTALL--------------------------------------------------------#
# setup of AFNI, which provides robust modifications of many of neuroimaging
# algorithms
RUN apt-get update -qq && apt-get install -yq --no-install-recommends ed gsl-bin libglu1-mesa-dev libglib2.0-0 libglw1-mesa \
    libgomp1 libjpeg62 libxm4 netpbm tcsh xfonts-base xvfb && \
    libs_path=/usr/lib/x86_64-linux-gnu && \
    if [ -f $libs_path/libgsl.so.19 ]; then \
           ln $libs_path/libgsl.so.19 $libs_path/libgsl.so.0; \
    fi && \
    echo "Install libxp (not in all ubuntu/debian repositories)" && \
    apt-get install -yq --no-install-recommends libxp6 \
    || /bin/bash -c " \
       curl --retry 5 -o /tmp/libxp6.deb -sSL \
       && dpkg -i /tmp/libxp6.deb && rm -f /tmp/libxp6.deb $LIBXP_URL" && \
    echo "Install libpng12 (not in all ubuntu/debian repositories" && \
    apt-get install -yq --no-install-recommends libpng12-0 \
    || /bin/bash -c " \
       curl -o /tmp/libpng12.deb -sSL $LIBPNG_URL \
       && dpkg -i /tmp/libpng12.deb && rm -f /tmp/libpng12.deb" && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /opt/afni && \
    curl -o afni.tar.gz -sSLO "$AFNI_URL" && \
    tar zxv -C /opt/afni --strip-components=1 -f afni.tar.gz && \
    rm -rf afni.tar.gz
ENV PATH=/opt/afni:$PATH

#--------NDMG SETUP-----------------------------------------------------------#
# setup of python dependencies for ndmg itself, as well as file dependencies
RUN \
    pip install numpy==1.12.1 networkx>=1.11 nibabel>=2.0 dipy>=0.1 scipy \
    python-dateutil==2.6.1 boto3 awscli matplotlib==1.5.3 plotly==1.12.1 nilearn>=0.2 sklearn>=0.0 \
    pandas cython

RUN \
    git clone -b m3r-release $NDMG_URL /ndmg && \
    cd /ndmg && \
    python setup.py install 

RUN \
    mkdir /ndmg_atlases && \
    cd /ndmg_atlases && \
    aws s3 cp --no-sign-request s3://mrneurodata/resources/ndmg_atlases.zip ./ && \
    unzip ndmg_atlases.zip


# copy over the entrypoint script
ADD ./.vimrc .vimrc

# and add it as an entrypoint
ENTRYPOINT ["ndmg_bids"]
