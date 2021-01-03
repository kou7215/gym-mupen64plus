################################################################
#FROM ubuntu:xenial-20170915 AS base
FROM nvidia/cuda:10.1-cudnn7-devel-ubuntu16.04 AS base


# Setup environment variables in a single layer
ENV \
    # Prevent dpkg from prompting for user input during package setup
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    # mupen64plus will be installed in /usr/games/; add to the $PATH
    PATH=$PATH:/usr/games/ \
    # Set default DISPLAY
    DISPLAY=:0


################################################################
FROM base AS buildstuff

RUN apt update && apt upgrade -y
RUN apt install -y \
        build-essential dpkg-dev libwebkitgtk-dev libjpeg-dev libtiff-dev libgtk2.0-dev \
        libsdl1.2-dev libgstreamer-plugins-base1.0-dev libnotify-dev freeglut3 freeglut3-dev \
        libjson-c2 libjson-c-dev \
        git wget
#RUN wget http://de.archive.ubuntu.com/ubuntu/pool/main/j/json-c/libjson-c2_0.11-4ubuntu2_i386.deb
#RUN dpkg -i libjson-c2_0.11-4ubuntu2_i386.deb

# clone, build, and install the input bot
# (explicitly specifying commit hash to attempt to guarantee behavior within this container)
WORKDIR /src/mupen64plus-src
RUN git clone https://github.com/mupen64plus/mupen64plus-core && \
        cd mupen64plus-core && \
        git reset --hard 12d136dd9a54e8b895026a104db7c076609d11ff && \
    cd .. && \
    git clone https://github.com/kevinhughes27/mupen64plus-input-bot && \
        cd mupen64plus-input-bot && \
        git reset --hard 40eff412eca6491acb7f70932b87b404c9c3ef70 && \
    make all && \
    make install
RUN apt update && apt upgrade -y

################################################################
FROM base

# Update package cache and install dependencies
RUN apt update && apt upgrade -y
RUN apt install -y \
        python3 python3-pip python3-dev \
        wget \
        xvfb libxv1 x11vnc \
        imagemagick \
        mupen64plus \
        nano \
        ffmpeg \
        libjson-c-dev

# Upgrade pip
RUN pip3 install --upgrade pip

# install VirtualGL (provides vglrun to allow us to run the emulator in XVFB)
# (Check for new releases here: https://github.com/VirtualGL/virtualgl/releases)
ENV VIRTUALGL_VERSION=2.5.2
RUN wget "https://sourceforge.net/projects/virtualgl/files/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb" && \
    apt install ./virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    rm virtualgl_${VIRTUALGL_VERSION}_amd64.deb

# Copy compiled input plugin from buildstuff layer
COPY --from=buildstuff /usr/local/lib/mupen64plus/mupen64plus-input-bot.so /usr/local/lib/mupen64plus/

# Copy the gym environment (current directory)
COPY . /src/gym-mupen64plus
# Copy the Super Smash Bros. save file to the mupen64plus save directory
# mupen64plus expects a specific filename, hence the awkward syntax and name
COPY ["./gym_mupen64plus/envs/Smash/smash.sra", "/root/.local/share/mupen64plus/save/Super Smash Bros. (U) [!].sra"]

# Install requirements & this package
# Declare ROMs as a volume for mounting a host path outside the container
VOLUME /src/gym-mupen64plus
WORKDIR /src/gym-mupen64plus

# jupyter lab
RUN apt install nodejs npm -y
RUN npm install -g n
RUN n stable
RUN apt purge nodejs npm -y
RUN pip install -r requirements.txt
RUN jupyter serverextension enable --py jupyterlab
RUN jupyter labextension install jupyterlab_vim

# Expose the default VNC port for connecting with a client/viewer outside the container
EXPOSE 5900
# for jupyter lab
EXPOSE 8888
