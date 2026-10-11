# TinyLLM-llama2

Analyse and benchmark text generation for small pretrained Llama-2-style language models in C!

## Project Setup

Project structure reference from [Link](https://github.com/cpp-best-practices/cmake_template)

- Using CMake for build configuration for creating three binary for each sub-tasks
- `logs` directory is used to store the logs generated during the execution of the programs.
- `plots` uses python's matplotlib library to visualize the performance of the algorithms.
- `figures` directory is used to store the generated plots and figures.
- `build` directory is used to store the compiled binaries and other build artifacts.
- `src` directory contains the source code for the project, organized into subdirectories for each sub-task.
- `include` directory contains the header files for the project, organized into subdirectories for each sub-task.

## Building the Project & Running the Benchmarks

```bash

# Check the Clang version & install CMake if not already installed
./run.sh
```

## Benchmark System

> TODO: Decide which system to use for benchmarking and update the following information accordingly.

- OS:
- CPU:
- RAM:

## Generate Plots

```bash
# Create a virtual environment for Python dependencies
python3 -m venv venv
source venv/bin/activate

pip3 install -r requirements.txt

# Run the plotting script to generate performance plots
python3 plots/plot.py
```

## Acknowledgments

- This project is inspired by and reference on [karpathy/llama2.c](https://github.com/karpathy/llama2.c)
