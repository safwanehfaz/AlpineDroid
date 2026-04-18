# AlpineDroid

This project provides a way to run an Alpine Linux environment on an Android device without needing root access. It uses `proot` to simulate a root filesystem, allowing you to use the `apk` package manager to install and run standard Linux applications.

## How it Works

The system is built using Docker and consists of two main parts:

1.  **A Bootstrap Package (`bootstrap.zip`):** This archive contains a minimal Alpine Linux root filesystem (`minirootfs`) and a statically compiled `proot` binary.
2.  **An Entrypoint Script (`alpine-on-droid.sh`):** This script sets up the environment on your Android device and launches the `proot`-ed shell.

## Building

You can build the `bootstrap.zip` for `aarch64` (64-bit ARM) or `armv7l` (32-bit ARM) architectures.

### Prerequisites

*   Docker installed and running on your machine.

### Manual Build

1.  Clone this repository.
2.  Run the build script, passing the desired architecture (`aarch64` or `armv7l`).

    ```bash
    # For 64-bit Android
    ./build.sh aarch64

    # For 32-bit Android
    ./build.sh armv7l
    ```

3.  The build artifact will be located at `dist/bootstrap-<architecture>.zip`.

### Automated Build (GitHub Actions)

This repository is configured with a GitHub Actions workflow that automatically builds `bootstrap.zip` for both `aarch64` and `armv7l` on every push.

You can download the latest build artifacts from the "Actions" tab of the repository.

## Installation on Android

1.  **Install Termux:** From F-Droid or the Google Play Store.
2.  **Install `unzip`:** Open Termux and run `pkg install unzip`.
3.  **Transfer Files:**
    *   Download the appropriate `bootstrap-<architecture>.zip` from the GitHub Actions artifacts or your manual build.
    *   Create a new directory on your device (e.g., `alpinedroid`).
    *   Place the `bootstrap.zip` file and the `alpine-on-droid.sh` script inside this new directory.
4.  **Run the Setup:**
    *   In Termux, navigate to the directory you created.
    *   Make the script executable: `chmod +x alpine-on-droid.sh`
    *   Run the script: `./alpine-on-droid.sh`

The script will extract the Alpine root filesystem. Once it's done, you can enter the Alpine environment by running the `proot` command shown in the script's output.
