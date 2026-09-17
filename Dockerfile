FROM public.ecr.aws/docker/library/ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517

LABEL org.opencontainers.image.title="ubuntu-lean-mathlib"
LABEL org.opencontainers.image.description="Ubuntu with Lean, Mathlib, comparator, and verifier dependencies"
LABEL org.opencontainers.image.source="https://github.com/zhihan/ubuntu-lean-mathlib"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git ca-certificates build-essential python3 python3-pip \
      wget zstd tzdata \
    && ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime \
    && rm -rf /var/lib/apt/lists/*

ENV LEAN_VERSION=v4.34.0
ENV ELAN_HOME=/root/.elan
ENV PATH=/root/.elan/bin:$PATH

RUN curl -fsSL https://elan.lean-lang.org/elan-init.sh \
      | sh -s -- -y --default-toolchain leanprover/lean4:${LEAN_VERSION} \
    && lean --version \
    && lake --version

WORKDIR /workspace
RUN echo "leanprover/lean4:${LEAN_VERSION}" > lean-toolchain
COPY lakefile.toml /workspace/lakefile.toml

RUN lake update && lake exe cache get

ENV COMPARATOR_REV=d03acab154d269c06e60e4de7e4cc85deebff94b
RUN git clone https://github.com/leanprover/comparator /tmp/comparator \
    && cd /tmp/comparator \
    && git checkout --detach "${COMPARATOR_REV}" \
    && echo "leanprover/lean4:${LEAN_VERSION}" > lean-toolchain \
    && lake build lean4export comparator \
    && install -m 0755 .lake/build/bin/comparator /usr/local/bin/comparator \
    && install -m 0755 .lake/packages/lean4export/.lake/build/bin/lean4export \
         /usr/local/bin/lean4export \
    && install -m 0755 scripts/fake-landrun.sh /usr/local/bin/fake-landrun \
    && rm -rf /tmp/comparator

ARG INSTALL_LANDRUN=0
ENV LANDRUN_TAG=v0.1.14
ENV LANDRUN_SHA256_AMD64=645178e3239cd33760560834e50efea0864183a2a8a82faf199760dffee6dd71
RUN if [ "$INSTALL_LANDRUN" = "1" ]; then \
      arch="$(dpkg --print-architecture)"; \
      test "$arch" = "amd64"; \
      curl -fsSL "https://github.com/Zouuup/landrun/releases/download/${LANDRUN_TAG}/landrun-linux-amd64" \
        -o /usr/local/bin/landrun; \
      echo "${LANDRUN_SHA256_AMD64}  /usr/local/bin/landrun" | sha256sum -c -; \
      chmod 0755 /usr/local/bin/landrun; \
    fi

RUN python3 -m pip install --break-system-packages --no-cache-dir \
      pytest==8.4.1 pytest-json-ctrf==0.3.5

RUN lake env printenv LEAN_PATH > /workspace/.lean_path
