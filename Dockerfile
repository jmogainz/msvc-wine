FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y wine64-development python3 msitools python3-simplejson \
                       python3-six ca-certificates && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Initialize the wine environment. Wait until the wineserver process has
# exited before closing the session, to avoid corrupting the wine prefix.
RUN wine64 wineboot --init && \
    while pgrep wineserver > /dev/null; do sleep 1; done

WORKDIR /opt/msvc

COPY lowercase fixinclude install.sh vsdownload.py msvctricks.cpp ./
COPY wrappers/* ./wrappers/

RUN PYTHONUNBUFFERED=1 ./vsdownload.py --accept-license --dest /opt/msvc && \
    ./install.sh /opt/msvc && \
    rm lowercase fixinclude install.sh vsdownload.py && \
    rm -rf wrappers

COPY msvcenv-native.sh /opt/msvc

RUN apt-get update && \
    apt-get install -y g++ wget cmake && \
    apt-get install -y winbind && \
    apt-get install -y supervisor && \
    apt-get install -y zsh && \
    apt-get install -y git && \
    apt-get install -y vim && \
    apt-get install -y sudo && \
    apt-get install -y curl

# Install CMake 3.23
RUN wget https://github.com/Kitware/CMake/releases/download/v3.23.0/cmake-3.23.0-Linux-x86_64.sh && \
    chmod +x cmake-3.23.0-Linux-x86_64.sh && \
    ./cmake-3.23.0-Linux-x86_64.sh --skip-license --prefix=/usr/local

RUN wget https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.gz && \
    tar -xvf binutils-2.42.tar.gz && \
    cd binutils-2.42 && \
    ./configure && \
    make && \
    make install

# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && chsh -s $(which zsh)

# Modify .bashrc
RUN echo "export PATH=/usr/local/bin:\$PATH" >> ~/.zshrc && \
    echo "export PATH=/opt/msvc/bin/x64:\$PATH" >> ~/.zshrc && \
    echo "alias msvc-cmake='CC=cl CXX=cl cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER_WORKS=1 -DCMAKE_CXX_COMPILER_WORKS=1 -DCMAKE_INSTALL_PREFIX=./../install'" >> ~/.zshrc

# Configure Supervisor to keep the container running
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Default command to run Supervisor
CMD ["/usr/bin/supervisord"]

# Later stages which actually uses MSVC can ideally start a persistent
# wine server like this:
#RUN wineserver -p && \
#    wine64 wineboot && \
