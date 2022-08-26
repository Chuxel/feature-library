FROM mcr.microsoft.com/devcontainers/base:ubuntu as root-with-sudo
RUN usermod -u 3000 vscode

FROM ubuntu as root-without-sudo
RUN groupadd --gid 3000 vscode \
    && useradd --uid 3000 --gid 3000 -m vscode

FROM root-with-sudo as nonroot-with-sudo
USER vscode

FROM root-without-sudo as nonroot-without-sudo
USER vscode
