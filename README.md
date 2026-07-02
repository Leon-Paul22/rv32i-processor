# RV32I Processor

A parameterized RV32I processor implemented from scratch in SystemVerilog.

This repository documents the complete design and verification of a 32-bit RISC-V (RV32I) processor using a modular, industry-oriented development methodology. Every module is designed, reviewed, verified, and committed independently before being integrated into the complete processor.

The objective of this project is not only to build a functional processor, but also to develop strong RTL design, verification, and computer architecture fundamentals through a structured implementation process.

---

## Features

- Parameterized RTL modules written in SystemVerilog
- Modular processor architecture
- Self-checking verification environment
- Progressive introduction of assertions and functional coverage
- Clean Git history with incremental module development
- Well-documented and maintainable codebase

---

## Repository Structure

```text
rv32i-processor/
│
├── rtl/
│   ├── control/
│   ├── core/
│   ├── datapath/
│   ├── memory/
│   └── pkg/
│
├── tb/
│   ├── common/
│   ├── integration/
│   └── unit/
│
└── README.md
```

---

## Development Methodology

Each module follows the same development workflow.

1. Study the architecture and specifications.
2. Implement the RTL in SystemVerilog.
3. Review functionality, corner cases, and coding style.
4. Develop a self-checking verification environment.
5. Verify functionality before integration.
6. Commit and publish each milestone through Git and GitHub.

This approach mirrors the incremental development process commonly followed in digital design projects.

---

## Verification Philosophy

Verification is developed alongside the RTL instead of being treated as a final step.

As the project progresses, the verification methodology expands from directed testing to more advanced verification techniques including assertions and functional coverage.

Each module is verified independently before being integrated into the complete processor.

---

## Tools

- SystemVerilog
- Vivado Simulator
- Visual Studio Code
- Git
- GitHub

---

## Project Roadmap

The processor is being developed incrementally. Major components include:

- Register File
- ALU
- ALU Control
- Program Counter
- Instruction Memory
- Immediate Generator
- Branch Comparator
- Address Generator
- Next PC Logic
- Data Memory
- Main Control Unit
- Processor Integration

Future work includes pipelining, FPGA implementation, and expansion towards a complete RISC-V based SoC.

---

## About

This project is part of my learning journey in digital design and computer architecture. The focus is on understanding the design decisions behind each module rather than simply producing a working implementation.

The repository is continuously updated as new modules are designed, verified, and integrated.

---

## Author

**Leon Paul**

B.E. Electrical & Electronics Engineering  
Birla Institute of Technology and Science, Pilani
