# -----------------------------------------------------------------------------
#  Build Stage
#
#  We split the RUN layers to cache them separately to fasten the rebuild process
#  in case of build fails during multi-stage builds.
# -----------------------------------------------------------------------------
FROM --platform=linux/amd64 centos:7.9.2009 AS build

COPY run-test.sh /run-test.sh

# Install dependencies
RUN \
  yum install -y wget gcc tcl-devel make which
#   apk upgrade && \
#   apk add \
#     alpine-sdk \
#     build-base  \
#     tcl-dev \
#     tk-dev \
#     mesa-dev \
#     jpeg-dev \
#     libjpeg-turbo-dev

# Download latest release
RUN \
  wget --no-check-certificate\
    -O sqlite.tar.gz \
    https://www.sqlite.org/src/tarball/sqlite.tar.gz?r=release && \
  tar xvfz sqlite.tar.gz

# Configure and make SQLite3 binary
RUN \
  ./sqlite/configure --prefix=/usr && \
  make && \
  make install \
  && \
  # Smoke test
  sqlite3 --version && \
  /run-test.sh

# -----------------------------------------------------------------------------
#  Main Stage
# -----------------------------------------------------------------------------
FROM --platform=linux/amd64 centos:7.9.2009

COPY --from=build /usr/bin/sqlite3 /usr/bin/sqlite3
COPY run-test.sh /run-test.sh

# Create a user and group for SQLite3 to avoid: Dockle CIS-DI-0001
ENV \
  USER_SQLITE=sqlite \
  GROUP_SQLITE=sqlite
RUN \
  groupadd -r $GROUP_SQLITE && \
  useradd  -r $USER_SQLITE -g $GROUP_SQLITE

# Set user
USER $USER_SQLITE

# Run simple test
#RUN /run-test.sh

# Set container's default command as `sqlite3`
CMD /usr/bin/sqlite3

# Avoid: Dockle CIS-DI-0006
HEALTHCHECK \
  --start-period=1m \
  --interval=5m \
  --timeout=3s \
  CMD /usr/bin/sqlite3 --version || exit 1
