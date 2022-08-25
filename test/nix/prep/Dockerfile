FROM mcr.microsoft.com/devcontainers/base:ubuntu as root
RUN usermod -u 1000 vscode

FROM root as nonroot
USER vscode